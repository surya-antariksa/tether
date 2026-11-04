-- Sprint 2/3: leave_circle, remove_member, pause_sharing, resume_sharing, set_sharing_enabled.
begin;
create extension if not exists pgtap with schema extensions;
select plan(47);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
create function pg_temp.role_of(circle uuid, n int) returns text language sql as
  $$ select role from public.circle_members where circle_id = circle and user_id = pg_temp.uid(n) $$;
create function pg_temp.n_events(circle uuid, t text) returns int language sql as
  $$ select count(*)::int from public.events where circle_id = circle and type = t $$;

insert into auth.users (id, email, raw_user_meta_data)
select pg_temp.uid(n), 'u' || n || '@example.test', jsonb_build_object('display_name', 'User' || n)
from generate_series(1, 9) n;

-- C1: u1 admin (3 hari), u2 (2 hari), u3 (1 hari), u4 (12 jam)
insert into public.circles (id, name) values ('c1c1c1c1-0000-0000-0000-000000000001', 'C1');
insert into public.circle_members (circle_id, user_id, role, joined_at) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin', now() - interval '3 days'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member', now() - interval '2 days'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(3), 'member', now() - interval '1 day'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(4), 'member', now() - interval '12 hours');
insert into public.invites (circle_id, code_hash, expires_at)
values ('c1c1c1c1-0000-0000-0000-000000000001', public.hash_invite_code('ABCDEF'), now() + interval '1 day');
-- C3: dua admin (u5, u6) dan satu anggota (u7)
insert into public.circles (id, name) values ('c3c3c3c3-0000-0000-0000-000000000003', 'C3');
insert into public.circle_members (circle_id, user_id, role, joined_at) values
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(5), 'admin', now() - interval '3 days'),
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(6), 'admin', now() - interval '2 days'),
  ('c3c3c3c3-0000-0000-0000-000000000003', pg_temp.uid(7), 'member', now() - interval '1 day');

-- ---------------------------------------------------------------------------
-- leave_circle
-- ---------------------------------------------------------------------------
select pg_temp.as_user(9);
select throws_ok($$select public.leave_circle('c1c1c1c1-0000-0000-0000-000000000001')$$, '42501', 'bukan anggota circle',
  'non-anggota tidak bisa keluar');
select throws_ok($$select public.leave_circle('00000000-0000-0000-0000-00000000dead')$$, '42501', 'bukan anggota circle',
  'Circle tidak ada: galat sama');
select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.leave_circle('c1c1c1c1-0000-0000-0000-000000000001')$$, '28000', null::text,
  'leave tanpa login ditolak');

select pg_temp.as_user(3);
select lives_ok($$select public.leave_circle('c1c1c1c1-0000-0000-0000-000000000001')$$, 'anggota biasa keluar');
select is((select count(*)::int from public.circles), 0, 'yang keluar tidak lagi melihat Circle');
reset role;
select is((select count(*)::int from public.circle_members where user_id = pg_temp.uid(3)), 0, 'baris keanggotaan terhapus');
select is(pg_temp.role_of('c1c1c1c1-0000-0000-0000-000000000001', 1), 'admin', 'admin tetap admin');
select is((select payload from public.events where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'
           and type = 'member_left' and user_id = pg_temp.uid(3)), '{"display_name": "User3"}'::jsonb,
  'event member_left tercatat (payload hanya display_name)');

-- admin terakhir keluar: anggota paling lama bergabung (u2, bukan u4) dipromosikan
select pg_temp.as_user(1);
select lives_ok($$select public.leave_circle('c1c1c1c1-0000-0000-0000-000000000001')$$, 'admin terakhir keluar');
reset role;
select is(pg_temp.role_of('c1c1c1c1-0000-0000-0000-000000000001', 2), 'admin', 'anggota paling lama (u2) jadi admin');
select is(pg_temp.role_of('c1c1c1c1-0000-0000-0000-000000000001', 4), 'member', 'anggota lain tetap member');
select is(pg_temp.n_events('c1c1c1c1-0000-0000-0000-000000000001', 'member_left'), 2, 'dua event member_left');

