-- Sprint 0A (T0.5) dan Sprint 4: geofence di server dengan debounce 2 titik, per Circle.
-- Sejak Sprint 4 status ada di member_place_state (per pengguna dan Circle) dan hanya place milik
-- Circle yang dievaluasi. Place uji "Titik Uji": center lat -6.2000 lng 106.8167, radius 150 m, di C1.
begin;
create extension if not exists pgtap with schema extensions;
select plan(65);

-- Pembantu (hanya hidup selama sesi tes)
create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;

create function pg_temp.pt(lat double precision, lng double precision, mins numeric, acc real default 10)
returns jsonb language sql as $$
  select jsonb_build_object('lat', lat, 'lng', lng, 'accuracy_m', acc, 'speed_mps', 0,
    'battery_pct', 80, 'is_moving', false, 'recorded_at', now() - mins * interval '1 minute')
$$;
-- tepat di center place uji
create function pg_temp.inn(mins numeric, acc real default 10) returns jsonb language sql as
  $$ select pg_temp.pt(-6.2, 106.8167, mins, acc) $$;
-- sekitar 600 m di utara center
create function pg_temp.outp(mins numeric) returns jsonb language sql as
  $$ select pg_temp.pt(-6.1946, 106.8167, mins) $$;

-- Kirim satu batch sebagai pengguna n lewat upload_points.
create function pg_temp.send(n int, variadic pts jsonb[]) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform public.upload_points(to_jsonb(pts));
end $$;

create function pg_temp.ev(n int, t text) returns int language sql as
  $$ select count(*)::int from public.events where user_id = pg_temp.uid(n) and type = t $$;
create function pg_temp.ev_all(n int) returns int language sql as
  $$ select count(*)::int from public.events where user_id = pg_temp.uid(n) $$;
create function pg_temp.ms(n int) returns public.member_status language sql as
  $$ select * from public.member_status where user_id = pg_temp.uid(n) $$;
-- status geofence pengguna n di Circle C1 (baris belum ada = pending 0 dan current null)
create function pg_temp.pc(n int, c uuid default 'c1c1c1c1-0000-0000-0000-000000000001') returns int language sql as
  $$ select coalesce((select pending_count::int from public.member_place_state
                      where user_id = pg_temp.uid(n) and circle_id = c), 0) $$;
create function pg_temp.cur(n int, c uuid default 'c1c1c1c1-0000-0000-0000-000000000001') returns uuid language sql as
  $$ select (select current_place_id from public.member_place_state
             where user_id = pg_temp.uid(n) and circle_id = c) $$;
-- hitung event pengguna n menurut tipe dan Circle
create function pg_temp.evc(n int, t text, c uuid) returns int language sql as
  $$ select count(*)::int from public.events where user_id = pg_temp.uid(n) and type = t and circle_id = c $$;
-- sisipkan titik langsung sebagai postgres (menguji trigger tanpa melewati upload_points)
create function pg_temp.ins(n int, mins numeric, lat double precision default -6.2, lng double precision default 106.8167)
returns void language sql as $$
  insert into public.location_points (user_id, point, accuracy_m, recorded_at)
  values (pg_temp.uid(n), extensions.ST_SetSRID(extensions.ST_MakePoint(lng, lat), 4326)::extensions.geography,
          10, now() - mins * interval '1 minute') $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 20) n;

-- Circle: C1 (tempat Titik Uji, Dekat, Tempat B) berisi u1..u11, u14, u15, u16, u17, u18.
-- C2 (Sekolah C2, di lokasi Tempat B): u14, u19. C3 (Kantor C3, di lokasi Titik Uji): u15, u20.
-- C4 (Kantor C4, di lokasi Titik Uji): u16 (di C1 u16 dijeda). u12 dan u13 tanpa Circle.
-- u17: di C1 dengan sharing_enabled = false. u18: di C1 dengan jeda yang sudah lewat.
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C1'), ('c2c2c2c2-0000-0000-0000-000000000002', 'C2'),
  ('c3c3c3c3-0000-0000-0000-000000000003', 'C3'), ('c4c4c4c4-0000-0000-0000-000000000004', 'C4');
