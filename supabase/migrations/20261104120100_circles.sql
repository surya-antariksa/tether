-- Sprint 2 (T2.1 sampai T2.4): Circle, anggota, undangan, jeda berbagi.
-- Rujukan: docs/04-data-model.md, docs/05-privacy-security.md.
--
-- Prinsip:
--  * Klien TIDAK punya hak tulis langsung ke circles, circle_members, invites, join_attempts.
--    Semua perubahan lewat RPC SECURITY DEFINER (search_path terkunci, user dari auth.uid()).
--  * invites dan join_attempts tidak bisa dibaca klien sama sekali.
--  * Fungsi bantu SECURITY DEFINER STABLE dipakai di kebijakan RLS agar tidak rekursif.
--
-- SQLSTATE yang dipakai RPC (pesan singkat, tanpa koordinat):
--   28000 tidak login            22023 argumen tidak valid        42501 bukan anggota atau bukan admin
--   P0002 target tidak ditemukan TH002 terlalu banyak percobaan   TH003 Circle penuh
--   TH004 batas Circle per pengguna tercapai
-- (TH001 milik upload_points: recorded_at terlalu jauh di masa depan.)

-- ---------------------------------------------------------------------------
-- Tabel
-- ---------------------------------------------------------------------------
create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

-- user_id mengacu ke profiles (bukan auth.users) agar PostgREST bisa meng-embed profil anggota.
create table public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('admin', 'member')),
  sharing_enabled boolean not null default true,
  -- null = tidak dijeda; 'infinity' = dijeda sampai dinyalakan lagi.
  paused_until timestamptz,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create index circle_members_user_idx on public.circle_members (user_id);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  -- sha256 hex dari kode huruf besar. Kode asli tidak pernah disimpan.
  code_hash text not null unique,
  expires_at timestamptz not null,
  max_uses int not null default 10 check (max_uses > 0),
  used_count int not null default 0 check (used_count >= 0),
  created_by uuid references public.profiles (id) on delete set null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index invites_circle_idx on public.invites (circle_id);

-- Catatan percobaan gabung/pratinjau, untuk pembatasan brute force.
create table public.join_attempts (
  user_id uuid not null references auth.users on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded boolean not null
);

create index join_attempts_user_idx on public.join_attempts (user_id, attempted_at desc);

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.invites enable row level security;
alter table public.join_attempts enable row level security;

revoke all on public.circles, public.circle_members, public.invites, public.join_attempts
  from public, anon, authenticated;
-- Hanya SELECT, dan hanya untuk circles dan circle_members (lewat kebijakan di bawah).
grant select on public.circles, public.circle_members to authenticated;

-- ---------------------------------------------------------------------------
-- events: tipe baru dan FK ke circles (sebelumnya ditunda sampai tabel ini ada)
-- ---------------------------------------------------------------------------
alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check check (type in (
  'arrive', 'leave', 'checkin', 'sos', 'paused', 'resumed',
  'member_joined', 'member_left', 'member_removed'));

-- Circle dihapus -> event dan tempat miliknya ikut terhapus.
alter table public.events
  add constraint events_circle_id_fkey foreign key (circle_id)
  references public.circles (id) on delete cascade;
alter table public.places
  add constraint places_circle_id_fkey foreign key (circle_id)
  references public.circles (id) on delete cascade;

