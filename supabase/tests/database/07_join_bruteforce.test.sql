-- Sprint 2: pembatasan percobaan (10 gagal dalam 15 menit -> TH002) untuk join_circle dan preview_invite.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- n percobaan join dengan kode salah; mengembalikan jumlah yang tidak melempar galat
create function pg_temp.fail_joins(n int) returns int language sql as
  $$ select count(*)::int from (select public.join_circle('BAD' || lpad(g::text, 3, '0'))
                                from generate_series(1, n) g) s $$;

-- 1 sampai 6 pengguna uji, 9 pemilik Circle
insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 9) n;
insert into public.circles (id, name, created_by)
values ('c3c3c3c3-0000-0000-0000-000000000003', 'Target', pg_temp.uid(9));
insert into public.circle_members (circle_id, user_id, role)
values ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(9), 'admin');
insert into public.invites (circle_id, code_hash, expires_at)
values ('c3c3c3c3-0000-0000-0000-000000000003', public.hash_invite_code('GOODCD'), now() + interval '1 day');

-- 10 gagal berturut-turut: semuanya dijawab NULL, lalu terkunci
select pg_temp.as_user(1);
select is(pg_temp.fail_joins(10), 10, '10 percobaan gagal pertama dijawab (NULL), belum terkunci');
select throws_ok($$select public.join_circle('BAD999')$$, 'TH002', 'terlalu banyak percobaan',
  'percobaan ke-11 terkunci: TH002');
select throws_ok($$select public.join_circle('GOODCD')$$, 'TH002', 'terlalu banyak percobaan',
  'kode BENAR pun ditolak TH002 saat terkunci');
select throws_ok($$select * from public.preview_invite('GOODCD')$$, 'TH002', 'terlalu banyak percobaan',
  'preview_invite ikut terkunci (percobaan dihitung bersama)');
select throws_ok($$select * from public.preview_invite('BAD999')$$, 'TH002', null::text,
  'preview dengan kode salah juga TH002');

reset role;
select is((select count(*)::int from public.join_attempts where user_id = pg_temp.uid(1) and not succeeded), 10,
  'percobaan saat terkunci tidak dicatat (jendela tidak diperpanjang)');
select is((select count(*)::int from public.circle_members where user_id = pg_temp.uid(1)), 0,
  'pengguna terkunci tidak bergabung');

-- pengguna lain tidak terpengaruh
select pg_temp.as_user(2);
select is(public.join_circle('GOODCD'), 'c3c3c3c3-0000-0000-0000-000000000003'::uuid,
  'pengguna lain tetap bisa bergabung dengan kode benar');

-- jendela 15 menit: kegagalan sedikit di bawah 15 menit masih menghitung
reset role;
update public.join_attempts set attempted_at = now() - interval '14 minutes' where user_id = pg_temp.uid(1);
select pg_temp.as_user(1);
select throws_ok($$select public.join_circle('GOODCD')$$, 'TH002', null::text, '14 menit kemudian masih terkunci');

-- setelah jendela lewat: terbuka lagi
reset role;
update public.join_attempts set attempted_at = now() - interval '16 minutes' where user_id = pg_temp.uid(1);
select pg_temp.as_user(1);
select is(public.join_circle('GOODCD'), 'c3c3c3c3-0000-0000-0000-000000000003'::uuid,
  'setelah 15 menit kunci terbuka dan kode benar diterima');

-- 9 gagal belum mengunci
select pg_temp.as_user(3);
select is(pg_temp.fail_joins(9), 9, '9 percobaan gagal');
select is(public.join_circle('GOODCD'), 'c3c3c3c3-0000-0000-0000-000000000003'::uuid,
  '9 kegagalan belum mengunci: kode benar diterima');

-- kombinasi preview dan join: 5 preview gagal + 5 join gagal = 10 -> terkunci
select pg_temp.as_user(4);
select is((select count(*)::int from (select * from public.preview_invite('PRV111')
           union all select * from public.preview_invite('PRV222')
           union all select * from public.preview_invite('PRV333')
           union all select * from public.preview_invite('PRV444')
           union all select * from public.preview_invite('PRV555')) s), 0, '5 preview gagal');
select is(pg_temp.fail_joins(5), 5, '5 join gagal');
select throws_ok($$select public.join_circle('GOODCD')$$, 'TH002', null::text,
  '5 preview + 5 join gagal = terkunci');

-- keberhasilan tidak dihitung sebagai kegagalan
select pg_temp.as_user(5);
select is((select count(*)::int from (select public.join_circle('GOODCD') from generate_series(1, 15)) s), 15,
  '15 percobaan berhasil/idempoten tidak mengunci');

-- percobaan lama (> 1 hari) dibersihkan
reset role;
insert into public.join_attempts (user_id, attempted_at, succeeded)
values (pg_temp.uid(6), now() - interval '2 days', false);
select pg_temp.as_user(6);
select public.join_circle('BAD000');
reset role;
select is((select count(*)::int from public.join_attempts
           where user_id = pg_temp.uid(6) and attempted_at < now() - interval '1 day'), 0,
  'catatan percobaan lebih dari 1 hari dihapus');

select * from finish();
rollback;
