-- Sprint 4/5: publikasi Realtime, purge_old_events, indeks jalur panas, penjadwalan pg_cron.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

-- ---------------------------------------------------------------------------
-- Publikasi Realtime
-- ---------------------------------------------------------------------------
select is((select array_agg(tablename::text order by tablename) from pg_publication_tables
           where pubname = 'supabase_realtime' and schemaname = 'public'),
  array['events', 'member_status', 'places'], 'supabase_realtime memuat events, member_status, dan places di schema public');
select is((select count(*)::int from pg_publication_tables
           where pubname = 'supabase_realtime' and tablename = 'circle_members'), 0,
  'circle_members TIDAK ada di publikasi (event DELETE tidak difilter RLS)');
select is((select count(*)::int from pg_publication_tables
           where pubname = 'supabase_realtime' and tablename in
           ('devices', 'push_outbox', 'member_place_state', 'notification_settings', 'location_points', 'invites')), 0,
  'tabel sensitif lain tidak dipublikasikan (places diterbitkan sejak 131000)');

-- ---------------------------------------------------------------------------
-- purge_old_events (90 hari)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 2) n;
insert into public.circles (id, name) values ('c1c1c1c1-0000-0000-0000-000000000001', 'C1');
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member');
insert into public.events (id, user_id, circle_id, type, payload, created_at) values
  ('e0000000-0000-0000-0000-000000000001', pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'checkin', '{}', now() - interval '91 days'),
  ('e0000000-0000-0000-0000-000000000002', pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'checkin', '{}', now() - interval '120 days'),
  ('e0000000-0000-0000-0000-000000000003', pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'checkin', '{}', now() - interval '89 days'),
  ('e0000000-0000-0000-0000-000000000004', pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'checkin', '{}', now());
select is((select count(*)::int from public.push_outbox where event_id::text like 'e0000000%'), 4,
  'sebelum purge: outbox ada untuk 4 event uji');
select is(public.purge_old_events(), 2, 'purge_old_events menghapus 2 event (91 dan 120 hari)');
select is((select array_agg(right(id::text, 1) order by id) from public.events where id::text like 'e0000000%'),
  array['3', '4'], 'event 89 hari dan baru tetap ada');
select is((select count(*)::int from public.push_outbox where event_id::text like 'e0000000%'), 2,
  'outbox event yang dihapus ikut terhapus (cascade)');
select pg_temp.as_user(1);
select throws_ok($$select public.purge_old_events()$$, '42501', null::text, 'authenticated tidak bisa purge_old_events');
reset role;
set local role anon;
select throws_ok($$select public.purge_old_events()$$, '42501', null::text, 'anon tidak bisa purge_old_events');
reset role;
select ok(has_function_privilege('service_role', 'public.purge_old_events()', 'execute'), 'service_role boleh purge_old_events');

-- ---------------------------------------------------------------------------
-- Indeks jalur panas
-- ---------------------------------------------------------------------------
select is((select count(*)::int from pg_indexes where schemaname = 'public' and indexname in (
  'events_circle_created_idx', 'events_created_idx', 'events_user_created_idx', 'places_circle_idx',
  'circle_members_user_idx', 'push_outbox_pending_idx', 'location_points_recorded_idx',
  'member_place_state_circle_idx', 'push_outbox_event_idx', 'push_outbox_recipient_idx')), 10,
  'semua indeks jalur panas ada');
select ok((select indexdef like '%(circle_id, created_at DESC)%' from pg_indexes where indexname = 'events_circle_created_idx'),
  'events: indeks (circle_id, created_at desc)');
select ok((select indexdef like '%WHERE (sent_at IS NULL)%' from pg_indexes where indexname = 'push_outbox_pending_idx'),
  'push_outbox: indeks parsial untuk baris belum terkirim');
select is(to_regclass('public.location_points_user_recorded_idx'), null,
  'indeks location_points redundan (user_id, recorded_at desc) sudah dihapus');
select ok((select count(*) = 1 from pg_constraint where conrelid = 'public.location_points'::regclass and contype = 'u'),
  'unique (user_id, recorded_at) tetap melayani kueri per pengguna');

-- ---------------------------------------------------------------------------
-- pg_cron (dilewati bila ekstensi tidak ada di lingkungan ini)
-- ---------------------------------------------------------------------------
create function pg_temp.cron_jobs() returns text[] language plpgsql as $$
begin
  if to_regclass('cron.job') is null then return null; end if;
  return (select array_agg(jobname || '|' || schedule || '|' || command order by jobname) from cron.job where jobname like 'tether_%');
end $$;
select case when pg_temp.cron_jobs() is null then skip('pg_cron tidak tersedia', 1)
  else is(pg_temp.cron_jobs(), array[
    'tether_purge_deleted_accounts|17 * * * *|select public.purge_deleted_accounts()',
    'tether_purge_events|10 3 * * *|select public.purge_old_events()',
    'tether_purge_location_points|0 * * * *|select public.purge_old_location_points()'],
    'pg_cron: tiga job purge: titik per jam, akun terhapus tiap jam (lihat 130900), events harian') end;

select * from finish();
rollback;