insert into public.circle_members (circle_id, user_id, role, sharing_enabled, paused_until)
select 'c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(n), case when n = 1 then 'admin' else 'member' end,
       n <> 17, case n when 16 then 'infinity'::timestamptz when 18 then now() - interval '1 minute' end
from unnest(array[1,2,3,4,5,6,7,8,9,10,11,14,15,16,17,18]) n;
insert into public.circle_members (circle_id, user_id, role) values
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(14), 'admin'),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(19), 'member'),
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(15), 'admin'),
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(20), 'member'),
  ('c4c4c4c4-0000-0000-0000-000000000004', pg_temp.uid(16), 'admin');

insert into public.places (circle_id, name, center, radius_m) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'Titik Uji', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography, 150),
  ('c1c1c1c1-0000-0000-0000-000000000001', 'Dekat', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.19901), 4326)::extensions.geography, 100),
  ('c1c1c1c1-0000-0000-0000-000000000001', 'Tempat B', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.1964), 4326)::extensions.geography, 100),
  ('c2c2c2c2-0000-0000-0000-000000000002', 'Sekolah C2', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.1964), 4326)::extensions.geography, 100),
  ('c3c3c3c3-0000-0000-0000-000000000003', 'Kantor C3', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography, 150),
  ('c4c4c4c4-0000-0000-0000-000000000004', 'Kantor C4', extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography, 150);

-- Bukti asumsi geometri
select is((select count(*)::int from public.places where name = 'Titik Uji' and radius_m = 150),
  1, 'place uji di C1 ada');
select ok((select extensions.ST_Distance(center, extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography) < 1
           from public.places where name = 'Titik Uji'),
  'titik "dalam" persis di center (jarak < 1 m)');
select ok((select d > 580 and d < 620 and d > radius_m from (
             select extensions.ST_Distance(center, extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.1946), 4326)::extensions.geography) d, radius_m
             from public.places where name = 'Titik Uji') s),
  'titik "luar" sekitar 600 m dan di luar radius 150 m');

-- S1: 1 titik di dalam -> belum ada event
select pg_temp.send(1, pg_temp.inn(20));
select is(pg_temp.ev_all(1), 0, '1 titik di dalam: tidak ada event');
select is(pg_temp.pc(1), 1, '1 titik di dalam: pending_count = 1');
select is(pg_temp.cur(1), null, '1 titik di dalam: current_place_id belum terisi');

-- S2: 2 titik berurutan di dalam -> tepat 1 arrive
select pg_temp.send(2, pg_temp.inn(20));
select pg_temp.send(2, pg_temp.inn(19));
select is(pg_temp.ev(2, 'arrive'), 1, '2 titik di dalam: tepat 1 event arrive');
select is(pg_temp.ev(2, 'leave'), 0, '2 titik di dalam: tidak ada leave');
select is(pg_temp.cur(2), (select id from public.places where name = 'Titik Uji'),
  'current_place_id = place uji');
select is((select payload ->> 'place_name' from public.events where user_id = pg_temp.uid(2) and type = 'arrive'),
  'Titik Uji', 'payload memuat nama place');
select ok((select payload ? 'recorded_at' and not (payload ?| array['lat', 'lng', 'latitude', 'longitude', 'point', 'coordinates'])
           from public.events where user_id = pg_temp.uid(2) and type = 'arrive'),
  'payload memuat recorded_at dan tanpa koordinat');
select pg_temp.send(2, pg_temp.inn(18));
select is(pg_temp.ev_all(2), 1, 'titik ketiga di dalam: tidak ada event tambahan');

-- S3: dalam, luar, dalam (flicker sebelum tiba) -> tidak ada event
select pg_temp.send(3, pg_temp.inn(20));
select pg_temp.send(3, pg_temp.outp(19));
select pg_temp.send(3, pg_temp.inn(18));
select is(pg_temp.ev_all(3), 0, 'flicker dalam-luar-dalam: tidak ada event');
select is(pg_temp.pc(3), 1, 'flicker: pending dimulai ulang dengan count = 1');