create index events_circle_created_idx on public.events (circle_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Fungsi bantu untuk RLS (SECURITY DEFINER STABLE, user dari auth.uid())
-- ---------------------------------------------------------------------------
create function public.is_circle_member(p_circle_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members m
    where m.circle_id = p_circle_id and m.user_id = (select auth.uid()));
$$;

create function public.is_circle_admin(p_circle_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members m
    where m.circle_id = p_circle_id and m.user_id = (select auth.uid()) and m.role = 'admin');
$$;

-- Pemanggil dan p_user_id berbagi minimal satu Circle (untuk profil).
create function public.shares_circle(p_user_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members me
    join public.circle_members them on them.circle_id = me.circle_id
    where me.user_id = (select auth.uid()) and them.user_id = p_user_id);
$$;

-- Pemanggil boleh melihat lokasi p_owner_id: ada Circle bersama yang di sisi pemilik
-- sharing_enabled = true DAN tidak sedang dijeda. Admin tidak mendapat pengecualian.
create function public.shares_active_circle(p_owner_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members me
    join public.circle_members them on them.circle_id = me.circle_id
    where me.user_id = (select auth.uid())
      and them.user_id = p_owner_id
      and them.sharing_enabled
      and (them.paused_until is null or them.paused_until < now()));
$$;

revoke all on function public.is_circle_member(uuid), public.is_circle_admin(uuid),
  public.shares_circle(uuid), public.shares_active_circle(uuid) from public, anon;
grant execute on function public.is_circle_member(uuid), public.is_circle_admin(uuid),
  public.shares_circle(uuid), public.shares_active_circle(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Kebijakan RLS
-- ---------------------------------------------------------------------------
create policy circles_select_member on public.circles
  for select to authenticated
  using (public.is_circle_member(id));

create policy circle_members_select_member on public.circle_members
  for select to authenticated
  using (public.is_circle_member(circle_id));

-- invites dan join_attempts: RLS aktif tanpa kebijakan dan tanpa GRANT = klien tidak bisa apa-apa.

-- Profil anggota Circle yang sama boleh dibaca (kebijakan profil sendiri ada di migrasi profiles).
create policy profiles_select_circle_mates on public.profiles
  for select to authenticated
  using (public.shares_circle(id));

-- ---------------------------------------------------------------------------
-- Fungsi internal (tidak bisa dipanggil klien)
-- ---------------------------------------------------------------------------
create function public.hash_invite_code(p_code text)
returns text
language sql immutable set search_path = ''
as $$
  select encode(extensions.digest(upper(btrim(coalesce(p_code, ''))), 'sha256'), 'hex');
$$;

-- Kode 6 karakter dari 31 simbol tanpa karakter ambigu (tanpa 0, O, 1, I, L), dari CSPRNG
-- (gen_random_bytes). Byte >= 248 dibuang agar tidak ada bias modulo (248 = 31 * 8).
create function public.generate_invite_code()
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  c_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c_length constant int := 6;
  v_code text := '';
  v_bytes bytea;
  v_byte int;
  i int;
begin
  while char_length(v_code) < c_length loop
    v_bytes := extensions.gen_random_bytes(16);
    for i in 0..15 loop
      v_byte := get_byte(v_bytes, i);
      if v_byte < 248 then
        v_code := v_code || substr(c_alphabet, (v_byte % 31) + 1, 1);
        exit when char_length(v_code) = c_length;
      end if;
    end loop;
  end loop;
  return v_code;
end;
$$;

-- Tolak (TH002) bila pengguna sudah gagal >= 10 kali dalam 15 menit terakhir. Dipanggil di
-- awal preview_invite dan join_circle. Percobaan lama (> 1 hari) dibersihkan sekalian.
create function public.check_join_rate(p_user_id uuid)
returns void
language plpgsql set search_path = ''
as $$
declare
  c_max_failures constant int := 10;
  c_window constant interval := interval '15 minutes';
begin
  delete from public.join_attempts
  where user_id = p_user_id and attempted_at < now() - interval '1 day';
  if (select count(*) from public.join_attempts
      where user_id = p_user_id and not succeeded and attempted_at > now() - c_window)
     >= c_max_failures then
    raise exception 'terlalu banyak percobaan' using errcode = 'TH002';
  end if;
end;
$$;

revoke all on function public.hash_invite_code(text), public.generate_invite_code(),
  public.check_join_rate(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------
-- Urutan kunci baris agar tidak deadlock: baris circles dulu, baru invites/circle_members.

-- create_circle: pembuat menjadi admin. Mengembalikan id Circle.
create function public.create_circle(p_name text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  -- ASUMSI: maksimal 5 keanggotaan Circle per pengguna saat membuat Circle baru.
  c_max_circles constant int := 5;
  v_uid uuid := auth.uid();
  v_name text := btrim(p_name);
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 40 then
    raise exception 'nama circle harus 1 sampai 40 karakter' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('th_circle:' || v_uid::text, 0));
  if (select count(*) from public.circle_members where user_id = v_uid) >= c_max_circles then
    raise exception 'batas circle tercapai' using errcode = 'TH004';
  end if;

  insert into public.circles (name, created_by) values (v_name, v_uid) returning id into v_id;
  insert into public.circle_members (circle_id, user_id, role) values (v_id, v_uid, 'admin');
  return v_id;
end;
$$;

-- create_invite: hanya admin. Mencabut undangan aktif sebelumnya. Kode asli hanya dikembalikan
-- di sini (yang disimpan hanya hash).
create function public.create_invite(p_circle_id uuid)
returns table (code text, expires_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
declare
  c_ttl constant interval := interval '48 hours';
  c_max_uses constant int := 10;
  v_uid uuid := auth.uid();
  v_code text;
  v_expires timestamptz := now() + c_ttl;
  v_try int := 0;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;

  perform 1 from public.circles c where c.id = p_circle_id for update;
  if not found or not public.is_circle_admin(p_circle_id) then
    raise exception 'hanya admin' using errcode = '42501';
  end if;

  update public.invites i set revoked_at = now()
  where i.circle_id = p_circle_id and i.revoked_at is null;

  loop
    v_try := v_try + 1;
    v_code := public.generate_invite_code();
    begin
      insert into public.invites (circle_id, code_hash, expires_at, max_uses, created_by)
      values (p_circle_id, public.hash_invite_code(v_code), v_expires, c_max_uses, v_uid);
      exit;
    exception when unique_violation then
      -- tabrakan hash (sangat jarang): coba kode lain
      if v_try >= 5 then
        raise exception 'gagal membuat kode, coba lagi' using errcode = 'P0001';
      end if;
    end;
  end loop;

  code := v_code;
  expires_at := v_expires;
  return next;
end;
$$;

-- preview_invite: tidak bergabung. Kode tidak valid, kedaluwarsa, dicabut, atau habis -> nol
-- baris (tidak dibedakan). Dihitung pada pembatasan percobaan.
-- Kegagalan SENGAJA tidak memakai RAISE: galat membatalkan transaksi dan ikut menghapus catatan
-- percobaan di join_attempts, sehingga pembatasan tidak akan pernah bekerja.
create function public.preview_invite(p_code text)
returns table (circle_name text, member_count int)
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_circle uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('th_join:' || v_uid::text, 0));
  perform public.check_join_rate(v_uid);

  select i.circle_id into v_circle
  from public.invites i
  where i.code_hash = public.hash_invite_code(p_code)
    and i.revoked_at is null and i.expires_at > now() and i.used_count < i.max_uses;

  if not found then
    insert into public.join_attempts (user_id, succeeded) values (v_uid, false);
    return;
  end if;

  insert into public.join_attempts (user_id, succeeded) values (v_uid, true);
  return query
    select c.name,
           (select count(*)::int from public.circle_members m where m.circle_id = c.id)
    from public.circles c
    where c.id = v_circle;
end;
$$;

-- join_circle: mengembalikan circle_id. Kode tidak valid/kedaluwarsa/dicabut/habis ->
-- mengembalikan NULL (satu hasil umum untuk semua sebab; alasan RAISE dijelaskan di preview_invite).
-- Sudah anggota -> circle_id tanpa efek ganda. Circle penuh -> galat TH003.
create function public.join_circle(p_code text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  -- ASUMSI (PRD F3): maksimal 10 anggota per Circle.
  c_max_members constant int := 10;
  v_uid uuid := auth.uid();
  v_hash text := public.hash_invite_code(p_code);
  v_circle uuid;
  v_invite public.invites%rowtype;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('th_join:' || v_uid::text, 0));
  perform public.check_join_rate(v_uid);

  -- Kunci Circle dulu (urutan kunci), lalu baca ulang undangan dengan FOR UPDATE.
  select i.circle_id into v_circle
  from public.invites i
  where i.code_hash = v_hash and i.revoked_at is null and i.expires_at > now();
  if found then
    perform 1 from public.circles c where c.id = v_circle for update;
  end if;
  if found then
    select i.* into v_invite
    from public.invites i
    where i.code_hash = v_hash and i.revoked_at is null and i.expires_at > now()
    for update;
  end if;
  if not found then
    insert into public.join_attempts (user_id, succeeded) values (v_uid, false);
    return null;
  end if;

  if exists (select 1 from public.circle_members m
             where m.circle_id = v_circle and m.user_id = v_uid) then
    insert into public.join_attempts (user_id, succeeded) values (v_uid, true);
    return v_circle;
  end if;

  if v_invite.used_count >= v_invite.max_uses then
    insert into public.join_attempts (user_id, succeeded) values (v_uid, false);
    return null;
  end if;

  if (select count(*) from public.circle_members m where m.circle_id = v_circle) >= c_max_members then
    raise exception 'circle penuh' using errcode = 'TH003';
  end if;

  update public.invites set used_count = used_count + 1 where id = v_invite.id;
  insert into public.circle_members (circle_id, user_id, role) values (v_circle, v_uid, 'member');
  insert into public.events (user_id, circle_id, type, payload)
  values (v_uid, v_circle, 'member_joined',
          jsonb_build_object('display_name',
            (select p.display_name from public.profiles p where p.id = v_uid)));
  insert into public.join_attempts (user_id, succeeded) values (v_uid, true);
  return v_circle;
end;
$$;

-- leave_circle: anggota terakhir -> Circle dihapus (cascade). Admin terakhir yang keluar saat
-- masih ada anggota lain -> anggota paling lama bergabung dipromosikan jadi admin.
create function public.leave_circle(p_circle_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_next uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;

  perform 1 from public.circles c where c.id = p_circle_id for update;
  if found then
    select m.role into v_role from public.circle_members m
    where m.circle_id = p_circle_id and m.user_id = v_uid;
  end if;
  if not found then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;

  if not exists (select 1 from public.circle_members m
                 where m.circle_id = p_circle_id and m.user_id <> v_uid) then
    delete from public.circles where id = p_circle_id;
    return;
  end if;

  if v_role = 'admin' and not exists (
       select 1 from public.circle_members m
       where m.circle_id = p_circle_id and m.user_id <> v_uid and m.role = 'admin') then
    select m.user_id into v_next from public.circle_members m
    where m.circle_id = p_circle_id and m.user_id <> v_uid
    order by m.joined_at, m.user_id
    limit 1;
    update public.circle_members set role = 'admin'
    where circle_id = p_circle_id and user_id = v_next;
  end if;

  delete from public.circle_members where circle_id = p_circle_id and user_id = v_uid;
  insert into public.events (user_id, circle_id, type, payload)
  values (v_uid, p_circle_id, 'member_left',
          jsonb_build_object('display_name',
            (select p.display_name from public.profiles p where p.id = v_uid)));
end;
$$;

-- remove_member: hanya admin, tidak boleh diri sendiri (pakai leave_circle).
-- Event 'member_removed' dicatat atas nama anggota yang dikeluarkan.
create function public.remove_member(p_circle_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;

  perform 1 from public.circles c where c.id = p_circle_id for update;
  if not found or not public.is_circle_admin(p_circle_id) then
    raise exception 'hanya admin' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = v_uid then
    raise exception 'tidak boleh mengeluarkan diri sendiri' using errcode = '22023';
  end if;

  delete from public.circle_members where circle_id = p_circle_id and user_id = p_user_id;
  if not found then
    raise exception 'anggota tidak ditemukan' using errcode = 'P0002';
  end if;

  insert into public.events (user_id, circle_id, type, payload)
  values (p_user_id, p_circle_id, 'member_removed',
          jsonb_build_object('display_name',
            (select p.display_name from public.profiles p where p.id = p_user_id)));
end;
$$;

-- pause_sharing: p_minutes null = sampai dinyalakan lagi (paused_until = 'infinity').
-- Per Circle. Event 'paused' dengan payload {"minutes": n} (n null bila tanpa batas).
create function public.pause_sharing(p_circle_id uuid, p_minutes int default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if p_minutes is not null and p_minutes <= 0 then
    raise exception 'p_minutes harus positif' using errcode = '22023';
  end if;

  update public.circle_members
     set paused_until = case when p_minutes is null then 'infinity'::timestamptz
                             else now() + p_minutes * interval '1 minute' end
   where circle_id = p_circle_id and user_id = v_uid;
  if not found then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;

  insert into public.events (user_id, circle_id, type, payload)
  values (v_uid, p_circle_id, 'paused', jsonb_build_object('minutes', p_minutes));
end;
$$;

-- resume_sharing: paused_until = null. Event 'resumed' hanya bila memang sedang ada jeda.
create function public.resume_sharing(p_circle_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_was timestamptz;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;

  select m.paused_until into v_was from public.circle_members m
  where m.circle_id = p_circle_id and m.user_id = v_uid for update;
  if not found then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;
  if v_was is null then
    return;
  end if;

  update public.circle_members set paused_until = null
  where circle_id = p_circle_id and user_id = v_uid;
  insert into public.events (user_id, circle_id, type, payload)
  values (v_uid, p_circle_id, 'resumed', '{}');
end;
$$;

-- set_sharing_enabled: sakelar berbagi jangka panjang per Circle (terpisah dari jeda).
-- Tidak mencatat event; anggota lain melihat perubahannya lewat circle_members.sharing_enabled.
create function public.set_sharing_enabled(p_circle_id uuid, p_enabled boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if p_enabled is null then
    raise exception 'p_enabled wajib diisi' using errcode = '22023';
  end if;

  update public.circle_members set sharing_enabled = p_enabled
  where circle_id = p_circle_id and user_id = v_uid;
  if not found then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;
end;
$$;

-- Default Supabase memberi EXECUTE ke anon: cabut dari public DAN anon, beri hanya ke authenticated.
revoke all on function
  public.create_circle(text), public.create_invite(uuid), public.preview_invite(text),
  public.join_circle(text), public.leave_circle(uuid), public.remove_member(uuid, uuid),
  public.pause_sharing(uuid, int), public.resume_sharing(uuid),
  public.set_sharing_enabled(uuid, boolean)
  from public, anon;
grant execute on function
  public.create_circle(text), public.create_invite(uuid), public.preview_invite(text),
  public.join_circle(text), public.leave_circle(uuid), public.remove_member(uuid, uuid),
  public.pause_sharing(uuid, int), public.resume_sharing(uuid),
  public.set_sharing_enabled(uuid, boolean)
  to authenticated;
