-- Sprint 5: notification_settings, devices, push_outbox (penerima, preferensi, tanpa payload).
begin;
create extension if not exists pgtap with schema extensions;
select plan(68);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;
-- penerima outbox untuk event terbaru tipe t milik pengguna n, sebagai larik nomor pengguna terurut
create function pg_temp.rcpt(n int, t text) returns int[] language sql as $$
  select coalesce(array_agg(right(o.recipient_id::text, 2)::int order by o.recipient_id), '{}')
  from public.push_outbox o
  where o.event_id = (select e.id from public.events e where e.user_id = pg_temp.uid(n) and e.type = t
                      order by e.created_at desc, e.id limit 1) $$;

insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 7) n;

-- ---------------------------------------------------------------------------
-- notification_settings
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.notification_settings where user_id in (select pg_temp.uid(n) from generate_series(1, 7) n)), 7, 'baris notification_settings dibuat otomatis per profil');
select is((select count(*)::int from public.notification_settings
           where arrive_leave and checkin and member_changes and user_id in (select pg_temp.uid(n) from generate_series(1, 7) n)), 7, 'semua bawaan true');
select has_column('public', 'notification_settings', 'arrive_leave', 'kolom arrive_leave ada');
select hasnt_column('public', 'notification_settings', 'sos', 'tidak ada sakelar SOS');
-- backfill untuk profil lama: hapus lalu jalankan pernyataan backfill yang sama
delete from public.notification_settings where user_id = pg_temp.uid(7);
insert into public.notification_settings (user_id) select id from public.profiles on conflict (user_id) do nothing;
select is((select count(*)::int from public.notification_settings where user_id = pg_temp.uid(7)), 1, 'backfill membuat baris yang hilang');

select pg_temp.as_user(1);
select is((select count(*)::int from public.notification_settings), 1, 'pengguna hanya melihat baris sendiri');
select is((select user_id from public.notification_settings), pg_temp.uid(1), 'baris itu milik sendiri');
update public.notification_settings set checkin = false;
select is((select checkin from public.notification_settings), false, 'pengguna bisa mengubah pengaturan sendiri');
select is((select count(*)::int from public.notification_settings where user_id <> pg_temp.uid(1)), 0, 'baris orang lain tidak terlihat');
select throws_ok($$update public.notification_settings set user_id = '00000000-0000-0000-0000-000000000002'$$,
  '42501', null::text, 'user_id tidak bisa diubah');
select throws_ok($$insert into public.notification_settings (user_id) values ('00000000-0000-0000-0000-000000000099')$$,
  '42501', null::text, 'INSERT langsung ditolak');
select throws_ok($$delete from public.notification_settings$$, '42501', null::text, 'DELETE langsung ditolak');
reset role;
select is((select count(*)::int from public.notification_settings where user_id <> pg_temp.uid(1) and not checkin), 0,
  'update pengguna 1 tidak menyentuh baris orang lain');
select pg_temp.as_user(2);
update public.notification_settings set arrive_leave = false where user_id = pg_temp.uid(1);
reset role;
select is((select arrive_leave from public.notification_settings where user_id = pg_temp.uid(1)), true,
  'update baris orang lain tidak berefek (RLS)');
set local role anon;
select throws_ok($$select * from public.notification_settings$$, '42501', null::text, 'anon tidak bisa SELECT notification_settings');
reset role;
update public.notification_settings set checkin = true where user_id = pg_temp.uid(1);

-- ---------------------------------------------------------------------------
-- devices
-- ---------------------------------------------------------------------------
select pg_temp.as_user(1);
select is((select public.register_device('android', 'tok-A')) is not null, true, 'register_device mengembalikan id');
reset role;
select is((select count(*)::int from public.devices where user_id = pg_temp.uid(1)), 1, 'perangkat tercatat');
update public.devices set last_active_at = now() - interval '1 day' where push_token = 'tok-A';
select set_config('t.dev', (select id::text from public.devices where push_token = 'tok-A'), true);
select pg_temp.as_user(1);
select is((select public.register_device('ios', 'tok-A')), current_setting('t.dev')::uuid,
  'upsert: token sama mengembalikan id yang sama');
