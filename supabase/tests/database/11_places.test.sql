-- Sprint 4: tempat per Circle (RLS, create/update/delete_place, batas 5 tempat, radius, hak ubah).
begin;
create extension if not exists pgtap with schema extensions;
select plan(62);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- buat tempat sebagai pengguna n di Circle C1, lintang/bujur dasar -6.2 / 106.8
create function pg_temp.mk(n int, nm text, c uuid default 'c1c1c1c1-0000-0000-0000-000000000001',
                           r int default 150) returns uuid language plpgsql as $$
declare v uuid;
begin
  perform pg_temp.as_user(n);
  select public.create_place(c, nm, -6.2, 106.8, r) into v;
  reset role;
  return v;
end $$;

insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 6) n;

-- C1: u1 admin, u2 member, u3 member. C2: u4 admin. u5 asing. u6 anggota C1 dan C2.
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C1'), ('c2c2c2c2-0000-0000-0000-000000000002', 'C2');
insert into public.circle_members (circle_id, user_id, role, joined_at) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin', now() - interval '3 days'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member', now() - interval '2 days'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(3), 'member', now() - interval '1 day'),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(4), 'admin', now()),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(6), 'member', now()),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(6), 'member', now());

-- Skema
select col_not_null('public', 'places', 'circle_id', 'places.circle_id NOT NULL');
select has_column('public', 'places', 'created_by', 'places.created_by ada');

-- ---------------------------------------------------------------------------
-- create_place: anggota biasa boleh (F7)
-- ---------------------------------------------------------------------------
select lives_ok($$select pg_temp.mk(2, 'Rumah')$$, 'anggota biasa (bukan admin) boleh membuat tempat');
select is((select created_by from public.places where name = 'Rumah'), pg_temp.uid(2), 'created_by = pembuat (auth.uid)');
select is((select circle_id from public.places where name = 'Rumah'), 'c1c1c1c1-0000-0000-0000-000000000001'::uuid,
  'circle_id sesuai argumen');
select ok((select abs(extensions.ST_Y(center::extensions.geometry) - (-6.2)) < 1e-9
                  and abs(extensions.ST_X(center::extensions.geometry) - 106.8) < 1e-9
                  and radius_m = 150
           from public.places where name = 'Rumah'),
  'koordinat (lat -6.2, lng 106.8) dan radius tersimpan benar (urutan bujur-lintang tidak tertukar)');
select pg_temp.as_user(3);
select is((select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', '  Sekolah  ', -6.21, 106.81, 100)) is not null,
  true, 'create_place mengembalikan uuid');
reset role;
select is((select count(*)::int from public.places where name = 'Sekolah'), 1, 'nama di-trim');

-- Validasi (22023), pesan tanpa koordinat
select pg_temp.as_user(2);
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', '', -6.2, 106.8, 150)$$,
  '22023', 'nama tempat harus 1 sampai 40 karakter', 'nama kosong ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', '   ', -6.2, 106.8, 150)$$,
  '22023', 'nama tempat harus 1 sampai 40 karakter', 'nama hanya spasi ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', repeat('x', 41), -6.2, 106.8, 150)$$,
  '22023', 'nama tempat harus 1 sampai 40 karakter', 'nama 41 karakter ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', -6.2, 106.8, 99)$$,
  '22023', 'radius harus 100 sampai 5000 meter', 'radius 99 ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', -6.2, 106.8, 50)$$,
  '22023', 'radius harus 100 sampai 5000 meter', 'radius 50 (batas spike lama) ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', -6.2, 106.8, 5001)$$,
  '22023', 'radius harus 100 sampai 5000 meter', 'radius 5001 ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', -6.2, 106.8, null)$$,
  '22023', 'radius harus 100 sampai 5000 meter', 'radius null ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', 91.234567, 106.8, 150)$$,
  '22023', 'koordinat tidak valid', 'lat 91 ditolak (pesan tanpa angka koordinat)');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', -6.2, 181.234567, 150)$$,
  '22023', 'koordinat tidak valid', 'lng 181 ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', 'NaN', 106.8, 150)$$,
  '22023', 'koordinat tidak valid', 'lat NaN ditolak');
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'R', null, 106.8, 150)$$,
  '22023', 'koordinat tidak valid', 'lat null ditolak');
reset role;
select is((select count(*)::int from public.places), 2, 'validasi gagal tidak menyisakan baris (hanya Rumah dan Sekolah)');