-- S4: sudah tiba, flicker keluar sebentar, lalu pergi sungguhan
select pg_temp.send(4, pg_temp.inn(20));
select pg_temp.send(4, pg_temp.inn(19));
select pg_temp.send(4, pg_temp.outp(18));
select pg_temp.send(4, pg_temp.inn(17));
select is(pg_temp.ev_all(4), 1, 'flicker setelah tiba (luar lalu dalam): tidak ada event ganda');
select is(pg_temp.pc(4), 0, 'kembali ke dalam: pending direset');
select pg_temp.send(4, pg_temp.outp(16));
select pg_temp.send(4, pg_temp.outp(15));
select is(pg_temp.ev(4, 'leave'), 1, '2 titik berurutan di luar setelah di dalam: tepat 1 leave');
select is(pg_temp.ev(4, 'arrive'), 1, 'arrive tetap 1');
select is(pg_temp.cur(4), null, 'setelah leave: current_place_id kosong');

-- S5: akurasi buruk diabaikan (dilewati, tidak menghitung dan tidak mereset)
select pg_temp.send(5, pg_temp.inn(20));
select pg_temp.send(5, pg_temp.inn(19, 500));
select is(pg_temp.ev_all(5), 0, 'titik akurasi 500 m tidak ikut debounce');
select is(pg_temp.pc(5), 1, 'titik akurasi buruk tidak menaikkan pending_count');
select pg_temp.send(5, pg_temp.inn(18));
select is(pg_temp.ev(5, 'arrive'), 1, 'titik akurasi baik berikutnya menuntaskan debounce');

-- S6: hanya titik akurasi buruk
select pg_temp.send(6, pg_temp.inn(20, 500), pg_temp.inn(19, 500));
select is(pg_temp.ev_all(6), 0, 'dua titik akurasi buruk di dalam: tidak ada event');
select is(pg_temp.pc(6), 0, 'dua titik akurasi buruk: pending tidak berubah');

-- S7: titik lebih tua dari last_seen_at tidak mengubah status dan tidak memicu event
select pg_temp.send(7, pg_temp.inn(20));
select pg_temp.send(7, pg_temp.inn(19));
select pg_temp.send(7, pg_temp.outp(40), pg_temp.outp(39));
select is(pg_temp.ev(7, 'leave'), 0, 'dua titik luar yang lebih tua: tidak ada leave');
select is(pg_temp.cur(7), (select id from public.places where name = 'Titik Uji'),
  'titik lama: current_place_id tidak berubah');
select is((pg_temp.ms(7)).last_seen_at, now() - interval '19 minutes', 'titik lama: last_seen_at tidak mundur');
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(7)), 4,
  'titik lama tetap tersimpan di location_points');

-- S8: batch tidak berurutan dalam satu panggilan diproses menurut recorded_at
select pg_temp.send(8, pg_temp.inn(18), pg_temp.inn(19));
select is(pg_temp.ev(8, 'arrive'), 1, 'batch terbalik urutan: tetap 1 arrive');
select is((pg_temp.ms(8)).last_seen_at, now() - interval '18 minutes', 'batch terbalik: last_seen_at = titik terbaru');

-- S9: dua place memuat titik -> yang terdekat dipilih
select ok((select extensions.ST_DWithin(s.center, d.center, 1000)
           and extensions.ST_DWithin(s.center, extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.1991), 4326)::extensions.geography, s.radius_m)
           and extensions.ST_DWithin(d.center, extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.1991), 4326)::extensions.geography, d.radius_m)
           from public.places s, public.places d where s.name = 'Titik Uji' and d.name = 'Dekat'),
  'titik uji terdekat berada di dalam radius dua place sekaligus');
select pg_temp.send(9, pg_temp.pt(-6.1991, 106.8167, 20), pg_temp.pt(-6.1991, 106.8167, 19));
select is((select place_id from public.events where user_id = pg_temp.uid(9) and type = 'arrive'),
  (select id from public.places where name = 'Dekat'), 'arrive memakai place terdekat');

