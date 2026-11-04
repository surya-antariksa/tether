-- Sprint 1: profil (trigger pembuatan profil dan RLS profiles).
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- jumlah baris yang terpengaruh oleh perintah DML (dijalankan dengan peran saat ini)
create function pg_temp.affected(q text) returns int language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end $$;
create function pg_temp.name_of(n int) returns text language sql as
  $$ select display_name from public.profiles where id = pg_temp.uid(n) $$;

-- 1 bernama, 2 tanpa metadata, 3 hanya spasi, 4 41 karakter, 5 anonim, 6 perlu di-trim, 7 orang asing
insert into auth.users (id, email, raw_user_meta_data, is_anonymous) values
  (pg_temp.uid(1), 'u1@example.test', '{"display_name":"Rina"}', false),
  (pg_temp.uid(2), 'u2@example.test', '{}', false),
  (pg_temp.uid(3), 'u3@example.test', '{"display_name":"   "}', false),
  (pg_temp.uid(4), 'u4@example.test', jsonb_build_object('display_name', repeat('x', 41)), false),
  (pg_temp.uid(5), null, null, true),
  (pg_temp.uid(6), 'u6@example.test', '{"display_name":"  Budi  "}', false),
  (pg_temp.uid(7), 'u7@example.test', '{"display_name":"Asing"}', false);

select is((select count(*)::int from public.profiles), 7, 'setiap pengguna baru otomatis punya profil');
select is(pg_temp.name_of(1), 'Rina', 'display_name dari metadata');
select is(pg_temp.name_of(2), 'Pengguna', 'metadata kosong -> Pengguna');
select is(pg_temp.name_of(3), 'Pengguna', 'nama hanya spasi -> Pengguna');
select is(pg_temp.name_of(4), 'Pengguna', 'nama 41 karakter (tidak valid) -> Pengguna');
select is(pg_temp.name_of(5), 'Pengguna', 'pengguna anonim tanpa metadata -> Pengguna');
select is(pg_temp.name_of(6), 'Budi', 'nama di-trim');
select is((select color from public.profiles where id = pg_temp.uid(1)), '#0F766E', 'warna bawaan');
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'RLS aktif di profiles');

-- 1 dan 2 satu Circle; 7 orang asing
insert into public.circles (id, name, created_by)
values ('c1c1c1c1-0000-0000-0000-000000000001', 'Keluarga', pg_temp.uid(1));
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member');

select pg_temp.as_user(1);
select is((select count(*)::int from public.profiles where id = pg_temp.uid(1)), 1, 'melihat profil sendiri');
select is((select count(*)::int from public.profiles where id = pg_temp.uid(2)), 1, 'melihat profil anggota Circle yang sama');
select is((select count(*)::int from public.profiles where id = pg_temp.uid(7)), 0, 'tidak melihat profil orang asing');
select is((select count(*)::int from public.profiles), 2, 'hanya 2 profil terlihat (sendiri dan anggota)');

-- UPDATE kolom yang diizinkan
select is(pg_temp.affected($$update public.profiles set display_name = 'Rina S', color = '#AABBCC',
    avatar_url = 'https://example.test/a.png' where id = '00000000-0000-0000-0000-000000000001'$$),
  1, 'update display_name, color, avatar_url milik sendiri berhasil');
select is(pg_temp.affected($$update public.profiles set display_name = 'Diretas'
    where id = '00000000-0000-0000-0000-000000000002'$$),
  0, 'update profil anggota lain tidak mengubah baris apa pun');
select is(pg_temp.affected($$update public.profiles set display_name = 'Diretas'
    where id = '00000000-0000-0000-0000-000000000007'$$),
  0, 'update profil orang asing tidak mengubah baris apa pun');

-- kolom lain ditolak
select throws_ok($$update public.profiles set id = '00000000-0000-0000-0000-0000000000ff'
  where id = '00000000-0000-0000-0000-000000000001'$$, '42501', null::text, 'update id ditolak');
select throws_ok($$update public.profiles set created_at = now()
  where id = '00000000-0000-0000-0000-000000000001'$$, '42501', null::text, 'update created_at ditolak');
select throws_ok($$update public.profiles set deleted_at = now()
  where id = '00000000-0000-0000-0000-000000000001'$$, '42501', null::text, 'update deleted_at ditolak');

-- constraint
select throws_ok($$update public.profiles set color = 'merah' where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null::text, 'warna bukan hex ditolak');
select throws_ok($$update public.profiles set color = '#12345G' where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null::text, 'warna hex tidak valid ditolak');
select throws_ok($$update public.profiles set display_name = '' where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null::text, 'nama kosong ditolak');
select throws_ok($$update public.profiles set display_name = repeat('x', 41) where id = '00000000-0000-0000-0000-000000000001'$$,
  '23514', null::text, 'nama 41 karakter ditolak');
select throws_ok($$update public.profiles set display_name = null where id = '00000000-0000-0000-0000-000000000001'$$,
  '23502', null::text, 'nama null ditolak');

-- tidak ada INSERT/DELETE dari klien
select throws_ok($$insert into public.profiles (id, display_name)
  values ('00000000-0000-0000-0000-0000000000aa', 'Palsu')$$, '42501', null::text, 'INSERT langsung ditolak');
select throws_ok($$delete from public.profiles where id = '00000000-0000-0000-0000-000000000001'$$,
  '42501', null::text, 'DELETE langsung ditolak');

reset role;
select is((select display_name from public.profiles where id = pg_temp.uid(1)), 'Rina S',
  'nama baru tersimpan');

-- orang asing tidak melihat profil anggota Circle
select pg_temp.as_user(7);
select is((select count(*)::int from public.profiles where id in (pg_temp.uid(1), pg_temp.uid(2))), 0,
  'orang asing tidak melihat profil anggota Circle');
select is((select count(*)::int from public.profiles), 1, 'orang asing hanya melihat dirinya');

-- keluar Circle memutus akses profil
reset role;
delete from public.circle_members where user_id = pg_temp.uid(2);
select pg_temp.as_user(1);
select is((select count(*)::int from public.profiles where id = pg_temp.uid(2)), 0,
  'setelah anggota keluar, profilnya tidak terlihat lagi');

-- anon tidak punya akses
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select count(*) from public.profiles$$, '42501', null::text, 'anon tidak bisa membaca profiles');

select * from finish();
rollback;