-- ada admin lain: tidak ada promosi
select pg_temp.as_user(5);
select lives_ok($$select public.leave_circle('c3c3c3c3-0000-0000-0000-000000000003')$$, 'admin keluar saat ada admin lain');
reset role;
select is(pg_temp.role_of('c3c3c3c3-0000-0000-0000-000000000003', 7), 'member', 'tanpa promosi bila masih ada admin');

-- ---------------------------------------------------------------------------
-- remove_member (C1 sekarang: u2 admin, u4 member)
-- ---------------------------------------------------------------------------
select pg_temp.as_user(4);
select throws_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002')$$,
  '42501', 'hanya admin', 'anggota biasa tidak bisa mengeluarkan');
select throws_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004')$$,
  '42501', 'hanya admin', 'non-admin tidak bisa mengeluarkan diri sendiri lewat remove_member');
select pg_temp.as_user(9);
select throws_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004')$$,
  '42501', 'hanya admin', 'orang luar tidak bisa mengeluarkan');
select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004')$$,
  '28000', null::text, 'remove tanpa login ditolak');

select pg_temp.as_user(2);
select throws_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002')$$,
  '22023', null::text, 'admin tidak boleh mengeluarkan dirinya sendiri');
select throws_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000009')$$,
  'P0002', null::text, 'target bukan anggota: P0002');
select lives_ok($$select public.remove_member('c1c1c1c1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004')$$,
  'admin mengeluarkan anggota');
reset role;
select is((select count(*)::int from public.circle_members where user_id = pg_temp.uid(4)), 0, 'anggota terhapus');
select is((select payload from public.events where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'
           and type = 'member_removed' and user_id = pg_temp.uid(4)), '{"display_name": "User4"}'::jsonb,
  'event member_removed tercatat');

