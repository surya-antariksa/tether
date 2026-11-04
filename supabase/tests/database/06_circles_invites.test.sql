-- Sprint 2: create_circle, create_invite, preview_invite, join_circle (tanpa brute force).
begin;
create extension if not exists pgtap with schema extensions;
select plan(63);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- id Circle dan kode disimpan di GUC transaksi: t.c1, t.code_old, t.code
create function pg_temp.c1() returns uuid language sql as $$ select current_setting('t.c1')::uuid $$;
-- jumlah percobaan gagal/berhasil milik pengguna n (dibaca sebagai postgres)
create function pg_temp.attempts(n int, ok boolean) returns int language sql as
  $$ select count(*)::int from public.join_attempts where user_id = pg_temp.uid(n) and succeeded = ok $$;

-- 1 admin, 2 anggota, 3 pengguna yang mencoba macam-macam kode, 4 sampai 14 pengguna lain
insert into auth.users (id, email, raw_user_meta_data)
select pg_temp.uid(n), 'u' || n || '@example.test', jsonb_build_object('display_name', 'User' || n)
from generate_series(1, 14) n;

-- ---------------------------------------------------------------------------
-- create_circle
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select set_config('t.c1', public.create_circle('  Keluarga  ')::text, true);
select ok(pg_temp.c1() is not null, 'create_circle mengembalikan id');
select is((select name from public.circles where id = pg_temp.c1()), 'Keluarga', 'nama di-trim');
select is((select role from public.circle_members where circle_id = pg_temp.c1() and user_id = pg_temp.uid(1)),
  'admin', 'pembuat menjadi admin');
select is((select created_by from public.circles where id = pg_temp.c1()), pg_temp.uid(1), 'created_by = auth.uid()');

select throws_ok($$select public.create_circle('')$$, '22023', null::text, 'nama kosong ditolak');
select throws_ok($$select public.create_circle('   ')$$, '22023', null::text, 'nama hanya spasi ditolak');
select throws_ok($$select public.create_circle(repeat('x', 41))$$, '22023', null::text, 'nama 41 karakter ditolak');
select throws_ok($$select public.create_circle(null)$$, '22023', null::text, 'nama null ditolak');

-- batas 5: sudah 1, tambah 4 -> total 5, yang ke-6 ditolak
select is((select count(*)::int from (select public.create_circle('C' || g) from generate_series(1, 4) g) s),
  4, 'membuat 4 Circle lagi (total 5) berhasil');
select throws_ok($$select public.create_circle('Keenam')$$, 'TH004', 'batas circle tercapai',
  'Circle ke-6 ditolak dengan TH004');
select pg_temp.as_user(2);
select lives_ok($$select public.create_circle('Milik 2')$$, 'batas per pengguna: pengguna lain tetap bisa membuat');

select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.create_circle('X')$$, '28000', null::text, 'tanpa login ditolak');

-- ---------------------------------------------------------------------------
-- create_invite
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select set_config('t.code_old', (select code from public.create_invite(pg_temp.c1())), true);
select set_config('t.code', (select code from public.create_invite(pg_temp.c1())), true);
select matches(current_setting('t.code'), '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
  'kode 6 karakter dari alfabet tanpa 0, O, 1, I, L');
select is((select expires_at from public.create_invite(pg_temp.c1()) limit 1) - now(), interval '48 hours',
  'kode berlaku 48 jam');
-- catatan: pemanggilan di atas membuat undangan ke-3 dan mencabut yang ke-2; ambil ulang kode terbaru
select set_config('t.code', (select code from public.create_invite(pg_temp.c1())), true);

reset role;
select is((select count(*)::int from public.invites where circle_id = pg_temp.c1() and revoked_at is null),
  1, 'hanya satu undangan aktif per Circle');
select is((select count(*)::int from public.invites where circle_id = pg_temp.c1() and revoked_at is not null),
  3, 'undangan lama dicabut (revoked_at terisi)');
select is((select code_hash from public.invites where circle_id = pg_temp.c1() and revoked_at is null),
  encode(sha256(convert_to(current_setting('t.code'), 'UTF8')), 'hex'), 'code_hash = sha256 hex dari kode');
select is((select count(*)::int from public.invites where code_hash = current_setting('t.code')), 0,
  'kode asli tidak disimpan');
select is((select max_uses || '/' || used_count from public.invites
           where circle_id = pg_temp.c1() and revoked_at is null), '10/0', 'max_uses 10, used_count 0');

