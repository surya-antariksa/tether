-- Sprint 0A (T0.2 dan T0.5): skema lokasi minimal, RLS dasar, RPC unggah, dan geofence di server.
-- Rujukan: docs/04-data-model.md, docs/03-architecture.md (alur geofence, ADR-006, ADR-008).
--
-- Kebijakan RLS di bawah ini HANYA untuk spike: akses berbasis pemilik (user_id = auth.uid()).
-- Akan diganti berbasis keanggotaan Circle di Sprint 2/3.

create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- places
-- ---------------------------------------------------------------------------
-- circle_id belum punya FK: tabel circles baru ada di Sprint 2, FK ditambah di sana.
create table public.places (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid,
  name text not null,
  center extensions.geography(Point, 4326) not null,
  radius_m int not null check (radius_m between 50 and 5000),
  created_at timestamptz default now()
);

create index places_center_gist on public.places using gist (center);

-- ---------------------------------------------------------------------------
-- location_points
-- ---------------------------------------------------------------------------
-- Partisi harian ditunda ke Sprint 3 (ADR-008, retensi 48 jam). Sementara tabel biasa
-- dan pembersihan lewat purge_old_location_points().
create table public.location_points (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,
  point extensions.geography(Point, 4326) not null,
  accuracy_m real,
  speed_mps real,
  battery_pct smallint check (battery_pct between 0 and 100),
  is_moving boolean not null default false,
  recorded_at timestamptz not null,
  received_at timestamptz not null default now(),
  -- kiriman ulang batch yang sama idempoten (ON CONFLICT DO NOTHING di upload_points)
  unique (user_id, recorded_at)
);