-- Batas radius dan koordinat tepi diterima
select lives_ok($$select pg_temp.mk(1, 'Radius100', 'c1c1c1c1-0000-0000-0000-000000000001', 100)$$, 'radius 100 diterima');
select lives_ok($$select pg_temp.mk(1, 'Radius5000', 'c1c1c1c1-0000-0000-0000-000000000001', 5000)$$, 'radius 5000 diterima');

-- Bukan anggota / Circle tidak ada: galat sama (tidak membocorkan keberadaan Circle)
select pg_temp.as_user(5);
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'X', -6.2, 106.8, 150)$$,
  '42501', 'bukan anggota circle', 'orang asing tidak bisa membuat tempat di Circle');
select throws_ok($$select public.create_place('99999999-0000-0000-0000-000000000009', 'X', -6.2, 106.8, 150)$$,
  '42501', 'bukan anggota circle', 'Circle tidak ada: galat sama dengan bukan anggota');
select throws_ok($$select public.create_place(null, 'X', -6.2, 106.8, 150)$$,
  '42501', 'bukan anggota circle', 'circle null: galat sama');
reset role;

-- Batas 5 tempat per Circle (C1 sekarang punya 4: Rumah, Sekolah, Radius100, Radius5000)
select lives_ok($$select pg_temp.mk(3, 'Kelima')$$, 'tempat ke-5 diterima');
select pg_temp.as_user(1);
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'Keenam', -6.2, 106.8, 150)$$,
  'TH005', 'batas tempat per circle tercapai', 'tempat ke-6 ditolak (TH005), juga untuk admin');
reset role;
select is((select count(*)::int from public.places where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'), 5,
  'C1 tetap 5 tempat');
select lives_ok($$select pg_temp.mk(4, 'Tempat C2', 'c2c2c2c2-0000-0000-0000-000000000002')$$,
  'batas dihitung per Circle: C2 tetap bisa membuat');

-- Tanpa login
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'X', -6.2, 106.8, 150)$$,
  '28000', 'tidak terautentikasi', 'tanpa JWT: 28000');
reset role;
set local role anon;
select throws_ok($$select public.create_place('c1c1c1c1-0000-0000-0000-000000000001', 'X', -6.2, 106.8, 150)$$,
  '42501', null::text, 'anon tidak bisa memanggil create_place');
select throws_ok($$select public.delete_place('00000000-0000-0000-0000-000000000000')$$,
  '42501', null::text, 'anon tidak bisa memanggil delete_place');
reset role;

-- ---------------------------------------------------------------------------
-- Matriks RLS SELECT
-- ---------------------------------------------------------------------------
select pg_temp.as_user(3);
select is((select count(*)::int from public.places), 5, 'anggota C1 melihat 5 tempat C1 dan tidak melihat tempat C2');
select is((select count(*)::int from public.places where name = 'Tempat C2'), 0, 'anggota C1 tidak melihat tempat C2');
select pg_temp.as_user(4);
select is((select array_agg(name) from public.places), array['Tempat C2'], 'anggota C2 hanya melihat tempat C2');
select pg_temp.as_user(6);
select is((select count(*)::int from public.places), 6, 'anggota dua Circle melihat tempat keduanya (5 + 1)');
select pg_temp.as_user(5);
select is((select count(*)::int from public.places), 0, 'orang asing tidak melihat tempat apa pun');
reset role;
set local role anon;
select throws_ok($$select count(*) from public.places$$, '42501', null::text, 'anon tidak bisa SELECT places');
reset role;

-- Tulis langsung ditolak (hanya lewat RPC)
select pg_temp.as_user(1);
select throws_ok($$insert into public.places (circle_id, name, center, radius_m)
  values ('c1c1c1c1-0000-0000-0000-000000000001', 'Langsung', extensions.ST_GeogFromText('POINT(0 0)'), 100)$$,
  '42501', null::text, 'admin tidak bisa INSERT langsung ke places');
select throws_ok($$update public.places set radius_m = 100$$, '42501', null::text, 'UPDATE langsung ditolak');
select throws_ok($$delete from public.places$$, '42501', null::text, 'DELETE langsung ditolak');
reset role;

-- ---------------------------------------------------------------------------
-- update_place dan delete_place: hanya pembuat atau admin
-- ---------------------------------------------------------------------------
-- Rumah dibuat u2. u3 (anggota biasa, bukan pembuat) tidak berhak. u1 (admin) berhak.
select pg_temp.as_user(3);
select throws_ok($$select public.update_place((select id from public.places where name = 'Rumah'), 'Diubah', 200)$$,
  '42501', 'hanya pembuat atau admin', 'anggota biasa non-pembuat tidak bisa mengubah');
