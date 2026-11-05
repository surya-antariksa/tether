-- Sprint 4: geofence per Circle (menggantikan model spike satu current_place_id per pengguna).
-- Rujukan: docs/03-architecture.md (alur geofence), docs/07-uml-diagrams.md 3.2.
--
-- Untuk SETIAP keanggotaan Circle pengguna yang aktif (sharing_enabled dan tidak dijeda), titik
-- baru dievaluasi terhadap place milik Circle itu saja, dengan debounce yang sama seperti spike.
-- Event arrive/leave membawa circle_id Circle tersebut. PRIVASI: keanggotaan yang dijeda atau
-- sharing_enabled = false TIDAK dievaluasi dan tidak menghasilkan event (agar tidak bocor lewat
-- arrive/leave). Titik tanpa keanggotaan aktif tidak menghasilkan event.

-- ---------------------------------------------------------------------------
-- member_place_state: status geofence per (pengguna, Circle)
-- ---------------------------------------------------------------------------
-- Arti kolom sama dengan member_status di spike:
--   current_place_id = tempat yang sudah DINYATAKAN (null = di luar atau belum diketahui).
--   pending_place_id + pending_is_outside = kandidat yang menunggu konfirmasi
--     (place: pending_place_id terisi, is_outside = false; "di luar": null dan is_outside = true).
--   pending_count = jumlah titik berurutan dengan kandidat pending yang sama (komit pada >= 2).
-- pending_place_id sengaja tanpa FK (penanda sementara). Hanya diisi trigger; klien tidak punya
-- akses (RLS aktif, tanpa kebijakan dan tanpa GRANT).
create table public.member_place_state (
  user_id uuid not null references auth.users on delete cascade,
  circle_id uuid not null references public.circles on delete cascade,
  current_place_id uuid references public.places (id) on delete set null,
  pending_place_id uuid,
  pending_count smallint not null default 0,
  pending_is_outside boolean not null default false,
  primary key (user_id, circle_id)
);

create index member_place_state_circle_idx on public.member_place_state (circle_id);

alter table public.member_place_state enable row level security;
revoke all on public.member_place_state from public, anon, authenticated;

-- Keluar atau dikeluarkan dari Circle (leave_circle, remove_member, delete_account) menghapus
-- status geofence Circle itu, sehingga bergabung kembali dimulai dari nol.
create function public.circle_members_after_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  delete from public.member_place_state
  where user_id = old.user_id and circle_id = old.circle_id;
  return null;
end;
$$;

revoke all on function public.circle_members_after_delete() from public, anon, authenticated;

create trigger circle_members_after_delete
  after delete on public.circle_members
  for each row execute function public.circle_members_after_delete();

-- Kolom geofence di member_status tidak lagi dipakai (status ada di member_place_state).
-- Dibiarkan agar klien yang masih memilih kolomnya tidak error: nilainya selalu null/0/false.
comment on column public.member_status.current_place_id is
  'TIDAK DIPAKAI sejak Sprint 4: lihat member_place_state. Selalu null.';
comment on column public.member_status.pending_place_id is 'TIDAK DIPAKAI sejak Sprint 4.';
comment on column public.member_status.pending_count is 'TIDAK DIPAKAI sejak Sprint 4.';
comment on column public.member_status.pending_is_outside is 'TIDAK DIPAKAI sejak Sprint 4.';

-- Bersihkan sisa status spike agar konsisten dengan komentar "selalu null".
update public.member_status
   set current_place_id = null, pending_place_id = null, pending_count = 0, pending_is_outside = false
 where current_place_id is not null or pending_place_id is not null
    or pending_count <> 0 or pending_is_outside;

-- ---------------------------------------------------------------------------
-- Trigger location_points: member_status + geofence per Circle
-- ---------------------------------------------------------------------------
create or replace function public.location_points_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- ASUMSI (belum dikalibrasi): titik dengan akurasi lebih buruk dari ini tidak dipakai geofence.
  c_max_accuracy_m constant real := 100;
  -- ASUMSI: jumlah titik berurutan dengan kandidat sama sebelum status dikomit.
  c_commit_count constant smallint := 2;
  v_circle uuid;
  v_exists boolean;
  v_current uuid;
  v_pending uuid;
  v_pending_out boolean;
  v_count smallint;
  v_cand uuid;
  v_cand_out boolean;
