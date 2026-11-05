-- Perbaikan dari tinjauan migrasi Sprint 4 dan 5.
--
-- 1. trigger_sos idempoten dan mendukung antrean offline (docs/09 T5.4): p_client_id (uuid dari
--    klien, dibuat saat tombol SOS ditahan) mencegah event dan push ganda bila permintaan
--    diulang; p_triggered_at membawa waktu pemicu asli bila terkirim terlambat.
-- 2. Koordinat SOS hanya terbaca oleh anggota Circle selama 48 jam (sama dengan titik lokasi,
--    docs/05 bagian 7); sesudahnya hanya pelakunya yang bisa membaca. Koordinat di payload yang
--    lebih lama dari 48 jam dibuang oleh purge_old_events, dijalankan cron harian, sehingga
--    penyimpanan fisik bisa sampai sekitar 72 jam; batas 48 jam ditegakkan oleh RLS.

drop function public.trigger_sos(double precision, double precision, real);

create function public.trigger_sos(
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

revoke all on function
  public.trigger_sos(double precision, double precision, real, uuid, timestamptz)
  from public, anon;
grant execute on function
  public.trigger_sos(double precision, double precision, real, uuid, timestamptz)
  to authenticated;

-- Kebijakan baca events: SOS lebih dari 48 jam hanya terbaca pelakunya.
drop policy events_select_circle on public.events;
create policy events_select_circle on public.events
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (circle_id is not null
        and public.is_circle_member(circle_id)
        and (type <> 'sos' or created_at > now() - interval '48 hours')));

create or replace function public.purge_old_events()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.events where created_at < now() - interval '90 days';
  get diagnostics v_deleted = row_count;
  -- Koordinat SOS tidak disimpan lebih dari 48 jam.
  update public.events
  set payload = payload - 'lat' - 'lng' - 'accuracy_m'
  where type = 'sos' and created_at < now() - interval '48 hours' and payload ? 'lat';
  return v_deleted;
end;
$$;
