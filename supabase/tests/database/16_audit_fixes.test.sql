-- Perbaikan hasil tinjauan: SOS idempoten (client_id, triggered_at) dan batas baca koordinat SOS 48 jam.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

insert into auth.users (id, email, raw_user_meta_data)
select pg_temp.uid(n), 'u' || n || '@example.test', jsonb_build_object('display_name', 'Nama' || n)
from generate_series(1, 3) n;
insert into public.circles (id, name) values ('c1c1c1c1-0000-0000-0000-000000000001', 'C1');
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member');

-- Idempotensi: client_id sama tidak menambah event dan tidak memakai jatah laju.
select pg_temp.as_user(1);
select is(public.trigger_sos(-6.2, 106.8, 10, 'aaaaaaaa-0000-0000-0000-000000000001', now() - interval '20 minutes'),
  1, 'SOS pertama dengan client_id membuat 1 event');
select is(public.trigger_sos(-6.2, 106.8, 10, 'aaaaaaaa-0000-0000-0000-000000000001', now() - interval '20 minutes'),
  1, 'pengulangan dengan client_id sama mengembalikan hasil lama');
select is(public.trigger_sos(-6.2, 106.8, 10, 'aaaaaaaa-0000-0000-0000-000000000001'),
  1, 'pengulangan ketiga juga tidak galat');
reset role;
select is((select count(*)::int from public.events where type = 'sos' and user_id = pg_temp.uid(1)), 1,
  'tetap tepat 1 event sos');
select is((select (payload ->> 'triggered_at')::timestamptz < now() - interval '19 minutes'
           from public.events where type = 'sos' and user_id = pg_temp.uid(1)), true,
  'triggered_at memakai waktu pemicu dari klien');
select is((select payload ->> 'client_id' from public.events where type = 'sos' and user_id = pg_temp.uid(1)),
  'aaaaaaaa-0000-0000-0000-000000000001', 'client_id tercatat di payload');

-- Waktu pemicu di masa depan dijepit ke sekarang; terlalu lama dijepit ke 1 hari.
select pg_temp.as_user(1);
select public.trigger_sos(-6.2, 106.8, null, 'aaaaaaaa-0000-0000-0000-000000000002', now() + interval '1 day');
select public.trigger_sos(-6.2, 106.8, null, 'aaaaaaaa-0000-0000-0000-000000000003', now() - interval '30 days');
reset role;
select is((select (payload ->> 'triggered_at')::timestamptz <= clock_timestamp()
           from public.events where payload ->> 'client_id' = 'aaaaaaaa-0000-0000-0000-000000000002'), true,
  'triggered_at masa depan dijepit');
select is((select (payload ->> 'triggered_at')::timestamptz > now() - interval '25 hours'
           from public.events where payload ->> 'client_id' = 'aaaaaaaa-0000-0000-0000-000000000003'), true,
  'triggered_at terlalu lama dijepit 1 hari');

-- Batas baca 48 jam: anggota melihat SOS baru, tidak melihat yang lama, pelaku tetap melihat.
update public.events set created_at = now() - interval '49 hours'
where payload ->> 'client_id' = 'aaaaaaaa-0000-0000-0000-000000000001';
select pg_temp.as_user(2);
select is((select count(*)::int from public.events where type = 'sos'), 2,
  'anggota hanya membaca SOS dalam 48 jam');
select pg_temp.as_user(1);
select is((select count(*)::int from public.events where type = 'sos'), 3, 'pelaku tetap membaca semua SOS miliknya');
reset role;

-- purge membuang koordinat SOS > 48 jam tetapi mempertahankan event.
select public.purge_old_events();
select is((select payload ? 'lat' from public.events where payload ->> 'client_id' = 'aaaaaaaa-0000-0000-0000-000000000001'),
  false, 'koordinat SOS lama dibuang oleh purge');

select * from finish();
rollback;