reset role;
select is((select count(*)::int from public.devices where push_token = 'tok-A'), 1, 'upsert tidak menggandakan baris');
select is((select platform from public.devices where push_token = 'tok-A'), 'ios', 'platform diperbarui');
select ok((select last_active_at > now() - interval '1 minute' from public.devices where push_token = 'tok-A'),
  'last_active_at diperbarui');

select pg_temp.as_user(1);
select throws_ok($$select public.register_device('windows', 'tok-B')$$, '22023', 'platform tidak valid', 'platform tidak dikenal ditolak');
select throws_ok($$select public.register_device(null, 'tok-B')$$, '22023', 'platform tidak valid', 'platform null ditolak');
select throws_ok($$select public.register_device('web', '')$$, '22023', 'token tidak valid', 'token kosong ditolak');
select throws_ok($$select public.register_device('web', null)$$, '22023', 'token tidak valid', 'token null ditolak');
select throws_ok($$select public.register_device('web', repeat('x', 4097))$$, '22023', 'token tidak valid', 'token terlalu panjang ditolak');

-- klien tidak bisa SELECT/menulis devices sama sekali
select throws_ok($$select * from public.devices$$, '42501', null::text, 'klien tidak bisa SELECT devices (bahkan milik sendiri)');
select throws_ok($$select push_token from public.devices$$, '42501', null::text, 'klien tidak bisa SELECT kolom push_token');
select throws_ok($$insert into public.devices (user_id, platform, push_token) values (auth.uid(), 'web', 'x')$$,
  '42501', null::text, 'INSERT langsung ditolak');
select throws_ok($$update public.devices set push_token = 'x'$$, '42501', null::text, 'UPDATE langsung ditolak');
select throws_ok($$delete from public.devices$$, '42501', null::text, 'DELETE langsung ditolak');

-- token orang lain: u2 mendaftar token yang sama (perangkat berganti akun) -> milik u1 dihapus
select pg_temp.as_user(2);
select lives_ok($$select public.register_device('android', 'tok-A')$$, 'u2 mendaftarkan token yang sama');
reset role;
select is((select user_id from public.devices where push_token = 'tok-A'), pg_temp.uid(2),
  'token berpindah ke u2 (akun lama tidak lagi menerima push di perangkat itu)');
select is((select count(*)::int from public.devices where push_token = 'tok-A'), 1, 'token hanya milik satu pengguna');

-- unregister_device hanya milik sendiri, tanpa galat bila tidak ada
select pg_temp.as_user(1);
select lives_ok($$select public.unregister_device('tok-A')$$, 'unregister token milik orang lain: tanpa galat');
select lives_ok($$select public.unregister_device('tidak-ada')$$, 'unregister token tidak dikenal: tanpa galat');
reset role;
select is((select count(*)::int from public.devices where push_token = 'tok-A'), 1, 'token u2 tidak terhapus oleh u1');
select pg_temp.as_user(2);
select lives_ok($$select public.unregister_device('tok-A')$$, 'u2 melepas perangkatnya');
reset role;
select is((select count(*)::int from public.devices where user_id in (select pg_temp.uid(n) from generate_series(1, 7) n)), 0, 'perangkat terhapus');

-- batas 10 perangkat per pengguna: yang paling lama tidak aktif dibuang
select pg_temp.as_user(3);
select public.register_device('android', 'old-' || i) from generate_series(1, 10) i;
reset role;
update public.devices set last_active_at = now() - interval '1 day' where push_token = 'old-1';
select pg_temp.as_user(3);
select public.register_device('android', 'baru');
reset role;
select is((select count(*)::int from public.devices where user_id = pg_temp.uid(3)), 10, 'maksimal 10 perangkat per pengguna');
select is((select count(*)::int from public.devices where push_token = 'old-1'), 0, 'perangkat paling lama tidak aktif dibuang');
select is((select count(*)::int from public.devices where push_token = 'baru'), 1, 'perangkat baru tersimpan');
delete from public.devices;

