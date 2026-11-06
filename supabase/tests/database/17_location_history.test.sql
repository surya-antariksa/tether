-- Riwayat lokasi 30 hari (F11): baca milik sendiri dan hapus lewat RPC.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.pt(mins numeric) returns jsonb language sql as $$
  select jsonb_build_object('lat', -6.2, 'lng', 106.8167, 'accuracy_m', 10, 'speed_mps', 0,
    'battery_pct', 80, 'is_moving', false, 'recorded_at', now() - mins * interval '1 minute')
$$;

insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 3) n;
insert into public.circles (id, name) values ('c1c1c1c1-0000-0000-0000-000000000001', 'C1');
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member');

-- u1: 3 titik; u2: 2 titik
select pg_temp.as_user(1);
select public.upload_points(jsonb_build_array(pg_temp.pt(30), pg_temp.pt(20), pg_temp.pt(10)));
select pg_temp.as_user(2);
select public.upload_points(jsonb_build_array(pg_temp.pt(15), pg_temp.pt(5)));

-- Baca riwayat sendiri
select pg_temp.as_user(1);
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(1)), 3,
  'u1 membaca 3 titik miliknya');
select is((select min(recorded_at) > now() - interval '30 days' from public.location_points
  where user_id = pg_temp.uid(1)), true, 'titik u1 ada dalam jendela 30 hari');

-- Klien tetap tidak bisa menghapus langsung
select throws_ok($$delete from public.location_points$$, '42501', null::text,
  'DELETE langsung ke location_points ditolak');

-- Hapus riwayat
select is(public.delete_my_location_history(), 3, 'delete_my_location_history mengembalikan 3');
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(1)), 0,
  'riwayat u1 kosong setelah dihapus');
select is(public.delete_my_location_history(), 0, 'idempoten: panggilan kedua mengembalikan 0');

-- Titik pengguna lain tidak terpengaruh
select pg_temp.as_user(2);
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(2)), 2,
  'riwayat u2 tidak terpengaruh');

-- Posisi terakhir (member_status) tidak dihapus
select pg_temp.as_user(1);
select is((select count(*)::int from public.member_status where user_id = pg_temp.uid(1)), 1,
  'member_status u1 tetap ada (lokasi saat ini, bukan riwayat)');

-- Pengguna tanpa titik
select pg_temp.as_user(3);
select is(public.delete_my_location_history(), 0, 'pengguna tanpa titik mendapat 0');

-- Tanpa autentikasi dan anon
reset role;
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok($$select public.delete_my_location_history()$$, '28000', null::text,
  'tanpa auth.uid() ditolak');
reset role;
set local role anon;
select throws_ok($$select public.delete_my_location_history()$$, '42501', null::text,
  'anon tidak bisa memanggil delete_my_location_history');
reset role;
select is((select prosecdef and 'search_path=""' = any (proconfig) from pg_proc
  where oid = 'public.delete_my_location_history()'::regprocedure), true,
  'SECURITY DEFINER dengan search_path kosong');

select * from finish();
rollback;