-- S10: pindah langsung dari place A ke place B -> leave A lalu arrive B
select pg_temp.send(10, pg_temp.inn(20), pg_temp.inn(19));
select pg_temp.send(10, pg_temp.pt(-6.1964, 106.8167, 18), pg_temp.pt(-6.1964, 106.8167, 17));
select is((select place_id from public.events where user_id = pg_temp.uid(10) and type = 'leave'),
  (select id from public.places where name = 'Titik Uji'), 'pindah A ke B: leave untuk place lama');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(10) and type = 'arrive'
           and place_id = (select id from public.places where name = 'Tempat B')),
  1, 'pindah A ke B: ada tepat 1 arrive untuk place baru');
select is(pg_temp.cur(10), (select id from public.places where name = 'Tempat B'),
  'pindah A ke B: current_place_id = place B');

-- ---------------------------------------------------------------------------
-- Sprint 4: geofence per Circle
-- ---------------------------------------------------------------------------
-- N1: dua Circle dengan tempat berbeda -> event terpisah per Circle. u14 (C1 dan C2): tiba di
-- Titik Uji (hanya C1 yang punya tempat di sana), lalu pindah ke lokasi Tempat B (C1) = Sekolah C2.
select pg_temp.send(14, pg_temp.inn(30), pg_temp.inn(29));
select is(pg_temp.evc(14, 'arrive', 'c1c1c1c1-0000-0000-0000-000000000001'), 1, 'N1: arrive Titik Uji hanya di C1');
select is(pg_temp.ev_all(14), 1, 'N1: tidak ada event di C2 (tidak ada tempat di sana)');
select pg_temp.send(14, pg_temp.pt(-6.1964, 106.8167, 28), pg_temp.pt(-6.1964, 106.8167, 27));
select is(pg_temp.evc(14, 'leave', 'c1c1c1c1-0000-0000-0000-000000000001'), 1, 'N1: leave Titik Uji di C1');
select is((select place_id from public.events where user_id = pg_temp.uid(14) and type = 'arrive'
           and circle_id = 'c2c2c2c2-0000-0000-0000-000000000002'),
  (select id from public.places where name = 'Sekolah C2'), 'N1: arrive di C2 memakai tempat milik C2');
select is((select place_id from public.events where user_id = pg_temp.uid(14) and type = 'arrive'
           and circle_id = 'c1c1c1c1-0000-0000-0000-000000000001' and payload ->> 'place_name' = 'Tempat B'),
  (select id from public.places where name = 'Tempat B'), 'N1: di C1 tempat yang cocok tetap milik C1');
select is(pg_temp.cur(14, 'c2c2c2c2-0000-0000-0000-000000000002'), (select id from public.places where name = 'Sekolah C2'),
  'N1: status C2 terpisah dari status C1');
select is(pg_temp.ev_all(14), 4, 'N1: total 4 event (arrive+leave+arrive di C1, arrive di C2)');

-- N2: tempat berbeda di lokasi yang sama pada dua Circle -> dua event arrive, circle_id berbeda
select pg_temp.send(15, pg_temp.inn(30), pg_temp.inn(29));
select is(pg_temp.evc(15, 'arrive', 'c1c1c1c1-0000-0000-0000-000000000001'), 1, 'N2: arrive di C1');
select is(pg_temp.evc(15, 'arrive', 'c3c3c3c3-0000-0000-0000-000000000003'), 1, 'N2: arrive di C3');
select is((select payload ->> 'place_name' from public.events
           where user_id = pg_temp.uid(15) and circle_id = 'c3c3c3c3-0000-0000-0000-000000000003'),
  'Kantor C3', 'N2: payload C3 memuat nama tempat C3, bukan tempat C1');