-- generator: alfabet benar, semua 31 simbol muncul, tanpa karakter ambigu
select is((select count(*)::int from (select public.generate_invite_code() c from generate_series(1, 400)) s
           where c !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$'), 0, '400 kode acak semuanya sesuai alfabet');
select is((select count(distinct ch)::int
           from (select regexp_split_to_table(string_agg(public.generate_invite_code(), ''), '') ch
                 from generate_series(1, 400)) s), 31, 'ke-31 simbol alfabet terpakai');

select pg_temp.as_user(3);
select throws_ok(format($$select public.create_invite(%L)$$, pg_temp.c1()), '42501', 'hanya admin',
  'bukan anggota tidak bisa membuat undangan');
select throws_ok($$select public.create_invite('00000000-0000-0000-0000-00000000dead')$$, '42501', 'hanya admin',
  'Circle tidak ada: galat sama (tidak membocorkan keberadaan)');
select set_config('request.jwt.claims', '', true);
select throws_ok(format($$select public.create_invite(%L)$$, pg_temp.c1()), '28000', null::text,
  'create_invite tanpa login ditolak');

-- ---------------------------------------------------------------------------
-- preview_invite (pengguna 3)
-- ---------------------------------------------------------------------------
select pg_temp.as_user(3);
select is((select circle_name from public.preview_invite(current_setting('t.code'))), 'Keluarga',
  'preview mengembalikan nama Circle');
select is((select member_count from public.preview_invite(current_setting('t.code'))), 1,
  'preview mengembalikan jumlah anggota');
select is((select circle_name from public.preview_invite('  ' || lower(current_setting('t.code')) || ' ')), 'Keluarga',
  'kode dinormalisasi (trim dan huruf besar)');
select is((select count(*)::int from public.circle_members where circle_id = pg_temp.c1() and user_id = pg_temp.uid(3)),
  0, 'preview tidak bergabung');
select is((select count(*)::int from public.preview_invite('ZZZZZZ')), 0, 'preview kode salah: nol baris');
select is((select count(*)::int from public.preview_invite(null)), 0, 'preview kode null: nol baris');
select is((select count(*)::int from public.preview_invite(current_setting('t.code_old'))), 0,
  'preview kode yang sudah dicabut: nol baris');
select set_config('request.jwt.claims', '', true);
select throws_ok($$select * from public.preview_invite('ABCDEF')$$, '28000', null::text,
  'preview tanpa login ditolak');

reset role;
select is(pg_temp.attempts(3, false), 3, 'preview gagal dicatat di join_attempts (tidak ikut rollback)');
select is(pg_temp.attempts(3, true), 3, 'preview berhasil juga dicatat');
select is((select used_count from public.invites where code_hash = public.hash_invite_code(current_setting('t.code'))), 0,
  'preview tidak menaikkan used_count');

-- ---------------------------------------------------------------------------
-- join_circle
-- ---------------------------------------------------------------------------
-- kode khusus (dimasukkan sebagai postgres): kedaluwarsa, dicabut, habis, dan Circle penuh
insert into public.circles (id, name) values
  ('c2c2c2c2-0000-0000-0000-000000000002', 'Penuh');
insert into public.circle_members (circle_id, user_id, role)
select 'c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(n), case when n = 4 then 'admin' else 'member' end
from generate_series(4, 13) n;
insert into public.invites (circle_id, code_hash, expires_at, revoked_at, used_count, max_uses) values
  (pg_temp.c1(), public.hash_invite_code('EXPIRD'), now() - interval '1 minute', null, 0, 10),
  (pg_temp.c1(), public.hash_invite_code('REVOKD'), now() + interval '1 day', now(), 0, 10),
  (pg_temp.c1(), public.hash_invite_code('USEDUP'), now() + interval '1 day', null, 2, 2),
  ('c2c2c2c2-0000-0000-0000-000000000002', public.hash_invite_code('FULLXX'), now() + interval '1 day', null, 0, 10);

select pg_temp.as_user(3);
select is(public.join_circle('ZZZZZZ'), null, 'kode salah: NULL');
select is(public.join_circle(current_setting('t.code_old')), null, 'kode yang sudah dicabut (diganti): NULL');
select is(public.join_circle('EXPIRD'), null, 'kode kedaluwarsa: NULL');
select is(public.join_circle('REVOKD'), null, 'kode dicabut: NULL');
select is(public.join_circle('USEDUP'), null, 'kode habis dipakai: NULL');
select is(public.join_circle(null), null, 'kode null: NULL');
select is((select count(*)::int from public.circle_members where user_id = pg_temp.uid(3)), 0,
  'tidak ada keanggotaan dari kode yang tidak valid');
select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.join_circle('ABCDEF')$$, '28000', null::text, 'join tanpa login ditolak');

reset role;
select is(pg_temp.attempts(3, false), 3 + 6, 'semua kegagalan join dicatat (total 9 gagal)');

-- berhasil: pengguna 2 dengan kode persis, pengguna 3 dengan kode huruf kecil berspasi
select pg_temp.as_user(2);
select is(public.join_circle(current_setting('t.code')), pg_temp.c1(), 'kode benar: mengembalikan circle_id');
select pg_temp.as_user(3);
select is(public.join_circle('  ' || lower(current_setting('t.code')) || ' '), pg_temp.c1(),
  'kode dinormalisasi saat join');

reset role;
select is((select role from public.circle_members where circle_id = pg_temp.c1() and user_id = pg_temp.uid(2)),
  'member', 'yang bergabung berperan member');
select is((select used_count from public.invites where code_hash = public.hash_invite_code(current_setting('t.code'))), 2,
  'used_count naik untuk tiap anggota baru');
select is((select count(*)::int from public.events where circle_id = pg_temp.c1() and type = 'member_joined'),
  2, 'event member_joined tercatat per anggota baru');
select is((select payload from public.events where circle_id = pg_temp.c1() and type = 'member_joined'
           and user_id = pg_temp.uid(2)), '{"display_name": "User2"}'::jsonb,
  'payload hanya display_name (tanpa koordinat)');

-- idempoten
select pg_temp.as_user(2);
select is(public.join_circle(current_setting('t.code')), pg_temp.c1(), 'sudah anggota: circle_id lagi');
reset role;
select is((select used_count from public.invites where code_hash = public.hash_invite_code(current_setting('t.code'))), 2,
  'idempoten: used_count tidak naik');
select is((select count(*)::int from public.circle_members where circle_id = pg_temp.c1()), 3,
  'idempoten: tidak ada anggota ganda');
select is((select count(*)::int from public.events where circle_id = pg_temp.c1() and type = 'member_joined'),
  2, 'idempoten: tidak ada event ganda');

-- member_count pada preview ikut naik
select pg_temp.as_user(5);
select is((select member_count from public.preview_invite(current_setting('t.code'))), 3, 'preview menghitung 3 anggota');

-- Circle penuh (10 anggota)
select pg_temp.as_user(14);
select throws_ok($$select public.join_circle('FULLXX')$$, 'TH003', 'circle penuh', 'Circle penuh ditolak dengan TH003');
select is((select count(*)::int from public.preview_invite('FULLXX')), 1, 'preview Circle penuh tetap tampil');
select is((select member_count from public.preview_invite('FULLXX')), 10, 'preview Circle penuh: 10 anggota');
select pg_temp.as_user(4);
select is(public.join_circle('FULLXX'), 'c2c2c2c2-0000-0000-0000-000000000002'::uuid,
  'anggota Circle penuh yang memanggil ulang: idempoten, bukan galat');
reset role;
select is((select count(*)::int from public.circle_members where circle_id = 'c2c2c2c2-0000-0000-0000-000000000002'),
  10, 'Circle penuh tetap 10 anggota');
select is((select used_count from public.invites where code_hash = public.hash_invite_code('FULLXX')), 0,
  'Circle penuh: used_count tidak naik');

-- anggota biasa tidak bisa membuat undangan
select pg_temp.as_user(2);
select throws_ok(format($$select public.create_invite(%L)$$, pg_temp.c1()), '42501', 'hanya admin',
  'anggota biasa tidak bisa membuat undangan');

-- batas anggota: Circle dengan 9 anggota + 1 pendatang = 10 diterima
reset role;
delete from public.circle_members where circle_id = 'c2c2c2c2-0000-0000-0000-000000000002' and user_id = pg_temp.uid(13);
select pg_temp.as_user(14);
select is(public.join_circle('FULLXX'), 'c2c2c2c2-0000-0000-0000-000000000002'::uuid, 'anggota ke-10 diterima');

select * from finish();
rollback;
