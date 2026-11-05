-- Perbaikan temuan tinjauan yang ditunda (gelombang 4):
--
-- 1. PENJAGA AKUN TERHAPUS: access token (JWT) yang sudah terbit tetap sah sampai kedaluwarsa
--    (kurang lebih 1 jam), sedangkan delete_account() sudah mencabut sesi dan keanggotaan. RPC
--    tulis kini menolak pemanggil dengan deleted_at terisi (28000, dianggap "tidak masuk" klien),
--    supaya akun terhapus tidak bisa menulis apa pun selama token lama masih berlaku.
--    TANPA penjaga: delete_account() (harus tetap idempoten) dan leave_circle() (dipakai
--    delete_account() SETELAH deleted_at diisi; keanggotaannya memang sudah kosong).
-- 2. EVENT set_sharing_enabled: circle_members sudah tidak dipublikasikan Realtime (ADR-016),
--    jadi perubahan sharing_enabled tidak terlihat anggota lain. RPC kini menerbitkan event
--    'sharing_changed' (payload {enabled}) hanya bila nilainya benar-benar berubah.
-- 3. DEDUP OUTBOX SOS: satu pemicu SOS membuat satu event per Circle; penerima yang ada di dua
--    Circle pengirim sebelumnya mendapat dua baris outbox (dua push). Baris kedua untuk
--    (penerima, client_id) sama tidak dibuat lagi.
-- 4. JADWAL PURGE AKUN: tether_purge_deleted_accounts naik dari harian (03:00) ke tiap jam
--    (menit 17) supaya penghapusan tuntas tidak bisa terlambat satu hari melewati 30 hari.
-- 5. ALARM pg_cron: bila ekstensi pg_cron tersedia tetapi ada job yang gagal terdaftar setelah
--    penjadwalan, migrasi GAGAL (bukan NOTICE senyap, ADR-013). Ekstensi tidak tersedia
--    tetap hanya NOTICE.

-- ---------------------------------------------------------------------------
-- 1. Penjaga akun terhapus
-- ---------------------------------------------------------------------------
create function public.assert_account_active()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.deleted_at is not null
  ) then
    raise exception 'akun telah dihapus' using errcode = '28000';
  end if;
end;
$$;

-- Internal: dipakai RPC SECURITY DEFINER lain, klien tidak boleh memanggil langsung.
revoke all on function public.assert_account_active() from public, anon, authenticated;

