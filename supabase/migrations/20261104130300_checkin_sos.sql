-- Sprint 5: check-in (PRD F8) dan SOS (PRD F9).
-- Dicatat sebagai event di tabel events; notifikasi push lewat push_outbox (migrasi berikutnya).
--
-- SQLSTATE baru: TH006 = batas laju check-in, TH007 = batas laju SOS,
--                TH008 = SOS tanpa Circle (tidak ada yang bisa diberi tahu).
-- (Lainnya dipakai ulang: 28000 tidak login, 22023 argumen tidak valid, 42501 bukan anggota.)

-- checkin: p_kind 'arrived' ("Saya sudah sampai") atau 'safe' ("Saya aman"). Hanya anggota Circle.
-- Payload {kind, display_name}, TANPA koordinat. Maksimal 1 check-in per 30 detik per pengguna
-- per Circle (TH006). Berlaku walau pengguna sedang dijeda: check-in adalah tindakan sengaja
-- dan tidak membawa lokasi. Mengembalikan id event.
create function public.checkin(p_circle_id uuid, p_kind text)
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

-- trigger_sos: membuat event 'sos' di SETIAP Circle tempat pengguna menjadi anggota dan
-- mengembalikan jumlah Circle yang diberi tahu.
--
-- PRIVASI: event 'sos' adalah SATU-SATUNYA event yang membawa koordinat (lat, lng) di payload.
-- Ini disengaja karena inti fitur SOS. Event hanya terlihat oleh anggota Circle tempat event itu
-- dibuat (kebijakan events_select_circle) dan pelakunya sendiri. Event lain TIDAK boleh memuat
-- koordinat.
--
-- SOS berlaku WALAU pengguna sedang dijeda atau sharing_enabled = false di Circle itu:
-- keselamatan mengalahkan jeda. Pemicu SOS adalah tindakan sengaja pengguna.
-- Batas laju: 3 SOS per 10 menit per pengguna (TH007). Tanpa Circle: TH008.
-- Pesan galat tidak memuat koordinat.
create function public.trigger_sos(
  p_lat double precision, p_lng double precision, p_accuracy_m real default null)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  c_max_sos constant int := 3;
  c_window constant interval := interval '10 minutes';
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_name text;
  v_count int;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  if p_lat is null or p_lng is null or p_lat = 'NaN' or p_lng = 'NaN'
     or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'koordinat tidak valid' using errcode = '22023';
  end if;
  if p_accuracy_m is not null and (p_accuracy_m = 'NaN' or p_accuracy_m < 0) then
    raise exception 'akurasi tidak valid' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('th_sos:' || v_uid::text, 0));
  -- Satu pemicu SOS menghasilkan satu event per Circle dengan created_at yang sama
  -- (clock_timestamp), jadi pemicu dihitung lewat created_at yang berbeda.
  if (select count(distinct e.created_at) from public.events e
      where e.user_id = v_uid and e.type = 'sos' and e.created_at > v_now - c_window) >= c_max_sos then
    raise exception 'terlalu sering memicu SOS' using errcode = 'TH007';
  end if;

  if not exists (select 1 from public.circle_members m where m.user_id = v_uid) then
    raise exception 'tidak ada circle untuk diberi tahu' using errcode = 'TH008';
  end if;

  select p.display_name into v_name from public.profiles p where p.id = v_uid;

  insert into public.events (user_id, circle_id, type, created_at, payload)
  select v_uid, m.circle_id, 'sos', v_now,
         jsonb_build_object('display_name', v_name, 'lat', p_lat, 'lng', p_lng,
                            'accuracy_m', p_accuracy_m, 'triggered_at', v_now)
  from public.circle_members m
  where m.user_id = v_uid
  order by m.circle_id;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.checkin(uuid, text),
  public.trigger_sos(double precision, double precision, real) from public, anon;
grant execute on function public.checkin(uuid, text),
  public.trigger_sos(double precision, double precision, real) to authenticated;