-- anggota terakhir keluar: Circle dihapus beserta turunannya
select pg_temp.as_user(2);
select lives_ok($$select public.leave_circle('c1c1c1c1-0000-0000-0000-000000000001')$$, 'anggota terakhir keluar');
reset role;
select is((select count(*)::int from public.circles where id = 'c1c1c1c1-0000-0000-0000-000000000001'), 0, 'Circle terhapus');
select is((select count(*)::int from public.invites where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'), 0,
  'undangan ikut terhapus (cascade)');
select is((select count(*)::int from public.events where circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'), 0,
  'event Circle ikut terhapus (cascade)');

-- ---------------------------------------------------------------------------
-- pause_sharing, resume_sharing, set_sharing_enabled (C4: u1 admin, u2 member; C5: u2 dan u3)
-- ---------------------------------------------------------------------------
insert into public.circles (id, name) values
  ('c4c4c4c4-0000-0000-0000-000000000004', 'C4'), ('c5c5c5c5-0000-0000-0000-000000000005', 'C5');
insert into public.circle_members (circle_id, user_id, role) values
  ('c4c4c4c4-0000-0000-0000-000000000004', pg_temp.uid(1), 'admin'),
  ('c4c4c4c4-0000-0000-0000-000000000004', pg_temp.uid(2), 'member'),
  ('c5c5c5c5-0000-0000-0000-000000000005', pg_temp.uid(2), 'admin'),
  ('c5c5c5c5-0000-0000-0000-000000000005', pg_temp.uid(3), 'member');

select pg_temp.as_user(2);
select public.pause_sharing('c4c4c4c4-0000-0000-0000-000000000004', 30);
reset role;
select is((select paused_until from public.circle_members
           where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004' and user_id = pg_temp.uid(2)),
  now() + interval '30 minutes', 'jeda 30 menit: paused_until = now() + 30 menit');
select is((select payload from public.events where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004' and type = 'paused'),
  '{"minutes": 30}'::jsonb, 'event paused: payload hanya minutes');
select is((select paused_until from public.circle_members
           where circle_id = 'c5c5c5c5-0000-0000-0000-000000000005' and user_id = pg_temp.uid(2)),
  null, 'jeda per Circle: keanggotaan lain tidak terpengaruh');

select pg_temp.as_user(2);
select public.pause_sharing('c4c4c4c4-0000-0000-0000-000000000004');
reset role;
select is((select paused_until from public.circle_members
           where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004' and user_id = pg_temp.uid(2)),
  'infinity'::timestamptz, 'tanpa menit: paused_until = infinity');
select is((select count(*)::int from public.events where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004'
           and type = 'paused' and payload = '{"minutes": null}'::jsonb), 1,
  'event paused tanpa batas: minutes null');
select is(pg_temp.n_events('c4c4c4c4-0000-0000-0000-000000000004', 'paused'), 2, 'dua event paused');

select pg_temp.as_user(2);
select throws_ok($$select public.pause_sharing('c4c4c4c4-0000-0000-0000-000000000004', 0)$$, '22023', null::text,
  'p_minutes 0 ditolak');
select throws_ok($$select public.pause_sharing('c4c4c4c4-0000-0000-0000-000000000004', -5)$$, '22023', null::text,
  'p_minutes negatif ditolak');
select pg_temp.as_user(9);
select throws_ok($$select public.pause_sharing('c4c4c4c4-0000-0000-0000-000000000004', 15)$$, '42501', 'bukan anggota circle',
  'non-anggota tidak bisa menjeda');
select throws_ok($$select public.resume_sharing('c4c4c4c4-0000-0000-0000-000000000004')$$, '42501', 'bukan anggota circle',
  'non-anggota tidak bisa resume');
select throws_ok($$select public.set_sharing_enabled('c4c4c4c4-0000-0000-0000-000000000004', false)$$, '42501',
  'bukan anggota circle', 'non-anggota tidak bisa set_sharing_enabled');
select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.pause_sharing('c4c4c4c4-0000-0000-0000-000000000004')$$, '28000', null::text,
  'pause tanpa login ditolak');

-- anggota lain di Circle yang sama melihat status jeda (u1) dan event-nya
select pg_temp.as_user(1);
select is((select paused_until from public.circle_members
           where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004' and user_id = pg_temp.uid(2)),
  'infinity'::timestamptz, 'anggota lain melihat paused_until = infinity');
select is((select count(*)::int from public.events where type = 'paused'), 2, 'anggota lain melihat event paused');

select pg_temp.as_user(2);
select public.resume_sharing('c4c4c4c4-0000-0000-0000-000000000004');
select public.resume_sharing('c4c4c4c4-0000-0000-0000-000000000004');
reset role;
select is((select paused_until from public.circle_members
           where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004' and user_id = pg_temp.uid(2)),
  null, 'resume: paused_until null');
select is(pg_temp.n_events('c4c4c4c4-0000-0000-0000-000000000004', 'resumed'), 1,
  'event resumed tercatat sekali (resume kedua tanpa jeda tidak mencatat lagi)');
select is((select payload from public.events where type = 'resumed'), '{}'::jsonb, 'payload resumed kosong');

select pg_temp.as_user(2);
select public.set_sharing_enabled('c4c4c4c4-0000-0000-0000-000000000004', false);
reset role;
select is((select sharing_enabled from public.circle_members
           where circle_id = 'c4c4c4c4-0000-0000-0000-000000000004' and user_id = pg_temp.uid(2)),
  false, 'set_sharing_enabled(false)');
select pg_temp.as_user(2);
select throws_ok($$select public.set_sharing_enabled('c4c4c4c4-0000-0000-0000-000000000004', null)$$, '22023', null::text,
  'set_sharing_enabled null ditolak');
select throws_ok($$update public.circle_members set paused_until = null$$, '42501', null::text,
  'klien tidak bisa UPDATE circle_members langsung');

select * from finish();
rollback;
