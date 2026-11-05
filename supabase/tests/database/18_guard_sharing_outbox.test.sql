-- Perbaikan temuan ditunda gelombang 4: penjaga akun terhapus, event set_sharing_enabled,
-- dedup outbox SOS antar Circle.
begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('dddddddd-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.c(n int) returns uuid language sql as
  $$ select ('dddddddd-' || lpad(n::text, 4, '0')
             || '-0000-0000-000000000001')::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

insert into auth.users (id, email, raw_user_meta_data)
select pg_temp.uid(n), 'gd' || n || '@example.test', jsonb_build_object('display_name', 'Nama' || n)
from generate_series(1, 4) n;

insert into public.circles (id, name) values (pg_temp.c(1), 'C1'), (pg_temp.c(2), 'C2');
-- Pengirim SOS (1) dan penerima (2) berada di dua Circle; 3 dan 4 satu Circle saja.
insert into public.circle_members (circle_id, user_id, role)
values (pg_temp.c(1), pg_temp.uid(1), 'admin'),
       (pg_temp.c(1), pg_temp.uid(2), 'member'),
       (pg_temp.c(1), pg_temp.uid(3), 'member'),
       (pg_temp.c(2), pg_temp.uid(1), 'member'),
       (pg_temp.c(2), pg_temp.uid(2), 'member'),
       (pg_temp.c(2), pg_temp.uid(4), 'admin');

-- ---------------------------------------------------------------------------
-- Event set_sharing_enabled (semua pengguna masih aktif di bagian ini)
-- ---------------------------------------------------------------------------
select pg_temp.as_user(2);
select public.set_sharing_enabled(pg_temp.c(1), true); -- nilai sama dengan bawaan
select is((select count(*)::int from public.events where type = 'sharing_changed'), 0,
  'set_sharing_enabled tanpa perubahan: tanpa event');
select lives_ok($$select public.set_sharing_enabled(pg_temp.c(1), false)$$,
  'set_sharing_enabled berubah false');
select is((select payload from public.events where type = 'sharing_changed'
           limit 1), '{"enabled": false}'::jsonb, 'payload sharing_changed {enabled: false}');
reset role;
select is((select count(*)::int from public.push_outbox where kind = 'sharing_changed'), 2,
  'anggota lain menerima outbox sharing_changed');
update public.notification_settings set member_changes = false where user_id = pg_temp.uid(3);
select pg_temp.as_user(2);
select lives_ok($$select public.set_sharing_enabled(pg_temp.c(1), true)$$,
  'set_sharing_enabled kembali true');
reset role;
select is((select count(*)::int from public.events where type = 'sharing_changed'), 2,
  'dua kali perubahan menghasilkan dua event');
-- Event pertama ke dua penerima (1 dan 3), event kedua hanya ke 3 karena preferensinya mati.
select is((select count(*)::int from public.push_outbox where kind = 'sharing_changed'), 3,
  'preferensi member_changes mengendalikan outbox sharing_changed');

-- ---------------------------------------------------------------------------
-- Dedup outbox SOS: penerima yang ada di dua Circle pengirim hanya satu baris
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select is(public.trigger_sos(-6.2, 106.8, null, 'dddddddd-aaaa-0000-0000-000000000001'),
  2, 'SOS pertama menghasilkan dua event (dua Circle)');
reset role;
select is((select count(*)::int from public.events
           where type = 'sos' and payload ->> 'client_id' = 'dddddddd-aaaa-0000-0000-000000000001'),
  2, 'dua event sos tercatat');
select is((select count(*)::int from public.push_outbox o
           join public.events e on e.id = o.event_id
           where e.type = 'sos' and e.user_id = pg_temp.uid(1) and o.recipient_id = pg_temp.uid(2)),
  1, 'penerima di dua Circle hanya mendapat satu baris outbox SOS');
select is((select count(*)::int from public.push_outbox o
           join public.events e on e.id = o.event_id
           where e.type = 'sos' and e.user_id = pg_temp.uid(1)),
  3, 'outbox SOS total = penerima unik, bukan 2 event kali keanggotaan');
select pg_temp.as_user(1);
select is(public.trigger_sos(-6.2, 106.8, null, 'dddddddd-aaaa-0000-0000-000000000001'),
  2, 'pemanggilan ulang client_id sama idempoten');
reset role;
select is((select count(*)::int from public.push_outbox o
           join public.events e on e.id = o.event_id
           where e.type = 'sos' and e.user_id = pg_temp.uid(1)),
  3, 'pemanggilan ulang tidak menambah outbox');

-- ---------------------------------------------------------------------------
-- Pengguna aktif tetap bisa menulis
-- ---------------------------------------------------------------------------
select pg_temp.as_user(3);
select lives_ok($$select public.create_place(pg_temp.c(1), 'Rumah', -6.2, 106.8, 200)$$,
  'anggota aktif tetap bisa menulis');
reset role;

-- ---------------------------------------------------------------------------
-- Penjaga akun terhapus
-- ---------------------------------------------------------------------------
update public.profiles set deleted_at = now() where id = pg_temp.uid(1);
select pg_temp.as_user(1);
select throws_ok($$select public.upload_points(
    '[{"lat":-6.2,"lng":106.8,"recorded_at":"2026-11-05T00:00:00Z"}]'::jsonb)$$,
  '28000', null::text, 'upload_points ditolak untuk akun terhapus');
select throws_ok($$select public.create_circle('Baru')$$, '28000', null::text,
  'create_circle ditolak');
select throws_ok($$select public.join_circle('AB2D33')$$, '28000', null::text,
  'join_circle ditolak');
select throws_ok($$select public.preview_invite('AB2D33')$$, '28000', null::text,
  'preview_invite ditolak');
select throws_ok($$select public.checkin(pg_temp.c(1), 'safe')$$, '28000', null::text,
  'checkin ditolak');
select throws_ok($$select public.trigger_sos(-6.2, 106.8, null, 'dddddddd-aaaa-0000-0000-000000000002')$$,
  '28000', null::text, 'trigger_sos ditolak');
select throws_ok($$select public.pause_sharing(pg_temp.c(1), 15)$$, '28000', null::text,
  'pause_sharing ditolak');
select throws_ok($$select public.resume_sharing(pg_temp.c(1))$$, '28000', null::text,
  'resume_sharing ditolak');
select throws_ok($$select public.set_sharing_enabled(pg_temp.c(1), false)$$, '28000', null::text,
  'set_sharing_enabled ditolak');
select throws_ok($$select public.create_invite(pg_temp.c(1))$$, '28000', null::text,
  'create_invite ditolak');
select throws_ok($$select public.remove_member(pg_temp.c(1), pg_temp.uid(3))$$, '28000', null::text,
  'remove_member ditolak');
select throws_ok($$select public.create_place(pg_temp.c(1), 'Rumah2', -6.2, 106.8, 200)$$,
  '28000', null::text, 'create_place ditolak');
select throws_ok($$select public.update_place(pg_temp.uid(3), 'Nama', 300)$$, '28000', null::text,
  'update_place ditolak');
select throws_ok($$select public.register_device('linux', 'token-a')$$, '28000', null::text,
  'register_device ditolak');
select throws_ok($$select public.unregister_device('token-a')$$, '28000', null::text,
  'unregister_device ditolak');
select throws_ok($$select public.delete_my_location_history()$$, '28000', null::text,
  'delete_my_location_history ditolak');
select lives_ok($$select public.delete_account()$$, 'delete_account tetap bisa dipanggil (idempoten)');
select throws_ok($$select public.leave_circle(pg_temp.c(1))$$, '42501', null::text,
  'leave_circle tanpa penjaga: keanggotaan sudah kosong (dipakai delete_account)');

select * from finish();
rollback;
