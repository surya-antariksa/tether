-- Sprint 5: hapus akun (F12): penonaktifan segera dan purge tuntas setelah 30 hari.
begin;
create extension if not exists pgtap with schema extensions;
select plan(48);

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
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 6) n;

-- C1: u1 admin (paling lama), u2 (anggota tertua setelah u1), u3. C2: u1 anggota TUNGGAL.
-- C3: u1 member, u4 admin (sudah ada admin lain). u5 asing. u6 untuk skenario purge.
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C1'), ('c2c2c2c2-0000-0000-0000-000000000002', 'C2'),
  ('c3c3c3c3-0000-0000-0000-000000000003', 'C3');
insert into public.circle_members (circle_id, user_id, role, joined_at) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin', now() - interval '10 days'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(3), 'member', now() - interval '5 days'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member', now() - interval '8 days'),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(1), 'admin', now() - interval '10 days'),
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(4), 'admin', now() - interval '10 days'),
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(1), 'member', now() - interval '9 days');
insert into public.places (circle_id, name, center, radius_m, created_by)
values ('c1c1c1c1-0000-0000-0000-000000000001', 'Rumah',
        extensions.ST_SetSRID(extensions.ST_MakePoint(106.8167, -6.2), 4326)::extensions.geography, 150, pg_temp.uid(1));

-- Data milik u1: titik (menghasilkan status geofence dan arrive di C1), perangkat, sesi, token refresh
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(1), 'role', 'authenticated')::text, true);
select public.upload_points(jsonb_build_array(pg_temp.pt(20), pg_temp.pt(19)));
select public.register_device('android', 'tok-u1');
select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe');
select public.trigger_sos(-6.2, 106.8);
insert into auth.sessions (id, user_id) values ('51515151-0000-0000-0000-000000000001', pg_temp.uid(1));
insert into auth.refresh_tokens (token, user_id, session_id, revoked)
values ('tok-refresh-u1', pg_temp.uid(1)::text, '51515151-0000-0000-0000-000000000001', false);
-- data milik u2 (tidak boleh terpengaruh)
insert into auth.sessions (id, user_id) values ('52525252-0000-0000-0000-000000000002', pg_temp.uid(2));
select public.register_device('android', 'tok-u2') from (select set_config('request.jwt.claims',
  json_build_object('sub', pg_temp.uid(2), 'role', 'authenticated')::text, true)) s;

-- Keadaan sebelum
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(1)), 2, 'sebelum: u1 punya 2 titik');
select is((select count(*)::int from public.member_place_state where user_id = pg_temp.uid(1)), 1, 'sebelum: u1 punya status geofence');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(1) and type in ('arrive', 'checkin', 'sos')), 5,
  'sebelum: u1 punya 1 arrive, 1 checkin, 3 sos (satu per Circle)');

-- Tidak bisa mengubah deleted_at lewat klien
select pg_temp.as_user(1);
select throws_ok($$update public.profiles set deleted_at = now()$$, '42501', null::text, 'klien tidak bisa menulis deleted_at langsung');
reset role;
set local role anon;
select throws_ok($$select public.delete_account()$$, '42501', null::text, 'anon tidak bisa delete_account');
reset role;
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok($$select public.delete_account()$$, '28000', 'tidak terautentikasi', 'tanpa JWT: 28000');
reset role;

-- ---------------------------------------------------------------------------
-- delete_account
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select lives_ok($$select public.delete_account()$$, 'delete_account berjalan');
reset role;

select ok((select deleted_at between now() - interval '1 minute' and now() + interval '1 minute'
           from public.profiles where id = pg_temp.uid(1)), 'profiles.deleted_at terisi');
select is((select banned_until from auth.users where id = pg_temp.uid(1)), timestamptz '9999-12-31 00:00:00+00',
  'auth.users.banned_until diblokir (login ditolak GoTrue)');
select is((select count(*)::int from auth.sessions where user_id = pg_temp.uid(1)), 0, 'semua sesi u1 dicabut');
select is((select count(*)::int from auth.refresh_tokens where user_id = pg_temp.uid(1)::text), 0, 'refresh token u1 ikut terhapus');
select is((select count(*)::int from auth.sessions where user_id = pg_temp.uid(2)), 1, 'sesi pengguna lain tidak terpengaruh');
select is((select count(*)::int from public.circle_members where user_id = pg_temp.uid(1)), 0, 'u1 keluar dari semua Circle');
select is((select count(*)::int from public.devices where user_id = pg_temp.uid(1)), 0, 'devices u1 terhapus');
select is((select count(*)::int from public.devices where user_id = pg_temp.uid(2)), 1, 'devices pengguna lain tetap');
select is((select count(*)::int from public.member_status where user_id = pg_temp.uid(1)), 0, 'member_status u1 terhapus');
select is((select count(*)::int from public.member_place_state where user_id = pg_temp.uid(1)), 0, 'member_place_state u1 terhapus');
select is((select count(*)::int from public.location_points where user_id = pg_temp.uid(1)), 0, 'titik lokasi u1 terhapus segera');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(1) and type in ('arrive', 'checkin', 'sos')), 0,
  'event arrive, checkin, sos u1 terhapus segera (tidak tersisa di Circle)');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(1) and type = 'member_left'), 2,
  'event member_left diterbitkan di Circle yang masih berpenghuni (C1, C3); C2 hilang bersama Circle');
select is((select count(*)::int from public.push_outbox where recipient_id = pg_temp.uid(1)), 0, 'tidak ada antrean push untuk u1');

