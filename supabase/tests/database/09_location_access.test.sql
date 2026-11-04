-- Sprint 3: aturan akses lokasi berbasis Circle (matriks visibilitas) dan penegakan jeda di upload_points.
begin;
create extension if not exists pgtap with schema extensions;
select plan(45);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.ids(variadic n int[]) returns uuid[] language sql as
  $$ select array_agg(pg_temp.uid(x) order by pg_temp.uid(x)) from unnest(n) x $$;
-- pengguna yang statusnya / titiknya terlihat oleh pengguna saat ini
create function pg_temp.vis_status() returns uuid[] language sql as
  $$ select coalesce(array_agg(user_id order by user_id), '{}') from public.member_status $$;
create function pg_temp.vis_points() returns uuid[] language sql as
  $$ select coalesce(array_agg(distinct user_id order by user_id), '{}') from public.location_points $$;
create function pg_temp.n_points(n int) returns int language sql as
  $$ select count(*)::int from public.location_points where user_id = pg_temp.uid(n) $$;
create function pg_temp.n_status(n int) returns int language sql as
  $$ select count(*)::int from public.member_status where user_id = pg_temp.uid(n) $$;
create function pg_temp.pt(mins numeric, lat double precision default -6.3, lng double precision default 106.9)
returns jsonb language sql as $$
  select jsonb_build_object('lat', lat, 'lng', lng, 'accuracy_m', 10, 'speed_mps', 0,
    'battery_pct', 80, 'is_moving', false, 'recorded_at', now() - mins * interval '1 minute')
$$;

insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 30) n;

-- C: u1 admin, u2 aktif, u3 dijeda (infinity), u4 sharing_enabled=false, u5 jeda sudah lewat,
--    u6 jeda 30 menit lagi, u9 aktif, u10 dijeda di C tetapi aktif di E (bersama u1)
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C'),
  ('e1e1e1e1-0000-0000-0000-000000000001', 'E'),
  ('d1d1d1d1-0000-0000-0000-000000000001', 'D'),
  ('f1f1f1f1-0000-0000-0000-000000000001', 'F');
insert into public.circle_members (circle_id, user_id, role, sharing_enabled, paused_until) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin', true, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member', true, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(3), 'member', true, 'infinity'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(4), 'member', false, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(5), 'member', true, now() - interval '1 minute'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(6), 'member', true, now() + interval '30 minutes'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(9), 'member', true, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(10), 'member', true, 'infinity'),
  ('e1e1e1e1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin', true, null),
  ('e1e1e1e1-0000-0000-0000-000000000001', pg_temp.uid(10), 'member', true, null),
  ('d1d1d1d1-0000-0000-0000-000000000001', pg_temp.uid(11), 'admin', true, null),
  ('d1d1d1d1-0000-0000-0000-000000000001', pg_temp.uid(12), 'member', true, null),
  ('f1f1f1f1-0000-0000-0000-000000000001', pg_temp.uid(7), 'admin', true, null),
  ('f1f1f1f1-0000-0000-0000-000000000001', pg_temp.uid(8), 'member', true, null);

-- Titik: semua pengguna (kecuali 12) satu titik 10 menit lalu; u13 tanpa keanggotaan.
-- u2 juga punya titik 47 jam dan 49 jam lalu; u1 titik 60 jam lalu (milik sendiri).
insert into public.location_points (user_id, point, accuracy_m, recorded_at)
select pg_temp.uid(n), extensions.ST_SetSRID(extensions.ST_MakePoint(106.9, -6.3), 4326)::extensions.geography,
       10, now() - interval '10 minutes'
from unnest(array[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13]) n;
insert into public.location_points (user_id, point, accuracy_m, recorded_at)
select pg_temp.uid(u), extensions.ST_SetSRID(extensions.ST_MakePoint(106.9, -6.3), 4326)::extensions.geography,
       10, now() - h * interval '1 hour'
from (values (2, 47), (2, 49), (1, 60)) v(u, h);

-- Peristiwa: e1 di C oleh u2; e2 tanpa Circle oleh u2; e3 di F oleh u7
insert into public.events (user_id, circle_id, type, payload) values
  (pg_temp.uid(2), 'c1c1c1c1-0000-0000-0000-000000000001', 'checkin', '{}'),
  (pg_temp.uid(2), null, 'checkin', '{}'),
  (pg_temp.uid(7), 'f1f1f1f1-0000-0000-0000-000000000001', 'checkin', '{}');

