-- Sprint 5: pengaturan notifikasi, perangkat, dan outbox push (persiapan FCM, PRD F10).
-- BELUM ADA pengirim: Edge Function yang membaca push_outbox dan memanggil FCM menyusul
-- (butuh proyek Firebase milik pengguna). Sampai itu ada, baris outbox menumpuk dengan sent_at null.

-- ---------------------------------------------------------------------------
-- notification_settings
-- ---------------------------------------------------------------------------
-- SOS tidak punya sakelar: SOS SELALU dikirim.
create table public.notification_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  arrive_leave boolean not null default true,
  checkin boolean not null default true,
  member_changes boolean not null default true
);

alter table public.notification_settings enable row level security;
revoke all on public.notification_settings from public, anon, authenticated;
grant select on public.notification_settings to authenticated;
-- Baris dibuat trigger (tidak ada INSERT/DELETE klien); user_id tidak bisa diubah.
grant update (arrive_leave, checkin, member_changes) on public.notification_settings to authenticated;

create policy notification_settings_select_own on public.notification_settings
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy notification_settings_update_own on public.notification_settings
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Baris otomatis saat profil dibuat. Tidak boleh gagal (akan menggagalkan pendaftaran).
create function public.handle_new_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.notification_settings (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return null;
end;
$$;

revoke all on function public.handle_new_profile() from public, anon, authenticated;

create trigger on_profile_created
  after insert on public.profiles
  for each row execute function public.handle_new_profile();

-- Profil yang sudah ada sebelum migrasi ini.
insert into public.notification_settings (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------------
-- devices: token push. Klien TIDAK punya akses langsung (tidak ada SELECT/INSERT/UPDATE/DELETE):
-- token adalah rahasia, dan lewat RPC sudah cukup untuk mendaftar dan mencabut.
-- ---------------------------------------------------------------------------
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'linux', 'web')),
  push_token text not null check (char_length(push_token) between 1 and 4096),
  last_active_at timestamptz not null default now(),
  unique (user_id, push_token)
);

alter table public.devices enable row level security;
revoke all on public.devices from public, anon, authenticated;

-- register_device: upsert menurut (user_id, push_token), memperbarui platform dan last_active_at.
-- Token yang sama milik pengguna LAIN dihapus: token mengikuti perangkat, jadi bila perangkat
-- berganti akun, akun lama tidak boleh lagi menerima notifikasi di perangkat itu.
-- Maksimal 10 perangkat per pengguna (yang paling lama tidak aktif dibuang). Mengembalikan id.
create function public.register_device(p_platform text, p_push_token text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  -- ASUMSI: batas perangkat per pengguna agar tabel tidak bisa dibengkakkan.
  c_max_devices constant int := 10;
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if p_platform is null or p_platform not in ('android', 'ios', 'linux', 'web') then
    raise exception 'platform tidak valid' using errcode = '22023';
  end if;
  if p_push_token is null or char_length(p_push_token) not between 1 and 4096 then
    raise exception 'token tidak valid' using errcode = '22023';
  end if;

  delete from public.devices where push_token = p_push_token and user_id <> v_uid;

  insert into public.devices as d (user_id, platform, push_token)
  values (v_uid, p_platform, p_push_token)
  on conflict (user_id, push_token) do update
    set platform = excluded.platform, last_active_at = now()
  returning d.id into v_id;

  delete from public.devices
  where id in (
    select d2.id from public.devices d2
    where d2.user_id = v_uid
    order by d2.last_active_at desc, d2.id
    offset c_max_devices);

  return v_id;
end;
$$;

-- unregister_device: menghapus perangkat milik pemanggil. Token tidak dikenal: tanpa galat
-- (tidak membocorkan apakah token ada).
create function public.unregister_device(p_push_token text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  delete from public.devices where user_id = v_uid and push_token = p_push_token;
end;
$$;

revoke all on function public.register_device(text, text), public.unregister_device(text)
  from public, anon;
grant execute on function public.register_device(text, text), public.unregister_device(text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- push_outbox: antrean notifikasi. Tanpa akses klien sama sekali. TIDAK memuat isi payload:
-- pengirim membaca events (event_id) sendiri dengan hak service_role.
-- ---------------------------------------------------------------------------
create table public.push_outbox (
  id bigint generated always as identity primary key,
  event_id uuid not null references public.events (id) on delete cascade,
  recipient_id uuid not null references auth.users on delete cascade,
  kind text not null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  attempts int not null default 0
);

alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from public, anon, authenticated;
revoke all on sequence public.push_outbox_id_seq from public, anon, authenticated;

-- Jalur panas pengirim: baris yang belum terkirim, urut id. Indeks FK untuk cascade.
create index push_outbox_pending_idx on public.push_outbox (id) where sent_at is null;
create index push_outbox_event_idx on public.push_outbox (event_id);
create index push_outbox_recipient_idx on public.push_outbox (recipient_id);

-- Trigger: setiap event baru -> satu baris outbox per anggota Circle penerima, kecuali pelaku
-- (events.user_id). Preferensi: arrive/leave -> arrive_leave; checkin -> checkin;
-- member_joined/left/removed dan paused/resumed -> member_changes; 'sos' SELALU.
-- Catatan: untuk member_removed, events.user_id adalah anggota yang dikeluarkan (bukan admin
-- pelaku), jadi admin yang mengeluarkan ikut menjadi penerima.
create function public.events_after_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.circle_id is null then
    return null;
  end if;

  insert into public.push_outbox (event_id, recipient_id, kind)
  select new.id, m.user_id, new.type
  from public.circle_members m
  left join public.notification_settings s on s.user_id = m.user_id
  where m.circle_id = new.circle_id
    and m.user_id <> new.user_id
    and case new.type
          when 'sos' then true
          when 'arrive' then coalesce(s.arrive_leave, true)
          when 'leave' then coalesce(s.arrive_leave, true)
          when 'checkin' then coalesce(s.checkin, true)
          when 'member_joined' then coalesce(s.member_changes, true)
          when 'member_left' then coalesce(s.member_changes, true)
          when 'member_removed' then coalesce(s.member_changes, true)
          when 'paused' then coalesce(s.member_changes, true)
          when 'resumed' then coalesce(s.member_changes, true)
          else false
        end;
  return null;
end;
$$;

revoke all on function public.events_after_insert() from public, anon, authenticated;

create trigger events_after_insert
  after insert on public.events
  for each row execute function public.events_after_insert();