-- Circle: C2 (anggota tunggal) dihapus, C1 promosi admin ke anggota paling lama (u2), C3 tetap admin u4
select is((select count(*)::int from public.circles where id = 'c2c2c2c2-0000-0000-0000-000000000002'), 0,
  'Circle yang hanya berisi u1 dihapus (tidak ada Circle yatim)');
select is((select role from public.circle_members where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001' and user_id = pg_temp.uid(2)),
  'admin', 'C1: anggota paling lama bergabung (u2) dipromosikan jadi admin');
select is((select role from public.circle_members where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001' and user_id = pg_temp.uid(3)),
  'member', 'C1: anggota lain tetap member');
select is((select count(*)::int from public.circle_members where circle_id = 'c3c3c3c3-0000-0000-0000-000000000003' and role = 'admin'), 1,
  'C3: admin lain tetap satu');
select is((select count(*)::int from public.circles c where not exists
           (select 1 from public.circle_members m where m.circle_id = c.id)), 0, 'tidak ada Circle tanpa anggota');
select is((select count(*)::int from public.circles c where not exists
           (select 1 from public.circle_members m where m.circle_id = c.id and m.role = 'admin')), 0, 'setiap Circle punya admin');
select is((select count(*)::int from public.push_outbox where kind = 'member_left' and recipient_id = pg_temp.uid(2)), 1,
  'u2 menerima antrean member_left');

-- Idempoten: panggilan kedua tidak mengubah deleted_at dan tidak galat
update public.profiles set deleted_at = now() - interval '2 days' where id = pg_temp.uid(1);
select pg_temp.as_user(1);
select lives_ok($$select public.delete_account()$$, 'panggilan kedua tidak galat');
reset role;
select ok((select deleted_at < now() - interval '1 day' from public.profiles where id = pg_temp.uid(1)),
  'deleted_at asli dipertahankan pada panggilan kedua');

-- ---------------------------------------------------------------------------
-- purge_deleted_accounts
-- ---------------------------------------------------------------------------
-- u1: deleted_at 2 hari, lalu 29 hari -> belum dihapus; 31 hari -> dihapus.
select is(public.purge_deleted_accounts(), 0, 'akun yang dihapus 2 hari lalu belum dipurge');
select is((select count(*)::int from auth.users where id = pg_temp.uid(1)), 1, 'auth.users u1 masih ada');

-- data turunan yang harus ikut hilang: profil, pengaturan notifikasi, event member_left, join_attempts
insert into public.join_attempts (user_id, succeeded) values (pg_temp.uid(1), false);
update public.profiles set deleted_at = now() - interval '29 days' where id = pg_temp.uid(1);
select is(public.purge_deleted_accounts(), 0, '29 hari: belum dipurge');
update public.profiles set deleted_at = now() - interval '31 days' where id = pg_temp.uid(1);
select is(public.purge_deleted_accounts(), 1, '31 hari: dipurge (mengembalikan 1)');
select is((select count(*)::int from auth.users where id = pg_temp.uid(1)), 0, 'auth.users u1 terhapus tuntas');
select is((select count(*)::int from public.profiles where id = pg_temp.uid(1)), 0, 'profil terhapus (cascade)');
select is((select count(*)::int from public.notification_settings where user_id = pg_temp.uid(1)), 0, 'notification_settings terhapus (cascade)');
select is((select count(*)::int from public.events where user_id = pg_temp.uid(1)), 0, 'event milik u1 terhapus (cascade)');
select is((select count(*)::int from public.join_attempts where user_id = pg_temp.uid(1)), 0, 'join_attempts terhapus (cascade)');
select is((select count(*)::int from public.push_outbox where event_id not in (select id from public.events)), 0,
  'tidak ada baris outbox yatim');
select is((select count(*)::int from auth.users where id in (pg_temp.uid(2), pg_temp.uid(3), pg_temp.uid(4))), 3,
  'pengguna lain tidak ikut terhapus');
select is((select count(*)::int from public.circles where id in
           ('c1c1c1c1-0000-0000-0000-000000000001', 'c3c3c3c3-0000-0000-0000-000000000003')), 2, 'Circle yang masih berpenghuni tetap ada');

-- Pengaman: akun terhapus yang masih tercatat sebagai anggota (tanpa lewat delete_account),
-- Circle yang jadi kosong ikut dihapus.
insert into public.circles (id, name) values ('c9c9c9c9-0000-0000-0000-000000000009', 'Yatim');
insert into public.circle_members (circle_id, user_id, role) values ('c9c9c9c9-0000-0000-0000-000000000009', pg_temp.uid(6), 'admin');
update public.profiles set deleted_at = now() - interval '40 days' where id = pg_temp.uid(6);
select is(public.purge_deleted_accounts(), 1, 'purge akun u6 (masih anggota)');
select is((select count(*)::int from public.circles where id = 'c9c9c9c9-0000-0000-0000-000000000009'), 0,
  'Circle yang menjadi kosong dihapus (tidak ada Circle yatim)');

-- Hak akses purge: hanya postgres/service_role
select pg_temp.as_user(2);
select throws_ok($$select public.purge_deleted_accounts()$$, '42501', null::text, 'authenticated tidak bisa purge_deleted_accounts');
reset role;
set local role anon;
select throws_ok($$select public.purge_deleted_accounts()$$, '42501', null::text, 'anon tidak bisa purge_deleted_accounts');
reset role;
select ok(has_function_privilege('service_role', 'public.purge_deleted_accounts()', 'execute'), 'service_role boleh menjalankan purge_deleted_accounts');
select ok(has_function_privilege('postgres', 'public.purge_deleted_accounts()', 'execute'), 'postgres boleh menjalankan purge_deleted_accounts');

select * from finish();
rollback;
