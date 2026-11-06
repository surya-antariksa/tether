-- Retensi riwayat lokasi: 48 jam -> 30 hari (permintaan produk 2026-11-06).
--
-- Yang berubah:
--   * upload_points menerima titik sampai 30 hari ke belakang (sebelumnya 48 jam), supaya titik
--     yang tertahan lama di antrean offline tidak dibuang server.
--   * purge_old_location_points membuang titik lebih tua dari 30 hari (sebelumnya 48 jam).
--     Dijadwalkan tiap jam oleh pg_cron (migrasi retention_indexes / guard_sharing_outbox).
--
-- Yang TIDAK berubah (sengaja, minimisasi data):
--   * Anggota Circle lain tetap hanya bisa membaca titik 48 jam terakhir (kebijakan RLS
--     location_points_select_circle). Hanya pemilik titik yang melihat 30 hari.
--   * Koordinat SOS tetap 48 jam. Kode undangan tetap berlaku 48 jam.
--   * events dihapus setelah 90 hari.

create or replace function public.upload_points(p_points jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_batch constant int := 500;
  c_max_future constant interval := interval '5 minutes';
  c_max_age constant interval := interval '30 days';
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

create or replace function public.purge_old_location_points()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.location_points
  where recorded_at < now() - interval '30 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.purge_old_location_points() from public, anon, authenticated;