-- ---------------------------------------------------------------------------
-- Matriks visibilitas, dilihat oleh admin u1
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select is(pg_temp.vis_status(), pg_temp.ids(1, 2, 5, 9, 10),
  'u1 melihat status: sendiri, aktif (2, 9), jeda lewat (5), aktif di Circle bersama lain (10)');
select is(pg_temp.vis_points(), pg_temp.ids(1, 2, 5, 9, 10), 'u1 melihat titik dari pengguna yang sama');
select is(pg_temp.n_points(2), 2, 'titik 10 menit dan 47 jam terlihat, 49 jam tidak');
select is(pg_temp.n_points(1), 2, 'titik milik sendiri terlihat semua, termasuk > 48 jam');
select is(pg_temp.n_points(3) + pg_temp.n_status(3), 0, 'admin TIDAK melihat anggota yang dijeda (infinity)');
select is(pg_temp.n_points(4) + pg_temp.n_status(4), 0, 'sharing_enabled=false tidak terlihat');
select is(pg_temp.n_points(6) + pg_temp.n_status(6), 0, 'jeda yang belum berakhir tidak terlihat');
select is(pg_temp.n_points(5), 1, 'jeda yang sudah lewat: terlihat lagi tanpa mengubah baris');
select is(pg_temp.n_points(10) + pg_temp.n_status(10), 2, 'dijeda di satu Circle tetapi aktif di Circle bersama lain: terlihat');
select is(pg_temp.n_points(7) + pg_temp.n_status(7) + pg_temp.n_points(8) + pg_temp.n_status(8), 0, 'orang asing tidak terlihat');
select is(pg_temp.n_points(11) + pg_temp.n_status(11), 0, 'anggota Circle lain (tanpa Circle bersama) tidak terlihat');
select is(pg_temp.n_points(13) + pg_temp.n_status(13), 0, 'pengguna tanpa keanggotaan tidak terlihat');
select is((select count(*)::int from public.location_points), 7, 'total titik terlihat oleh u1 = 7');

-- ---------------------------------------------------------------------------
-- Sudut pandang lain
-- ---------------------------------------------------------------------------
select pg_temp.as_user(2);
select is(pg_temp.vis_status(), pg_temp.ids(1, 2, 5, 9),
  'u2 (anggota biasa): u10 tidak terlihat karena dijeda di satu-satunya Circle bersama');
select is(pg_temp.n_points(2), 3, 'pemilik melihat semua titiknya sendiri (juga 49 jam)');
select pg_temp.as_user(3);
select is(pg_temp.vis_status(), pg_temp.ids(1, 2, 3, 5, 9),
  'u3 (sendiri dijeda) tetap melihat dirinya dan anggota aktif');
select pg_temp.as_user(7);
select is(pg_temp.vis_status(), pg_temp.ids(7, 8), 'orang asing hanya melihat Circle-nya sendiri');
select is(pg_temp.vis_points(), pg_temp.ids(7, 8), 'orang asing: titik hanya dari Circle-nya sendiri');
select pg_temp.as_user(13);
select is(pg_temp.vis_status(), pg_temp.ids(13), 'tanpa keanggotaan: hanya diri sendiri');
select is(pg_temp.vis_points(), pg_temp.ids(13), 'tanpa keanggotaan: titik hanya milik sendiri');

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select is((select count(*)::int from public.events where user_id = pg_temp.uid(2)), 1,
  'anggota Circle melihat event Circle (e1) tetapi tidak event tanpa Circle (e2)');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(7)), 0, 'event Circle lain tidak terlihat');
select pg_temp.as_user(2);
select is((select count(*)::int from public.events where user_id = pg_temp.uid(2)), 2,
  'pemilik melihat event miliknya termasuk yang tanpa Circle');
select pg_temp.as_user(7);
select is((select count(*)::int from public.events where user_id = pg_temp.uid(2)), 0, 'orang asing tidak melihat event');

-- ---------------------------------------------------------------------------
-- Perubahan dinamis
-- ---------------------------------------------------------------------------
select pg_temp.as_user(3);
select public.resume_sharing('c1c1c1c1-0000-0000-0000-000000000001');
select pg_temp.as_user(1);
select is(pg_temp.n_points(3) + pg_temp.n_status(3), 2, 'setelah resume_sharing, anggota terlihat lagi');

select pg_temp.as_user(2);
select public.pause_sharing('c1c1c1c1-0000-0000-0000-000000000001', 30);
select pg_temp.as_user(1);
select is(pg_temp.n_points(2) + pg_temp.n_status(2), 0, 'setelah pause_sharing, langsung tidak terlihat');
reset role;
update public.circle_members set paused_until = now() - interval '1 second'
where user_id = pg_temp.uid(2);
select pg_temp.as_user(1);
select is(pg_temp.n_points(2), 2, 'jeda kedaluwarsa: terlihat lagi');

