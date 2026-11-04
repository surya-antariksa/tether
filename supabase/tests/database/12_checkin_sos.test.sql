-- Sprint 5: check-in dan SOS (payload, batas laju, jeda, hak akses baca).
begin;
create extension if not exists pgtap with schema extensions;
select plan(57);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- jumlah event tipe t milik pengguna n (dibaca sebagai postgres)
create function pg_temp.evn(n int, t text, c uuid default null) returns int language plpgsql as $$
declare v int;
begin
  select count(*)::int into v from public.events
  where user_id = pg_temp.uid(n) and type = t and (c is null or circle_id = c);
  return v;
end $$;

insert into auth.users (id, email, raw_user_meta_data)
select pg_temp.uid(n), 'u' || n || '@example.test', jsonb_build_object('display_name', 'Nama' || n)
from generate_series(1, 8) n;

-- C1: u1 admin, u2, u3 (dijeda infinity), u4 (sharing_enabled=false), u5.   C2: u1 admin, u6.
-- u7 asing (tanpa Circle). u3 juga ada di C2? tidak. u8 hanya di C2 (anggota tunggal tidak relevan).
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C1'), ('c2c2c2c2-0000-0000-0000-000000000002', 'C2');
insert into public.circle_members (circle_id, user_id, role, sharing_enabled, paused_until) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin', true, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member', true, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(3), 'member', true, 'infinity'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(4), 'member', false, null),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(5), 'member', true, null),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(1), 'admin', true, null),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(6), 'member', true, null),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(8), 'member', false, 'infinity');

-- ===========================================================================
-- checkin
-- ===========================================================================
select pg_temp.as_user(2);
select is((select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'arrived')) is not null, true,
  'checkin mengembalikan id event');
reset role;
select is(pg_temp.evn(2, 'checkin', 'c1c1c1c1-0000-0000-0000-000000000001'), 1, 'ada tepat 1 event checkin di C1');
select is((select payload from public.events where user_id = pg_temp.uid(2) and type = 'checkin'),
  '{"kind": "arrived", "display_name": "Nama2"}'::jsonb, 'payload checkin tepat {kind, display_name}');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(2) and type = 'checkin'
           and payload ?| array['lat', 'lng', 'latitude', 'longitude', 'point', 'coordinates', 'accuracy_m']), 0,
  'payload checkin tanpa koordinat');

-- Pembaca: anggota C1 melihat, orang asing dan anggota C2 saja tidak
select pg_temp.as_user(5);
select is((select count(*)::int from public.events where type = 'checkin'), 1, 'anggota C1 lain membaca checkin');
select pg_temp.as_user(6);
select is((select count(*)::int from public.events where type = 'checkin'), 0, 'anggota C2 (bukan C1) tidak membaca checkin C1');
select pg_temp.as_user(7);
select is((select count(*)::int from public.events), 0, 'orang asing tidak membaca event apa pun');

-- Batas laju: 1 per 30 detik per pengguna per Circle (TH006)
select pg_temp.as_user(2);
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$,
  'TH006', 'terlalu sering check-in', 'check-in kedua dalam 30 detik ditolak (TH006), kind apa pun');
reset role;
select is(pg_temp.evn(2, 'checkin'), 1, 'check-in yang ditolak tidak menulis event');

-- u1 anggota dua Circle: batas laju per Circle, bukan global
select pg_temp.as_user(1);
select lives_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$, 'u1 check-in di C1');
select lives_ok($$select public.checkin('c2c2c2c2-0000-0000-0000-000000000002', 'safe')$$,
  'u1 check-in di C2 tidak terblokir oleh C1 (batas laju per Circle)');
reset role;

-- Setelah 30 detik berlalu (mundurkan created_at) boleh lagi
update public.events set created_at = now() - interval '31 seconds' where user_id = pg_temp.uid(2) and type = 'checkin';
select pg_temp.as_user(2);
select lives_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$, 'setelah 31 detik boleh check-in lagi');
reset role;
select is(pg_temp.evn(2, 'checkin'), 2, 'sekarang 2 event checkin milik u2');
update public.events set created_at = now() - interval '15 seconds' where user_id = pg_temp.uid(2) and type = 'checkin';
select pg_temp.as_user(2);
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$,
  'TH006', null::text, '15 detik: masih diblokir');