select throws_ok($$select public.delete_place((select id from public.places where name = 'Rumah'))$$,
  '42501', 'hanya pembuat atau admin', 'anggota biasa non-pembuat tidak bisa menghapus');
select pg_temp.as_user(5);
select throws_ok($$select public.update_place((select id from public.places where name = 'Rumah'), 'Diubah', 200)$$,
  'P0002', 'tempat tidak ditemukan', 'orang asing: P0002');
select throws_ok($$select public.delete_place((select id from public.places where name = 'Rumah'))$$,
  'P0002', 'tempat tidak ditemukan', 'orang asing tidak bisa menghapus: P0002');
select throws_ok($$select public.update_place('99999999-0000-0000-0000-000000000009', 'Diubah', 200)$$,
  'P0002', 'tempat tidak ditemukan', 'tempat tidak ada: galat sama dengan orang asing');
select pg_temp.as_user(4);
select throws_ok($$select public.delete_place((select id from public.places where name = 'Rumah'))$$,
  'P0002', 'tempat tidak ditemukan', 'admin Circle lain tidak bisa menghapus tempat Circle ini');
select pg_temp.as_user(2);
select lives_ok($$select public.update_place((select id from public.places where name = 'Rumah'), 'Rumah Baru', 300)$$,
  'pembuat boleh mengubah');
select throws_ok($$select public.update_place((select id from public.places where name = 'Rumah Baru'), 'x', 99)$$,
  '22023', 'radius harus 100 sampai 5000 meter', 'update dengan radius 99 ditolak');
select throws_ok($$select public.update_place((select id from public.places where name = 'Rumah Baru'), '', 300)$$,
  '22023', 'nama tempat harus 1 sampai 40 karakter', 'update dengan nama kosong ditolak');
reset role;
select is((select radius_m from public.places where name = 'Rumah Baru'), 300, 'radius berubah');
select pg_temp.as_user(1);
select lives_ok($$select public.update_place((select id from public.places where name = 'Rumah Baru'), 'Rumah Admin', 400)$$,
  'admin (bukan pembuat) boleh mengubah');
reset role;
select is((select radius_m from public.places where name = 'Rumah Admin'), 400, 'admin mengubah radius');
select is((select created_by from public.places where name = 'Rumah Admin'), pg_temp.uid(2), 'created_by tidak berubah oleh update');

-- delete_place: pembuat dan admin; event lama tetap, status geofence dikosongkan
insert into public.member_place_state (user_id, circle_id, current_place_id)
select pg_temp.uid(3), circle_id, id from public.places where name = 'Rumah Admin';
insert into public.events (user_id, circle_id, type, place_id, payload)
select pg_temp.uid(3), circle_id, 'arrive', id, '{"place_name":"Rumah Admin"}' from public.places where name = 'Rumah Admin';
select pg_temp.as_user(2);
select lives_ok($$select public.delete_place((select id from public.places where name = 'Rumah Admin'))$$,
  'pembuat boleh menghapus');
reset role;
select is((select count(*)::int from public.places where name = 'Rumah Admin'), 0, 'tempat terhapus');
select is((select current_place_id from public.member_place_state where user_id = pg_temp.uid(3)), null,
  'status geofence yang menunjuk tempat terhapus dikosongkan');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(3) and place_id is null
           and payload ->> 'place_name' = 'Rumah Admin'), 1, 'event lama tetap ada (place_id null, nama di payload)');
select pg_temp.as_user(1);
select lives_ok($$select public.delete_place((select id from public.places where name = 'Sekolah'))$$,
  'admin boleh menghapus tempat milik anggota lain');
reset role;
select is((select count(*)::int from public.places where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'), 3,
  'sisa 3 tempat di C1 setelah dua penghapusan');
select lives_ok($$select pg_temp.mk(3, 'Pengganti')$$, 'setelah penghapusan, kuota terisi lagi bisa dipakai');

-- Circle dihapus -> tempat ikut terhapus
delete from public.circles where id = 'c2c2c2c2-0000-0000-0000-000000000002';
select is((select count(*)::int from public.places where name = 'Tempat C2'), 0, 'tempat ikut terhapus bersama Circle');

select * from finish();
rollback;