select pg_temp.as_user(2);
select public.leave_circle('c1c1c1c1-0000-0000-0000-000000000001');
select pg_temp.as_user(1);
select is(pg_temp.n_points(2) + pg_temp.n_status(2), 0, 'keluar Circle memutus akses ke lokasi');
select pg_temp.as_user(2);
select is(pg_temp.n_points(2), 3, 'yang keluar tetap melihat datanya sendiri');

-- ---------------------------------------------------------------------------
-- upload_points dan jeda
-- ---------------------------------------------------------------------------
-- X dan Y untuk u21 sampai u28
reset role;
insert into public.circles (id, name) values
  ('a1a1a1a1-0000-0000-0000-000000000001', 'X'), ('b1b1b1b1-0000-0000-0000-000000000001', 'Y');
insert into public.circle_members (circle_id, user_id, role, sharing_enabled, paused_until) values
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(21), 'admin', true, 'infinity'),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(22), 'admin', true, 'infinity'),
  ('b1b1b1b1-0000-0000-0000-000000000001', pg_temp.uid(22), 'member', true, now() + interval '1 hour'),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(23), 'admin', true, 'infinity'),
  ('b1b1b1b1-0000-0000-0000-000000000001', pg_temp.uid(23), 'member', true, null),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(24), 'admin', false, null),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(25), 'admin', true, now() - interval '1 minute'),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(26), 'admin', true, 'infinity'),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(27), 'admin', true, null),
  ('a1a1a1a1-0000-0000-0000-000000000001', pg_temp.uid(28), 'admin', false, null),
  ('b1b1b1b1-0000-0000-0000-000000000001', pg_temp.uid(28), 'member', true, null);

select pg_temp.as_user(20);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 1, 'tanpa keanggotaan: titik diterima');
select pg_temp.as_user(21);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5), pg_temp.pt(6), pg_temp.pt(7))), 0,
  'semua keanggotaan dijeda: batch dilewati (0, tanpa galat)');
select pg_temp.as_user(22);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 0, 'dua keanggotaan, keduanya dijeda: dilewati');
select pg_temp.as_user(23);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 1, 'satu keanggotaan aktif: diterima');
select pg_temp.as_user(24);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 0, 'sharing_enabled=false di satu-satunya keanggotaan: dilewati');
select pg_temp.as_user(25);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 1, 'jeda sudah lewat: diterima');
select pg_temp.as_user(28);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 1, 'sharing off di X tetapi aktif di Y: diterima');

reset role;
select is((select count(*)::int from public.location_points where user_id in (pg_temp.uid(21), pg_temp.uid(22), pg_temp.uid(24))),
  0, 'tidak ada titik tersimpan dari pengguna yang dijeda');
select is((select count(*)::int from public.member_status where user_id in (pg_temp.uid(21), pg_temp.uid(22), pg_temp.uid(24))),
  0, 'tidak ada member_status dari pengguna yang dijeda');
select is((select count(*)::int from public.location_points where user_id in (pg_temp.uid(20), pg_temp.uid(23), pg_temp.uid(25), pg_temp.uid(28))),
  4, 'titik pengguna yang diterima tersimpan');

-- validasi dan TH001 tetap berlaku lebih dulu untuk pengguna yang dijeda
select pg_temp.as_user(26);
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 91, 'lng', 106, 'recorded_at', now())))$$, '22023', null::text,
  'pengguna dijeda: input tidak valid tetap 22023');
select throws_ok($$select public.upload_points(jsonb_build_array(
  jsonb_build_object('lat', 1, 'lng', 106, 'recorded_at', now() + interval '1 hour')))$$, 'TH001', null::text,
  'pengguna dijeda: recorded_at di masa depan tetap TH001');

-- jeda dan lanjut lewat RPC memengaruhi upload_points
select pg_temp.as_user(27);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(5))), 1, 'sebelum jeda: diterima');
select public.pause_sharing('a1a1a1a1-0000-0000-0000-000000000001', 15);
select is(public.upload_points(jsonb_build_array(pg_temp.pt(6))), 0, 'setelah pause_sharing: dilewati');
select public.resume_sharing('a1a1a1a1-0000-0000-0000-000000000001');
select is(public.upload_points(jsonb_build_array(pg_temp.pt(7))), 1, 'setelah resume_sharing: diterima lagi');
reset role;
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(27)), 2,
  'hanya dua titik (sebelum jeda dan setelah resume) yang tersimpan');

select * from finish();
rollback;