set local role anon;
select throws_ok($$select public.register_device('web', 'x')$$, '42501', null::text, 'anon tidak bisa register_device');
select throws_ok($$select public.unregister_device('x')$$, '42501', null::text, 'anon tidak bisa unregister_device');
reset role;

-- ---------------------------------------------------------------------------
-- push_outbox: tanpa akses klien
-- ---------------------------------------------------------------------------
-- C1: u1 admin, u2, u3, u4. C2: u4 admin, u5. u6 asing. u7 anggota C1 dan C2? (tidak)
insert into public.circles (id, name) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C1'), ('c2c2c2c2-0000-0000-0000-000000000002', 'C2');
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(2), 'member'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(3), 'member'),
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(4), 'member'),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(4), 'admin'),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(5), 'member');
-- anggota ditambahkan langsung (tanpa RPC): tidak ada event, jadi outbox masih kosong
select is((select count(*)::int from public.push_outbox), 0, 'outbox kosong sebelum ada event');

select pg_temp.as_user(1);
select throws_ok($$select * from public.push_outbox$$, '42501', null::text, 'klien tidak bisa SELECT push_outbox');
select throws_ok($$insert into public.push_outbox (event_id, recipient_id, kind) values (gen_random_uuid(), auth.uid(), 'sos')$$,
  '42501', null::text, 'klien tidak bisa INSERT push_outbox');
select throws_ok($$update public.push_outbox set sent_at = now()$$, '42501', null::text, 'klien tidak bisa UPDATE push_outbox');
select throws_ok($$delete from public.push_outbox$$, '42501', null::text, 'klien tidak bisa DELETE push_outbox');
reset role;
set local role anon;
select throws_ok($$select * from public.push_outbox$$, '42501', null::text, 'anon tidak bisa SELECT push_outbox');
reset role;

-- tanpa isi payload di outbox
select is((select array_agg(column_name::text order by ordinal_position) from information_schema.columns
           where table_schema = 'public' and table_name = 'push_outbox'),
  array['id', 'event_id', 'recipient_id', 'kind', 'created_at', 'sent_at', 'attempts'],
  'kolom push_outbox: tanpa payload atau koordinat');

-- check-in oleh u1 -> penerima u2, u3, u4 (bukan u1, bukan anggota C2, bukan asing)
select pg_temp.as_user(1);
select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'arrived');
reset role;
select is(pg_temp.rcpt(1, 'checkin'), array[2, 3, 4], 'checkin: penerima = anggota C1 selain pelaku');
select is((select count(distinct kind)::int from public.push_outbox), 1, 'satu jenis kind');
select is((select kind from public.push_outbox limit 1), 'checkin', 'kind = tipe event');

-- preferensi: u3 mematikan checkin, u4 mematikan arrive_leave dan member_changes
update public.notification_settings set checkin = false where user_id = pg_temp.uid(3);
update public.notification_settings set arrive_leave = false, member_changes = false where user_id = pg_temp.uid(4);
update public.events set created_at = now() - interval '5 minutes' where type = 'checkin';
select pg_temp.as_user(1);
select public.checkin('c1c1c1c1-0000-0000-0000-000000000001', 'safe');
reset role;
select is((select array_agg(right(o.recipient_id::text, 2)::int order by o.recipient_id) from public.push_outbox o
           join public.events e on e.id = o.event_id where e.payload ->> 'kind' = 'safe'),
  array[2, 4], 'checkin: u3 (checkin=false) tidak menerima, u4 (checkin=true) tetap menerima');

