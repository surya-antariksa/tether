-- Sprint 0A: pembersih retensi 48 jam.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-00000000000a', 'a@example.test');

insert into public.location_points (user_id, point, recorded_at)
select 'aaaaaaaa-0000-0000-0000-00000000000a',
       extensions.ST_SetSRID(extensions.ST_MakePoint(106.9, -6.3), 4326)::extensions.geography,
       now() - h * interval '1 hour'
from unnest(array[72, 49, 47, 1]) h;

select is(public.purge_old_location_points(), 2, 'purge menghapus 2 titik (72 jam dan 49 jam)');
select is((select count(*)::int from public.location_points), 2, 'tersisa 2 titik');
select is((select count(*)::int from public.location_points where recorded_at < now() - interval '48 hours'),
  0, 'tidak ada titik lebih tua dari 48 jam');
select is((select count(*)::int from public.location_points
           where recorded_at in (now() - interval '47 hours', now() - interval '1 hour')),
  2, 'titik 47 jam dan 1 jam tetap ada');

select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select public.purge_old_location_points()$$, '42501', null::text,
  'authenticated tidak bisa menjalankan purge');
reset role;
set local role anon;
select throws_ok($$select public.purge_old_location_points()$$, '42501', null::text,
  'anon tidak bisa menjalankan purge');

select * from finish();
rollback;
