-- Sprint 0A: RLS dan hak akses dasar (kebijakan spike berbasis pemilik).
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'a@example.test'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'b@example.test');

-- Sejak Sprint 4 geofence dan places per Circle: A dan B masing-masing di Circle sendiri dengan
-- satu place di titik yang sama (Circle berbeda, jadi event A tidak terlihat oleh B).
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-00000000000a', 'CA'), ('c1c1c1c1-0000-0000-0000-00000000000b', 'CB');
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a', 'admin'),
  ('c1c1c1c1-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-00000000000b', 'admin');
insert into public.places (circle_id, name, center, radius_m)
select c, 'Titik Uji', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography, 150
from unnest(array['c1c1c1c1-0000-0000-0000-00000000000a', 'c1c1c1c1-0000-0000-0000-00000000000b']::uuid[]) c;

-- Data dua pengguna, dimasukkan sebagai postgres (2 titik di tengah place uji -> 1 event arrive).
insert into public.location_points (user_id, point, accuracy_m, recorded_at)
select u, extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography,
       10, now() - m * interval '1 minute'
from unnest(array['aaaaaaaa-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-00000000000b']::uuid[]) u,
     unnest(array[10, 9]) m;

select is(
  (select count(*)::int from pg_class
   where oid in ('public.places'::regclass, 'public.location_points'::regclass,
                 'public.member_status'::regclass, 'public.events'::regclass)
     and relrowsecurity),
  4, 'RLS aktif di keempat tabel');

-- Login sebagai A
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.location_points where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'),
  2, 'A melihat titik miliknya');
select is((select count(*)::int from public.location_points where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'),
  0, 'A tidak melihat titik B');
select is((select count(*)::int from public.member_status where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'),
  1, 'A melihat status miliknya');
select is((select count(*)::int from public.member_status where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'),
  0, 'A tidak melihat status B');
select is((select count(*)::int from public.events where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'),
  1, 'A melihat event miliknya');
select is((select count(*)::int from public.events where user_id = 'bbbbbbbb-0000-0000-0000-00000000000b'),
  0, 'A tidak melihat event B');
select is((select count(*)::int from public.places), 1, 'A hanya membaca place Circle-nya (bukan milik B)');

select throws_ok($$insert into public.location_points (user_id, point, recorded_at)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', extensions.ST_GeogFromText('POINT(0 0)'), now())$$,
  '42501', null::text, 'INSERT langsung ke location_points ditolak');
select throws_ok($$insert into public.member_status (user_id)
  values ('aaaaaaaa-0000-0000-0000-00000000000a')$$,
  '42501', null::text, 'INSERT langsung ke member_status ditolak');
select throws_ok($$insert into public.events (user_id, type)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', 'sos')$$,
  '42501', null::text, 'INSERT langsung ke events ditolak');
select throws_ok($$insert into public.places (name, center, radius_m)
  values ('x', extensions.ST_GeogFromText('POINT(0 0)'), 100)$$,
  '42501', null::text, 'INSERT langsung ke places ditolak');

select throws_ok($$update public.location_points set is_moving = true$$,
  '42501', null::text, 'UPDATE location_points ditolak');
select throws_ok($$update public.member_status set battery_pct = 1$$,
  '42501', null::text, 'UPDATE member_status ditolak');
select throws_ok($$update public.events set type = 'sos'$$,
  '42501', null::text, 'UPDATE events ditolak');

select throws_ok($$delete from public.location_points$$,
  '42501', null::text, 'DELETE location_points ditolak');
select throws_ok($$delete from public.member_status$$,
  '42501', null::text, 'DELETE member_status ditolak');
select throws_ok($$delete from public.events$$,
  '42501', null::text, 'DELETE events ditolak');

select throws_ok($$update public.places set radius_m = 100$$,
  '42501', null::text, 'UPDATE places ditolak');
select throws_ok($$delete from public.places$$,
  '42501', null::text, 'DELETE places ditolak');

-- Anon tidak punya akses sama sekali
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;

select throws_ok($$select count(*) from public.location_points$$,
  '42501', null::text, 'anon tidak bisa membaca location_points');
select throws_ok($$select public.upload_points('[]'::jsonb)$$,
  '42501', null::text, 'anon tidak bisa memanggil upload_points');

select * from finish();
rollback;