-- Catatan: unique di atas sudah membuat indeks (user_id, recorded_at) menaik. Indeks menurun
-- tetap dibuat sesuai rancangan (kueri "titik terbaru dulu").
create index location_points_user_recorded_idx
  on public.location_points (user_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- member_status
-- ---------------------------------------------------------------------------
-- Status terakhir per pengguna, diisi HANYA oleh trigger di location_points.
--
-- Cara kerja debounce geofence (kandidat):
--   "kandidat" adalah hasil evaluasi satu titik: sebuah place (titik berada dalam radius,
--   dipilih yang terdekat bila ada beberapa) atau "di luar" (tidak ada place yang memuat).
--   current_place_id = tempat yang sudah DINYATAKAN (null berarti di luar atau belum diketahui).
--   pending_place_id + pending_is_outside = kandidat yang sedang menunggu konfirmasi:
--     place         -> pending_place_id terisi, pending_is_outside = false
--     "di luar"     -> pending_place_id null, pending_is_outside = true
--     tidak ada     -> pending_place_id null, pending_is_outside = false, pending_count = 0
--   pending_count = jumlah titik berurutan yang menghasilkan kandidat pending yang sama.
--   Kandidat sama dengan current -> pending direset. Kandidat berbeda -> pending_count naik
--   bila kandidat sama dengan pending, selain itu pending diganti dan count = 1. Pada count >= 2
--   status dikomit (event leave/arrive) dan pending direset.
-- pending_place_id sengaja tanpa FK: hanya penanda sementara.
create table public.member_status (
  user_id uuid primary key references auth.users on delete cascade,
  last_point extensions.geography(Point, 4326),
  last_seen_at timestamptz,
  battery_pct smallint,
  is_moving boolean,
  current_place_id uuid references public.places (id) on delete set null,
  pending_place_id uuid,
  pending_count smallint not null default 0,
  pending_is_outside boolean not null default false
);

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
-- circle_id belum punya FK (Circle datang di Sprint 2). Payload TIDAK boleh memuat koordinat.
create table public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  circle_id uuid,
  type text not null check (type in ('arrive', 'leave', 'checkin', 'sos', 'paused', 'resumed')),
  place_id uuid references public.places (id) on delete set null,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RLS dan hak akses (spike)
-- ---------------------------------------------------------------------------
alter table public.places enable row level security;
alter table public.location_points enable row level security;
alter table public.member_status enable row level security;
alter table public.events enable row level security;

-- Bawaan Supabase memberi ALL ke anon dan authenticated pada tabel baru di public: cabut dulu.
revoke all on public.places, public.location_points, public.member_status, public.events
  from public, anon, authenticated;
revoke all on sequence public.location_points_id_seq from public, anon, authenticated;

grant select on public.places, public.location_points, public.member_status, public.events
  to authenticated;

-- Pemilik boleh membaca miliknya sendiri. Tidak ada kebijakan INSERT/UPDATE/DELETE:
-- penulisan hanya lewat upload_points() dan trigger (SECURITY DEFINER).
create policy location_points_select_own on public.location_points
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy member_status_select_own on public.member_status
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy events_select_own on public.events
  for select to authenticated
  using (user_id = (select auth.uid()));

-- places: semua pengguna terautentikasi boleh membaca (spike), tulis tidak diizinkan.
create policy places_select_authenticated on public.places
  for select to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- Trigger: member_status dan geofence
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER dengan search_path terkunci (semua nama dikualifikasi skema).
-- Dipanggil per baris yang BENAR-BENAR masuk (baris yang dilewati ON CONFLICT tidak memicu).
create function public.location_points_after_insert()
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
  v_current uuid;
  v_pending uuid;
  v_pending_out boolean;
  v_count smallint;
  v_cand uuid;
  v_cand_out boolean;
begin
  -- (a) member_status hanya diubah bila titik ini LEBIH BARU dari last_seen_at. Batch bisa
  -- datang tidak berurutan: titik lama tetap tersimpan di location_points, tetapi tidak
  -- mengubah status maupun geofence.
  insert into public.member_status as ms
    (user_id, last_point, last_seen_at, battery_pct, is_moving)
  values
    (new.user_id, new.point, new.recorded_at, new.battery_pct, new.is_moving)
  on conflict (user_id) do update
    set last_point = excluded.last_point,
        last_seen_at = excluded.last_seen_at,
        battery_pct = excluded.battery_pct,
        is_moving = excluded.is_moving
    where ms.last_seen_at is null or ms.last_seen_at < excluded.last_seen_at
  returning ms.current_place_id, ms.pending_place_id, ms.pending_is_outside, ms.pending_count
  into v_current, v_pending, v_pending_out, v_count;

  if not found then
    return null; -- titik lama: status dan geofence tidak berubah
  end if;

  -- (b) geofence dengan debounce. Titik tanpa akurasi (null) tetap dievaluasi.
  if new.accuracy_m is not null and new.accuracy_m > c_max_accuracy_m then
    return null;
  end if;

  -- Kandidat: place terdekat yang memuat titik, atau null = "di luar".
  -- TODO Sprint 2: batasi ke place milik Circle pengguna.
  select p.id into v_cand
  from public.places p
  where extensions.ST_DWithin(p.center, new.point, p.radius_m)
  order by extensions.ST_Distance(p.center, new.point), p.id
  limit 1;
  v_cand_out := v_cand is null;

  if v_cand is not distinct from v_current then
    update public.member_status
       set pending_place_id = null, pending_count = 0, pending_is_outside = false
     where user_id = new.user_id
       and (pending_place_id is not null or pending_count <> 0 or pending_is_outside);
    return null;
  end if;

  if (v_cand_out and v_pending_out) or (not v_cand_out and v_cand = v_pending) then
    v_count := v_count + 1;
  else
    v_count := 1;
  end if;

  if v_count >= c_commit_count then
    if v_current is not null then
      insert into public.events (user_id, type, place_id, payload)
      select new.user_id, 'leave', p.id,
             jsonb_build_object('place_name', p.name, 'recorded_at', new.recorded_at)
      from public.places p
      where p.id = v_current;
    end if;
    if v_cand is not null then
      insert into public.events (user_id, type, place_id, payload)
      select new.user_id, 'arrive', p.id,
             jsonb_build_object('place_name', p.name, 'recorded_at', new.recorded_at)
      from public.places p
      where p.id = v_cand;
    end if;
    update public.member_status
       set current_place_id = v_cand,
           pending_place_id = null, pending_count = 0, pending_is_outside = false
     where user_id = new.user_id;
  else
    update public.member_status
       set pending_place_id = v_cand, pending_count = v_count, pending_is_outside = v_cand_out
     where user_id = new.user_id;
  end if;

  return null;
end;
$$;

revoke all on function public.location_points_after_insert() from public, anon, authenticated;

create trigger location_points_after_insert
  after insert on public.location_points
  for each row execute function public.location_points_after_insert();

-- ---------------------------------------------------------------------------
-- RPC unggah titik
-- ---------------------------------------------------------------------------
-- Input: array objek {lat, lng, accuracy_m, speed_mps, battery_pct, is_moving, recorded_at}.
-- user_id SELALU dari auth.uid(); field user_id di payload diabaikan.
-- SECURITY DEFINER karena authenticated sengaja tidak punya hak INSERT langsung; search_path
-- terkunci. Mengembalikan jumlah baris yang benar-benar masuk (duplikat dan titik > 48 jam
-- dilewati, bukan gagal). Titik diproses berurutan menurut recorded_at agar debounce geofence
-- benar walau array tidak berurutan.
-- Error (SQLSTATE 22023 untuk input tidak valid, 28000 bila tidak login, TH001 bila recorded_at
-- > 5 menit di masa depan karena jam perangkat maju). Satu titik tidak valid menggagalkan
-- SELURUH batch: klien mengisolasi dan membuang titik yang ditolak dengan 22023, sedangkan TH001
-- dan kode lain dianggap sementara (titik tetap di antrean). Pesan error tidak memuat koordinat.
-- recorded_at sebaiknya ISO-8601 dengan zona waktu (mis. akhiran Z).
create function public.upload_points(p_points jsonb)
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

-- ---------------------------------------------------------------------------
-- Retensi (ADR-008)
-- ---------------------------------------------------------------------------
-- Menghapus titik lebih tua dari 48 jam (berdasarkan recorded_at, sama dengan batas unggah).
-- BELUM dijadwalkan: pg_cron menyusul di Sprint 3. Hanya untuk service_role/postgres.
create function public.purge_old_location_points()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.location_points
  where recorded_at < now() - interval '48 hours';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.purge_old_location_points() from public, anon, authenticated;