-- Validasi dan hak akses
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'sos')$$,
  '22023', 'p_kind harus arrived atau safe', 'kind selain arrived/safe ditolak');
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', null)$$,
  '22023', 'p_kind harus arrived atau safe', 'kind null ditolak');
select pg_temp.as_user(7);
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$,
  '42501', 'bukan anggota circle', 'orang asing tidak bisa check-in');
select throws_ok($$select public.checkin('99999999-0000-0000-0000-000000000009', 'safe')$$,
  '42501', 'bukan anggota circle', 'Circle tidak ada: galat sama');
select pg_temp.as_user(6);
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$,
  '42501', 'bukan anggota circle', 'anggota C2 tidak bisa check-in ke C1');
reset role;
set local role anon;
select throws_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$,
  '42501', null::text, 'anon tidak bisa check-in');
reset role;

-- Berlaku walau dijeda (u3 dijeda infinity) dan walau sharing_enabled=false (u4)
select pg_temp.as_user(3);
select lives_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'arrived')$$, 'check-in tetap berfungsi saat dijeda');
select pg_temp.as_user(4);
select lives_ok($$select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe')$$, 'check-in tetap berfungsi saat sharing_enabled=false');
reset role;
select is(pg_temp.evn(3, 'checkin'), 1, 'event check-in u3 (dijeda) tercatat');

-- ===========================================================================
-- trigger_sos
-- ===========================================================================
select pg_temp.as_user(1);
select is((select public.trigger_sos(-6.123456, 106.654321, 12.5)), 2, 'SOS u1 memberi tahu 2 Circle (C1 dan C2)');
reset role;
select is(pg_temp.evn(1, 'sos'), 2, 'ada 2 event sos milik u1');
select is(pg_temp.evn(1, 'sos', 'c1c1c1c1-0000-0000-0000-000000000001'), 1, 'event sos di C1');
select is(pg_temp.evn(1, 'sos', 'c2c2c2c2-0000-0000-0000-000000000002'), 1, 'event sos di C2');
select is((select payload ->> 'display_name' from public.events where user_id = pg_temp.uid(1) and type = 'sos' limit 1),
  'Nama1', 'payload sos memuat display_name');
select is((select (payload ->> 'lat')::double precision from public.events where user_id = pg_temp.uid(1) and type = 'sos' limit 1),
  -6.123456::double precision, 'payload sos memuat lat persis');
select is((select (payload ->> 'lng')::double precision from public.events where user_id = pg_temp.uid(1) and type = 'sos' limit 1),
  106.654321::double precision, 'payload sos memuat lng persis');
select is((select (payload ->> 'accuracy_m')::real from public.events where user_id = pg_temp.uid(1) and type = 'sos' limit 1),
  12.5::real, 'payload sos memuat accuracy_m');
select ok((select (payload ->> 'triggered_at')::timestamptz between now() - interval '1 minute' and now() + interval '1 minute'
           from public.events where user_id = pg_temp.uid(1) and type = 'sos' limit 1),
  'payload sos memuat triggered_at yang masuk akal');
select is((select jsonb_object_keys_count from (select count(*)::int jsonb_object_keys_count from jsonb_object_keys(
           (select payload from public.events where user_id = pg_temp.uid(1) and type = 'sos' limit 1))) s), 5,
  'payload sos tepat 5 kunci (display_name, lat, lng, accuracy_m, triggered_at)');
select is((select count(*)::int from public.events where type <> 'sos'
           and payload ?| array['lat', 'lng', 'latitude', 'longitude', 'point', 'coordinates']), 0,
  'hanya event sos yang membawa koordinat');

-- Pembaca SOS: anggota Circle itu saja
select pg_temp.as_user(5);
select is((select count(*)::int from public.events where type = 'sos' and user_id = pg_temp.uid(1)), 1,
  'anggota C1 membaca sos u1 di C1 (tepat 1 baris, bukan milik C2)');
select is((select (payload ->> 'lat')::double precision from public.events where type = 'sos' and user_id = pg_temp.uid(1)),
  -6.123456::double precision, 'anggota C1 membaca koordinat SOS');
select pg_temp.as_user(6);
select is((select circle_id from public.events where type = 'sos' and user_id = pg_temp.uid(1)),
  'c2c2c2c2-0000-0000-0000-000000000002'::uuid, 'anggota C2 membaca sos di C2');
select pg_temp.as_user(7);
select is((select count(*)::int from public.events where type = 'sos'), 0, 'orang asing tidak bisa membaca SOS');
reset role;

-- SOS dari anggota yang dijeda di satu-satunya Circle (u3 di C1, infinity): tetap terkirim
select pg_temp.as_user(3);
select is((select public.trigger_sos(-6.2, 106.8)), 1, 'SOS tetap berfungsi saat dijeda (1 Circle)');
reset role;
select is((select payload -> 'accuracy_m' from public.events where user_id = pg_temp.uid(3) and type = 'sos'),
  'null'::jsonb, 'accuracy_m default null tercatat sebagai null');
-- u4 sharing_enabled=false, u8 dijeda di C2
select pg_temp.as_user(4);
select is((select public.trigger_sos(-6.2, 106.8)), 1, 'SOS tetap berfungsi saat sharing_enabled=false');
select pg_temp.as_user(8);
select is((select public.trigger_sos(-6.2, 106.8, 5)), 1, 'SOS tetap berfungsi bagi anggota yang dijeda di C2');
reset role;
select is(pg_temp.evn(8, 'sos', 'c2c2c2c2-0000-0000-0000-000000000002'), 1, 'event sos u8 tercatat di C2');

-- Batas laju: 3 pemicu per 10 menit (u1 sudah 1 pemicu = 2 event). Pemicu dihitung, bukan event.
select pg_temp.as_user(1);
select is((select public.trigger_sos(-6.2, 106.8)), 2, 'pemicu ke-2 diterima');
select is((select public.trigger_sos(-6.2, 106.8)), 2, 'pemicu ke-3 diterima (6 event, 3 pemicu)');
select throws_ok($$select public.trigger_sos(-6.2, 106.8)$$, 'TH007', 'terlalu sering memicu SOS',
  'pemicu ke-4 dalam 10 menit ditolak (TH007)');
reset role;
select is(pg_temp.evn(1, 'sos'), 6, 'pemicu yang ditolak tidak menulis event');
-- pengguna lain tidak terpengaruh
select pg_temp.as_user(5);
select is((select public.trigger_sos(-6.2, 106.8)), 1, 'batas laju per pengguna: u5 tidak terpengaruh');
reset role;
-- setelah 11 menit boleh lagi
update public.events set created_at = now() - interval '11 minutes' where user_id = pg_temp.uid(1) and type = 'sos';
select pg_temp.as_user(1);
select is((select public.trigger_sos(-6.2, 106.8)), 2, 'setelah 10 menit lewat boleh lagi');
reset role;

-- Validasi
select pg_temp.as_user(2);
select throws_ok($$select public.trigger_sos(91.5, 106.8)$$, '22023', 'koordinat tidak valid', 'lat di luar rentang ditolak');
select throws_ok($$select public.trigger_sos(-6.2, 200.5)$$, '22023', 'koordinat tidak valid', 'lng di luar rentang ditolak');
select throws_ok($$select public.trigger_sos(null, 106.8)$$, '22023', 'koordinat tidak valid', 'lat null ditolak');
select throws_ok($$select public.trigger_sos(-6.2, 106.8, -1)$$, '22023', 'akurasi tidak valid', 'akurasi negatif ditolak');
reset role;

-- Tanpa Circle (u7): galat jelas TH008 dan tidak ada event
select pg_temp.as_user(7);
select throws_ok($$select public.trigger_sos(-6.2, 106.8)$$, 'TH008', 'tidak ada circle untuk diberi tahu', 'tanpa Circle: TH008');
reset role;
select is(pg_temp.evn(7, 'sos'), 0, 'tanpa Circle tidak ada event sos');

-- Tanpa login dan anon
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok($$select public.trigger_sos(-6.2, 106.8)$$, '28000', 'tidak terautentikasi', 'tanpa JWT: 28000');
reset role;
set local role anon;
select throws_ok($$select public.trigger_sos(-6.2, 106.8)$$, '42501', null::text, 'anon tidak bisa trigger_sos');
reset role;

select * from finish();
rollback;