create or replace function public.upload_points(p_points jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_batch constant int := 500;
  c_max_future constant interval := interval '5 minutes';
  c_max_age constant interval := interval '48 hours';
  v_uid uuid := auth.uid();
  v_inserted integer;
  v_lat double precision[];
  v_lng double precision[];
  v_accuracy real[];
  v_speed real[];
  v_battery smallint[];
  v_moving boolean[];
  v_recorded timestamptz[];
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  if p_points is null or jsonb_typeof(p_points) <> 'array' then
    raise exception 'p_points harus berupa array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_points) = 0 then
    raise exception 'array titik kosong' using errcode = '22023';
  end if;
  if jsonb_array_length(p_points) > c_max_batch then
    raise exception 'maksimal % titik per batch', c_max_batch using errcode = '22023';
  end if;

  -- Hanya parsing dan validasi input yang dibungkus handler (-> 22023). Insert dan trigger
  -- sengaja di luar: galatnya tidak boleh tampil sebagai 22023, karena klien membuang titik
  -- yang ditolak dengan 22023.
  begin
    if exists (
      select 1 from jsonb_array_elements(p_points) e
      where jsonb_typeof(e) is distinct from 'object'
         or jsonb_typeof(e -> 'lat') is distinct from 'number'
         or jsonb_typeof(e -> 'lng') is distinct from 'number'
         or jsonb_typeof(e -> 'recorded_at') is distinct from 'string'
         or coalesce(jsonb_typeof(e -> 'accuracy_m'), 'null') not in ('number', 'null')
         or coalesce(jsonb_typeof(e -> 'speed_mps'), 'null') not in ('number', 'null')
         or coalesce(jsonb_typeof(e -> 'battery_pct'), 'null') not in ('number', 'null')
         or coalesce(jsonb_typeof(e -> 'is_moving'), 'null') not in ('boolean', 'null')
    ) then
      raise exception 'format titik tidak valid' using errcode = '22023';
    end if;

    if exists (
      select 1 from jsonb_array_elements(p_points) e
      where (e ->> 'lat')::double precision not between -90 and 90
         or (e ->> 'lng')::double precision not between -180 and 180
         or (e ->> 'battery_pct')::numeric not between 0 and 100
    ) then
      raise exception 'nilai titik di luar rentang' using errcode = '22023';
    end if;

    -- Semua konversi tipe dilakukan di sini (array_agg memaksa evaluasi), diurutkan menurut
    -- recorded_at supaya insert di bawah memproses titik berurutan.
    select array_agg((e ->> 'lat')::double precision order by (e ->> 'recorded_at')::timestamptz),
           array_agg((e ->> 'lng')::double precision order by (e ->> 'recorded_at')::timestamptz),
           array_agg((e ->> 'accuracy_m')::real order by (e ->> 'recorded_at')::timestamptz),
           array_agg((e ->> 'speed_mps')::real order by (e ->> 'recorded_at')::timestamptz),
           array_agg((e ->> 'battery_pct')::numeric::smallint order by (e ->> 'recorded_at')::timestamptz),
           array_agg(coalesce((e ->> 'is_moving')::boolean, false) order by (e ->> 'recorded_at')::timestamptz),
           array_agg((e ->> 'recorded_at')::timestamptz order by (e ->> 'recorded_at')::timestamptz)
      into v_lat, v_lng, v_accuracy, v_speed, v_battery, v_moving, v_recorded
    from jsonb_array_elements(p_points) e;
  exception
    when invalid_text_representation or invalid_datetime_format or datetime_field_overflow
      or numeric_value_out_of_range then
      -- sengaja tidak menyertakan SQLERRM: pesan bawaan Postgres bisa memuat isi baris
      raise exception 'format titik tidak valid' using errcode = '22023';
  end;

  -- SQLSTATE khusus TH001 (bukan 22023): penyebabnya jam perangkat, bukan titiknya. Klien
  -- menganggapnya kegagalan sementara (tetap di antrean, coba lagi), bukan titik buruk.
  if exists (select 1 from unnest(v_recorded) r where r > now() + c_max_future) then
    raise exception 'recorded_at terlalu jauh di masa depan (jam perangkat tidak sinkron)'
      using errcode = 'TH001';
  end if;

  -- Penegakan jeda di server (Sprint 3): pengguna yang punya keanggotaan tetapi SEMUA
  -- keanggotaannya dijeda atau sharing_enabled = false tidak menyimpan titik (kembali 0, tanpa
  -- galat). Pengguna tanpa keanggotaan tetap diterima (onboarding). Validasi dan TH001 di atas
  -- tetap berlaku lebih dulu.
  if exists (select 1 from public.circle_members m where m.user_id = v_uid)
     and not exists (
       select 1 from public.circle_members m
       where m.user_id = v_uid and m.sharing_enabled
         and (m.paused_until is null or m.paused_until < now())) then
    return 0;
  end if;

  insert into public.location_points
    (user_id, point, accuracy_m, speed_mps, battery_pct, is_moving, recorded_at)
  select v_uid,
         extensions.ST_SetSRID(extensions.ST_MakePoint(s.lng, s.lat), 4326)::extensions.geography,
         s.accuracy_m, s.speed_mps, s.battery_pct, s.is_moving, s.recorded_at
  from unnest(v_lat, v_lng, v_accuracy, v_speed, v_battery, v_moving, v_recorded)
         as s(lat, lng, accuracy_m, speed_mps, battery_pct, is_moving, recorded_at)
  where s.recorded_at >= now() - c_max_age
  order by s.recorded_at
  on conflict (user_id, recorded_at) do nothing;

  get diagnostics v_inserted = row_count;

  return v_inserted;
end;
$$;

revoke all on function public.upload_points(jsonb) from public, anon;
grant execute on function public.upload_points(jsonb) to authenticated;

create or replace function public.create_circle(p_name text)
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
  perform public.assert_account_active();
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

create or replace function public.create_invite(p_circle_id uuid)
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
  perform public.assert_account_active();

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

create or replace function public.preview_invite(p_code text)
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
  perform public.assert_account_active();
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

create or replace function public.join_circle(p_code text)
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
  perform public.assert_account_active();
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

create or replace function public.remove_member(p_circle_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();

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

create or replace function public.pause_sharing(p_circle_id uuid, p_minutes int default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
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

create or replace function public.resume_sharing(p_circle_id uuid)
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
  perform public.assert_account_active();

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

-- 2. set_sharing_enabled: kini menerbitkan 'sharing_changed' (payload {enabled}) hanya bila
-- nilainya berubah. circle_members tidak dipublikasikan Realtime (ADR-016), jadi tanpa event
-- anggota lain tidak akan melihat perubahan sakelar.
create or replace function public.set_sharing_enabled(p_circle_id uuid, p_enabled boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_was boolean;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  if p_enabled is null then
    raise exception 'p_enabled wajib diisi' using errcode = '22023';
  end if;

  select m.sharing_enabled into v_was from public.circle_members m
  where m.circle_id = p_circle_id and m.user_id = v_uid for update;
  if not found then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;
  if v_was is not distinct from p_enabled then
    return; -- tanpa perubahan: tanpa event
  end if;

  update public.circle_members set sharing_enabled = p_enabled
  where circle_id = p_circle_id and user_id = v_uid;
  insert into public.events (user_id, circle_id, type, payload)
  values (v_uid, p_circle_id, 'sharing_changed', jsonb_build_object('enabled', p_enabled));
end;
$$;

create or replace function public.create_place(
  p_circle_id uuid, p_name text, p_lat double precision, p_lng double precision, p_radius_m int)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  -- PRD F7: maksimal 5 tempat per Circle.
  c_max_places constant int := 5;
  v_uid uuid := auth.uid();
  v_name text := btrim(p_name);
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  if v_name is null or char_length(v_name) not between 1 and 40 then
    raise exception 'nama tempat harus 1 sampai 40 karakter' using errcode = '22023';
  end if;
  -- NaN lolos "not between" sebagai false pada ekspresi biasa, jadi diperiksa eksplisit.
  if p_lat is null or p_lng is null or p_lat = 'NaN' or p_lng = 'NaN'
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'koordinat tidak valid' using errcode = '22023';
  end if;
  if p_radius_m is null or p_radius_m not between 100 and 5000 then
    raise exception 'radius harus 100 sampai 5000 meter' using errcode = '22023';
  end if;

  -- Kunci baris Circle dulu (urutan kunci sama dengan RPC Circle) agar batas 5 tidak bisa
  -- dilampaui oleh dua pemanggilan bersamaan. Circle tidak ada atau bukan anggota: galat sama.
  perform 1 from public.circles c where c.id = p_circle_id for update;
  if not found or not public.is_circle_member(p_circle_id) then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;
  if (select count(*) from public.places where circle_id = p_circle_id) >= c_max_places then
    raise exception 'batas tempat per circle tercapai' using errcode = 'TH005';
  end if;

  insert into public.places (circle_id, name, center, radius_m, created_by)
  values (p_circle_id, v_name,
          extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat), 4326)::extensions.geography,
          p_radius_m, v_uid)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.update_place(p_place_id uuid, p_name text, p_radius_m int)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(p_name);
  v_circle uuid;
  v_creator uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  if v_name is null or char_length(v_name) not between 1 and 40 then
    raise exception 'nama tempat harus 1 sampai 40 karakter' using errcode = '22023';
  end if;
  if p_radius_m is null or p_radius_m not between 100 and 5000 then
    raise exception 'radius harus 100 sampai 5000 meter' using errcode = '22023';
  end if;

  select p.circle_id into v_circle from public.places p where p.id = p_place_id;
  if found then
    perform 1 from public.circles c where c.id = v_circle for update;
  end if;
  if found then
    select p.created_by into v_creator from public.places p where p.id = p_place_id for update;
  end if;
  if not found or not public.is_circle_member(v_circle) then
    raise exception 'tempat tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_creator is distinct from v_uid and not public.is_circle_admin(v_circle) then
    raise exception 'hanya pembuat atau admin' using errcode = '42501';
  end if;

  update public.places set name = v_name, radius_m = p_radius_m where id = p_place_id;
end;
$$;

create or replace function public.delete_place(p_place_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_circle uuid;
  v_creator uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();

  select p.circle_id into v_circle from public.places p where p.id = p_place_id;
  if found then
    perform 1 from public.circles c where c.id = v_circle for update;
  end if;
  if found then
    select p.created_by into v_creator from public.places p where p.id = p_place_id for update;
  end if;
  if not found or not public.is_circle_member(v_circle) then
    raise exception 'tempat tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_creator is distinct from v_uid and not public.is_circle_admin(v_circle) then
    raise exception 'hanya pembuat atau admin' using errcode = '42501';
  end if;

  delete from public.places where id = p_place_id;
end;
$$;

create or replace function public.checkin(p_circle_id uuid, p_kind text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c_window constant interval := interval '30 seconds';
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  if p_kind is null or p_kind not in ('arrived', 'safe') then
    raise exception 'p_kind harus arrived atau safe' using errcode = '22023';
  end if;
  if not public.is_circle_member(p_circle_id) then
    raise exception 'bukan anggota circle' using errcode = '42501';
  end if;

  -- Serialkan per pengguna dan Circle agar dua panggilan bersamaan tidak lolos batas laju.
  perform pg_advisory_xact_lock(hashtextextended('th_checkin:' || v_uid::text || p_circle_id::text, 0));
  if exists (
    select 1 from public.events e
    where e.user_id = v_uid and e.circle_id = p_circle_id and e.type = 'checkin'
      and e.created_at > clock_timestamp() - c_window
  ) then
    raise exception 'terlalu sering check-in' using errcode = 'TH006';
  end if;

  insert into public.events (user_id, circle_id, type, created_at, payload)
  values (v_uid, p_circle_id, 'checkin', clock_timestamp(),
          jsonb_build_object('kind', p_kind,
            'display_name', (select p.display_name from public.profiles p where p.id = v_uid)))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.trigger_sos(
  p_lat double precision, p_lng double precision, p_accuracy_m real default null,
  p_client_id uuid default null, p_triggered_at timestamptz default null)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  c_max_sos constant int := 3;
  c_window constant interval := interval '10 minutes';
  c_max_age constant interval := interval '1 day';
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_name text;
  v_count int;
  v_triggered timestamptz;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  if p_lat is null or p_lng is null or p_lat = 'NaN' or p_lng = 'NaN'
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'koordinat tidak valid' using errcode = '22023';
  end if;
  if p_accuracy_m is not null
     and (p_accuracy_m = 'NaN' or p_accuracy_m = 'Infinity' or p_accuracy_m < 0) then
    raise exception 'akurasi tidak valid' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('th_sos:' || v_uid::text, 0));

  -- Pengulangan dengan p_client_id yang sama: tidak membuat event lagi, tidak memakai jatah laju.
  if p_client_id is not null then
    select count(*)::int into v_count from public.events e
    where e.user_id = v_uid and e.type = 'sos' and e.payload ->> 'client_id' = p_client_id::text;
    if v_count > 0 then
      return v_count;
    end if;
  end if;

  if (select count(distinct e.created_at) from public.events e
      where e.user_id = v_uid and e.type = 'sos' and e.created_at > v_now - c_window) >= c_max_sos then
    raise exception 'terlalu sering memicu SOS' using errcode = 'TH007';
  end if;

  if not exists (select 1 from public.circle_members m where m.user_id = v_uid) then
    raise exception 'tidak ada circle untuk diberi tahu' using errcode = 'TH008';
  end if;

  -- Waktu pemicu dari klien dijepit ke [sekarang - 1 hari, sekarang]; selain itu waktu server.
  v_triggered := least(v_now, greatest(coalesce(p_triggered_at, v_now), v_now - c_max_age));

  select p.display_name into v_name from public.profiles p where p.id = v_uid;

  insert into public.events (user_id, circle_id, type, created_at, payload)
  select v_uid, m.circle_id, 'sos', v_now,
         jsonb_build_object('display_name', v_name, 'lat', p_lat, 'lng', p_lng,
                            'accuracy_m', p_accuracy_m, 'triggered_at', v_triggered)
           || case when p_client_id is null then '{}'::jsonb
                   else jsonb_build_object('client_id', p_client_id) end
  from public.circle_members m
  where m.user_id = v_uid
  order by m.circle_id;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.register_device(p_platform text, p_push_token text)
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
  perform public.assert_account_active();
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

create or replace function public.unregister_device(p_push_token text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  delete from public.devices where user_id = v_uid and push_token = p_push_token;
end;
$$;

create or replace function public.delete_my_location_history()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_deleted integer;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  perform public.assert_account_active();
  delete from public.location_points where user_id = v_uid;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Tipe event baru: sharing_changed
-- ---------------------------------------------------------------------------
alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check check (type in (
  'arrive', 'leave', 'checkin', 'sos', 'paused', 'resumed',
  'member_joined', 'member_left', 'member_removed', 'sharing_changed'));

-- ---------------------------------------------------------------------------
-- 3. Outbox: sharing_changed ikut preferensi member_changes, dan dedup SOS
-- ---------------------------------------------------------------------------
create or replace function public.events_after_insert()
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
    -- Dedup push SOS: penerima yang sudah diberi baris outbox untuk SOS pengirim dengan
    -- client_id sama (dari Circle lain) tidak diberi baris kedua; satu SOS satu push.
    and not (
      new.type = 'sos'
      and new.payload ->> 'client_id' is not null
      and exists (
        select 1 from public.push_outbox o
        join public.events e on e.id = o.event_id
        where e.type = 'sos' and e.user_id = new.user_id
          and e.payload ->> 'client_id' = new.payload ->> 'client_id'
          and o.recipient_id = m.user_id
      )
    )
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
          when 'sharing_changed' then coalesce(s.member_changes, true)
          else false
        end;
  return null;
end;
$$;

revoke all on function public.events_after_insert() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4 dan 5. Penjadwalan ulang purge akun tiap jam + alarm pg_cron yang keras
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron tidak tersedia: purge TIDAK dijadwalkan (lihat ADR-013)';
    return;
  end if;

  create extension if not exists pg_cron;
  -- cron.schedule memperbarui job bernama sama, jadi idempoten dan aman diulang.
  perform cron.schedule('tether_purge_location_points', '0 * * * *',
    'select public.purge_old_location_points()');
  perform cron.schedule('tether_purge_deleted_accounts', '17 * * * *',
    'select public.purge_deleted_accounts()');
  perform cron.schedule('tether_purge_events', '10 3 * * *',
    'select public.purge_old_events()');

  -- Alarm: pg_cron tersedia tetapi job gagal terdaftar = gagal keras, bukan senyap.
  if exists (
    select 1 from (values
      ('tether_purge_location_points'),
      ('tether_purge_deleted_accounts'),
      ('tether_purge_events')) as j(name)
    where not exists (select 1 from cron.job cj where cj.jobname = j.name)
  ) then
    raise exception 'job purge pg_cron tidak lengkap setelah penjadwalan';
  end if;
end;
$$;