begin
  -- (a) member_status hanya diubah bila titik ini LEBIH BARU dari last_seen_at. Batch bisa
  -- datang tidak berurutan: titik lama tetap tersimpan di location_points, tetapi tidak
  -- mengubah status maupun geofence. Upsert ini juga mengunci baris pengguna sehingga evaluasi
  -- geofence satu pengguna berjalan serial.
  insert into public.member_status as ms
    (user_id, last_point, last_seen_at, battery_pct, is_moving)
  values
    (new.user_id, new.point, new.recorded_at, new.battery_pct, new.is_moving)
  on conflict (user_id) do update
    set last_point = excluded.last_point,
        last_seen_at = excluded.last_seen_at,
        battery_pct = excluded.battery_pct,
        is_moving = excluded.is_moving
    where ms.last_seen_at is null or ms.last_seen_at < excluded.last_seen_at;

  if not found then
    return null; -- titik lama: status dan geofence tidak berubah
  end if;

  -- (b) geofence dengan debounce. Titik tanpa akurasi (null) tetap dievaluasi.
  if new.accuracy_m is not null and new.accuracy_m > c_max_accuracy_m then
    return null;
  end if;

  -- Hanya keanggotaan yang aktif (berbagi menyala dan tidak dijeda). Urut circle_id agar urutan
  -- kunci konsisten.
  for v_circle in
    select m.circle_id
    from public.circle_members m
    where m.user_id = new.user_id
      and m.sharing_enabled
      and (m.paused_until is null or m.paused_until < now())
    order by m.circle_id
  loop
    select s.current_place_id, s.pending_place_id, s.pending_is_outside, s.pending_count
      into v_current, v_pending, v_pending_out, v_count
    from public.member_place_state s
    where s.user_id = new.user_id and s.circle_id = v_circle;
    v_exists := found;
    if not v_exists then
      v_current := null; v_pending := null; v_pending_out := false; v_count := 0;
    end if;

    -- Kandidat: place terdekat di Circle ini yang memuat titik, atau null = "di luar".
    select p.id into v_cand
    from public.places p
    where p.circle_id = v_circle
      and extensions.ST_DWithin(p.center, new.point, p.radius_m)
    order by extensions.ST_Distance(p.center, new.point), p.id
    limit 1;
    v_cand_out := v_cand is null;

    if v_cand is not distinct from v_current then
      if v_exists and (v_pending is not null or v_count <> 0 or v_pending_out) then
        update public.member_place_state
           set pending_place_id = null, pending_count = 0, pending_is_outside = false
         where user_id = new.user_id and circle_id = v_circle;
      end if;
      continue;
    end if;

    if (v_cand_out and v_pending_out) or (not v_cand_out and v_cand = v_pending) then
      v_count := v_count + 1;
    else
      v_count := 1;
    end if;

    if v_count >= c_commit_count then
      if v_current is not null then
        insert into public.events (user_id, circle_id, type, place_id, payload)
        select new.user_id, v_circle, 'leave', p.id,
               jsonb_build_object('place_name', p.name, 'recorded_at', new.recorded_at)
        from public.places p
        where p.id = v_current;
      end if;
      if v_cand is not null then
        insert into public.events (user_id, circle_id, type, place_id, payload)
        select new.user_id, v_circle, 'arrive', p.id,
               jsonb_build_object('place_name', p.name, 'recorded_at', new.recorded_at)
        from public.places p
        where p.id = v_cand;
      end if;
      insert into public.member_place_state as s
        (user_id, circle_id, current_place_id, pending_place_id, pending_count, pending_is_outside)
      values (new.user_id, v_circle, v_cand, null, 0, false)
      on conflict (user_id, circle_id) do update
        set current_place_id = excluded.current_place_id,
            pending_place_id = null, pending_count = 0, pending_is_outside = false;
    else
      insert into public.member_place_state as s
        (user_id, circle_id, current_place_id, pending_place_id, pending_count, pending_is_outside)
      values (new.user_id, v_circle, v_current, v_cand, v_count, v_cand_out)
      on conflict (user_id, circle_id) do update
        set pending_place_id = excluded.pending_place_id,
            pending_count = excluded.pending_count,
            pending_is_outside = excluded.pending_is_outside;
    end if;
  end loop;

  return null;
end;
$$;