-- arrive/leave mengikuti arrive_leave
insert into public.events (user_id, circle_id, type, payload) values
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'arrive', '{"place_name":"Rumah"}'),
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'leave', '{"place_name":"Rumah"}');
select is((select array_agg(distinct right(o.recipient_id::text, 2)::int order by right(o.recipient_id::text, 2)::int)
           from public.push_outbox o where o.kind in ('arrive', 'leave')),
  array[2, 3], 'arrive/leave: u4 (arrive_leave=false) tidak menerima');
select is((select count(*)::int from public.push_outbox where kind in ('arrive', 'leave')), 4, '2 event x 2 penerima');

-- member_changes: paused/resumed/member_*
insert into public.events (user_id, circle_id, type, payload) values
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'paused', '{}'),
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'resumed', '{}'),
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'member_joined', '{}'),
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'member_left', '{}'),
  (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'member_removed', '{}');
select is((select count(*)::int from public.push_outbox where kind in ('paused', 'resumed', 'member_joined', 'member_left', 'member_removed')),
  10, 'member_changes: 5 event x 2 penerima (u4 mati)');
select is((select count(*)::int from public.push_outbox where kind in ('paused', 'resumed', 'member_joined', 'member_left', 'member_removed')
           and recipient_id = pg_temp.uid(4)), 0, 'u4 (member_changes=false) tidak menerima');
update public.notification_settings set member_changes = false where user_id = pg_temp.uid(3);
insert into public.events (user_id, circle_id, type, payload, created_at)
values (pg_temp.uid(1), 'c1c1c1c1-0000-0000-0000-000000000001', 'paused', '{}', now() + interval '1 minute');
select is(pg_temp.rcpt(1, 'paused') @> array[3], false, 'u3 mematikan member_changes: tidak menerima paused lagi');

-- SOS SELALU: semua sakelar mati tetap menerima
update public.notification_settings set arrive_leave = false, checkin = false, member_changes = false;
select pg_temp.as_user(1);
select public.trigger_sos(-6.2, 106.8, 10);
reset role;
select is((select array_agg(right(o.recipient_id::text, 2)::int order by o.recipient_id) from public.push_outbox o
           join public.events e on e.id = o.event_id where e.type = 'sos' and e.circle_id = 'c1c1c1c1-0000-0000-0000-000000000001'),
  array[2, 3, 4], 'SOS tidak bisa dimatikan: semua anggota selain pelaku tetap menerima');
select is((select count(*)::int from public.push_outbox o join public.events e on e.id = o.event_id
           where e.type = 'sos' and o.recipient_id = pg_temp.uid(1)), 0, 'pelaku SOS tidak menerima');
select is((select count(*)::int from public.push_outbox o join public.events e on e.id = o.event_id
           where e.type = 'sos' and e.circle_id = 'c2c2c2c2-0000-0000-0000-000000000002'), 0,
  'SOS u1 tidak membuat outbox di Circle yang bukan miliknya (C2)');
select is((select count(*)::int from public.push_outbox where recipient_id in (pg_temp.uid(6), pg_temp.uid(5))), 0,
  'orang asing dan anggota Circle lain tidak menerima apa pun');

-- Nilai bawaan dan hubungan
select is((select count(*)::int from public.push_outbox where sent_at is not null or attempts <> 0), 0,
  'baris baru: sent_at null dan attempts 0');

-- Event tanpa circle_id (mis. sisa spike) tidak membuat outbox
insert into public.events (user_id, type) values (pg_temp.uid(1), 'sos');
select is((select count(*)::int from public.push_outbox o join public.events e on e.id = o.event_id
           where e.circle_id is null), 0, 'event tanpa circle_id tidak membuat outbox');

-- Cascade: menghapus event menghapus baris outbox-nya
delete from public.events where type = 'sos';
select is((select count(*)::int from public.push_outbox where kind = 'sos'), 0, 'outbox ikut terhapus bersama event (cascade)');

-- Indeks baris belum terkirim bersifat parsial
select ok((select indpred is not null from pg_index where indexrelid = 'public.push_outbox_pending_idx'::regclass),
  'indeks push_outbox belum terkirim bersifat parsial');

select * from finish();
rollback;