-- N3: keanggotaan dijeda tidak dievaluasi dan tidak menghasilkan event; Circle aktif tetap
select pg_temp.send(16, pg_temp.inn(30), pg_temp.inn(29));
select is(pg_temp.evc(16, 'arrive', 'c1c1c1c1-0000-0000-0000-000000000001'), 0, 'N3: Circle yang dijeda (C1) tidak menghasilkan event');
select is(pg_temp.evc(16, 'arrive', 'c4c4c4c4-0000-0000-0000-000000000004'), 1, 'N3: Circle aktif (C4) tetap menghasilkan event');
select is((select count(*)::int from public.member_place_state where user_id = pg_temp.uid(16)
           and circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'), 0, 'N3: tidak ada status geofence untuk Circle yang dijeda');

-- N4: sharing_enabled = false (titik disisipkan langsung agar trigger yang diuji, bukan upload_points)
select pg_temp.ins(17, 30);
select pg_temp.ins(17, 29);
select is(pg_temp.ev_all(17), 0, 'N4: sharing_enabled=false tidak menghasilkan event');
select is((select count(*)::int from public.member_place_state where user_id = pg_temp.uid(17)), 0,
  'N4: sharing_enabled=false tidak membuat status geofence');
select is((select count(*)::int from public.member_status where user_id = pg_temp.uid(17)), 1, 'N4: member_status tetap diperbarui (perilaku lama)');

-- N5: jeda yang sudah lewat dianggap aktif
select pg_temp.send(18, pg_temp.inn(30), pg_temp.inn(29));
select is(pg_temp.ev(18, 'arrive'), 1, 'N5: jeda yang sudah lewat tidak menghalangi event');

-- N6: titik tanpa keanggotaan Circle tidak menghasilkan event
select pg_temp.send(13, pg_temp.inn(30), pg_temp.inn(29));
select is(pg_temp.ev_all(13), 0, 'N6: tanpa Circle tidak ada event');
select is((select count(*)::int from public.member_place_state where user_id = pg_temp.uid(13)), 0,
  'N6: tanpa Circle tidak ada status geofence');
select is((select count(*)::int from public.member_status where user_id = pg_temp.uid(13)), 1, 'N6: member_status tetap terisi');

-- N7: anggota lain Circle membaca event arrive lewat RLS, orang asing dan Circle lain tidak
select pg_temp.as_user(11);
select is((select count(*)::int from public.events where user_id = pg_temp.uid(2) and type = 'arrive'), 1,
  'N7: anggota C1 lain membaca event arrive u2');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(15)
           and circle_id = 'c3c3c3c3-0000-0000-0000-000000000003'), 0,
  'N7: anggota C1 tidak membaca event u15 di C3 (bukan anggota C3)');
select pg_temp.as_user(20);
select is((select count(*)::int from public.events where user_id = pg_temp.uid(15)
           and circle_id = 'c3c3c3c3-0000-0000-0000-000000000003'), 1,
  'N7: anggota C3 membaca event arrive u15 di C3');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(15)
           and circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'), 0,
  'N7: anggota C3 tidak membaca event u15 di C1');
select pg_temp.as_user(12);
select is((select count(*)::int from public.events), 0, 'N7: orang asing tidak membaca event apa pun');
select is((select count(*)::int from public.places), 0, 'N7: orang asing tidak membaca place apa pun');
reset role;

-- N8: keluar dari Circle menghapus status geofence Circle itu; kolom lama member_status tidak dipakai
select pg_temp.send(19, pg_temp.pt(-6.1964, 106.8167, 20), pg_temp.pt(-6.1964, 106.8167, 19));
select is(pg_temp.cur(19, 'c2c2c2c2-0000-0000-0000-000000000002'), (select id from public.places where name = 'Sekolah C2'),
  'N8: u19 tiba di Sekolah C2');
delete from public.circle_members where circle_id = 'c2c2c2c2-0000-0000-0000-000000000002' and user_id = pg_temp.uid(19);
select is((select count(*)::int from public.member_place_state where user_id = pg_temp.uid(19)), 0,
  'N8: status geofence ikut terhapus saat keluar Circle');
select is((select count(*)::int from public.member_status
           where current_place_id is not null or pending_place_id is not null or pending_count <> 0 or pending_is_outside), 0,
  'N8: kolom geofence lama di member_status tidak pernah terisi');

-- N9: payload semua event geofence tanpa koordinat
select is((select count(*)::int from public.events where type in ('arrive', 'leave')
           and (payload ?| array['lat', 'lng', 'latitude', 'longitude', 'point', 'coordinates'])), 0,
  'N9: tidak ada payload arrive/leave yang memuat koordinat');

select * from finish();
rollback;
