-- Sprint 1 sampai 3: hak akses klien (tulis langsung ditolak, invites tertutup, EXECUTE fungsi).
begin;
create extension if not exists pgtap with schema extensions;
select plan(29);

create function pg_temp.uid(n int) returns uuid language sql as
  $$ select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.uid(n), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

insert into auth.users (id, email)
select pg_temp.uid(n), 'u' || n || '@example.test' from generate_series(1, 3) n;
-- C1: u1 admin. C2: u2 admin. u3 tanpa Circle.
insert into public.circles (id, name, created_by) values
  ('c1c1c1c1-0000-0000-0000-000000000001', 'C1', pg_temp.uid(1)),
  ('c2c2c2c2-0000-0000-0000-000000000002', 'C2', pg_temp.uid(2));
insert into public.circle_members (circle_id, user_id, role) values
  ('c1c1c1c1-0000-0000-0000-000000000001', pg_temp.uid(1), 'admin'),
  ('c2c2c2c2-0000-0000-0000-000000000002', pg_temp.uid(2), 'admin');
insert into public.invites (circle_id, code_hash, expires_at)
values ('c1c1c1c1-0000-0000-0000-000000000001', public.hash_invite_code('ABCDEF'), now() + interval '1 day');
insert into public.join_attempts (user_id, succeeded) values (pg_temp.uid(1), false);

-- RLS aktif di semua tabel public
select is((select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity), 0,
  'RLS aktif di semua tabel schema public');

-- RPC publik: anon tidak boleh, authenticated boleh
select is((select count(*)::int from unnest(array[
  'public.create_circle(text)', 'public.create_invite(uuid)', 'public.preview_invite(text)',
  'public.join_circle(text)', 'public.leave_circle(uuid)', 'public.remove_member(uuid,uuid)',
  'public.pause_sharing(uuid,int)', 'public.resume_sharing(uuid)', 'public.set_sharing_enabled(uuid,boolean)',
  'public.upload_points(jsonb)', 'public.is_circle_member(uuid)', 'public.is_circle_admin(uuid)',
  'public.shares_circle(uuid)', 'public.shares_active_circle(uuid)',
  'public.create_place(uuid,text,double precision,double precision,int)', 'public.update_place(uuid,text,int)',
  'public.delete_place(uuid)', 'public.checkin(uuid,text)', 'public.trigger_sos(double precision,double precision,real,uuid,timestamp with time zone)',
  'public.register_device(text,text)', 'public.unregister_device(text)', 'public.delete_account()',
  'public.delete_my_location_history()']::regprocedure[]) f
  where has_function_privilege('anon', f, 'execute') or has_function_privilege('public', f, 'execute')), 0,
  'anon dan PUBLIC tidak punya EXECUTE pada RPC dan fungsi bantu');
select is((select count(*)::int from unnest(array[
  'public.create_circle(text)', 'public.create_invite(uuid)', 'public.preview_invite(text)',
  'public.join_circle(text)', 'public.leave_circle(uuid)', 'public.remove_member(uuid,uuid)',
  'public.pause_sharing(uuid,int)', 'public.resume_sharing(uuid)', 'public.set_sharing_enabled(uuid,boolean)',
  'public.upload_points(jsonb)', 'public.is_circle_member(uuid)', 'public.is_circle_admin(uuid)',
  'public.shares_circle(uuid)', 'public.shares_active_circle(uuid)',
  'public.create_place(uuid,text,double precision,double precision,int)', 'public.update_place(uuid,text,int)',
  'public.delete_place(uuid)', 'public.checkin(uuid,text)', 'public.trigger_sos(double precision,double precision,real,uuid,timestamp with time zone)',
  'public.register_device(text,text)', 'public.unregister_device(text)', 'public.delete_account()',
  'public.delete_my_location_history()']::regprocedure[]) f
  where has_function_privilege('authenticated', f, 'execute')), 23,
  'authenticated punya EXECUTE pada semua RPC dan fungsi bantu');
select is((select count(*)::int from unnest(array[
  'public.handle_new_user()', 'public.hash_invite_code(text)', 'public.generate_invite_code()',
  'public.check_join_rate(uuid)', 'public.purge_old_location_points()',
  'public.location_points_after_insert()', 'public.purge_old_events()', 'public.purge_deleted_accounts()',
  'public.handle_new_profile()', 'public.events_after_insert()', 'public.circle_members_after_delete()']::regprocedure[]) f
  where has_function_privilege('anon', f, 'execute') or has_function_privilege('authenticated', f, 'execute')
     or has_function_privilege('public', f, 'execute')), 0,
  'fungsi internal tidak bisa dipanggil klien');
-- semua fungsi SECURITY DEFINER di public mengunci search_path
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prosecdef
             and not coalesce('search_path=""' = any (p.proconfig), false)), 0,
  'semua fungsi SECURITY DEFINER memakai search_path kosong');

-- Klien: SELECT circles dan circle_members hanya milik Circle sendiri
select pg_temp.as_user(1);
select is((select count(*)::int from public.circles), 1, 'u1 hanya melihat Circle miliknya');
select is((select count(*)::int from public.circle_members), 1, 'u1 hanya melihat anggota Circle miliknya');
select pg_temp.as_user(3);
select is((select count(*)::int from public.circles) + (select count(*)::int from public.circle_members), 0,
  'pengguna tanpa Circle tidak melihat apa pun');

-- invites dan join_attempts tidak bisa dibaca
select pg_temp.as_user(1);
select throws_ok($$select * from public.invites$$, '42501', null::text, 'klien tidak bisa SELECT invites');
select throws_ok($$select code_hash from public.invites$$, '42501', null::text, 'klien tidak bisa SELECT kolom invites');
select throws_ok($$select * from public.join_attempts$$, '42501', null::text, 'klien tidak bisa SELECT join_attempts');

-- tidak ada tulis langsung
select throws_ok($$insert into public.circles (name) values ('Palsu')$$, '42501', null::text, 'INSERT circles ditolak');
select throws_ok($$insert into public.circle_members (circle_id, user_id, role)
  values ('c2c2c2c2-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'member')$$,
  '42501', null::text, 'INSERT circle_members ditolak (tidak bisa masuk Circle lain)');
select throws_ok($$insert into public.invites (circle_id, code_hash, expires_at)
  values ('c1c1c1c1-0000-0000-0000-000000000001', 'x', now())$$, '42501', null::text, 'INSERT invites ditolak');
select throws_ok($$insert into public.join_attempts (user_id, succeeded)
  values ('00000000-0000-0000-0000-000000000001', true)$$, '42501', null::text, 'INSERT join_attempts ditolak');
select throws_ok($$update public.circles set name = 'x'$$, '42501', null::text, 'UPDATE circles ditolak');
select throws_ok($$update public.circle_members set role = 'admin'$$, '42501', null::text,
  'UPDATE circle_members ditolak (tidak bisa menjadikan diri admin)');
select throws_ok($$update public.invites set max_uses = 1000$$, '42501', null::text, 'UPDATE invites ditolak');
select throws_ok($$update public.join_attempts set succeeded = false$$, '42501', null::text, 'UPDATE join_attempts ditolak');
select throws_ok($$delete from public.circles$$, '42501', null::text, 'DELETE circles ditolak');
select throws_ok($$delete from public.circle_members$$, '42501', null::text, 'DELETE circle_members ditolak');
select throws_ok($$delete from public.invites$$, '42501', null::text, 'DELETE invites ditolak');
select throws_ok($$delete from public.join_attempts$$, '42501', null::text,
  'DELETE join_attempts ditolak (tidak bisa mereset pembatasan)');

-- anon tidak punya akses
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select * from public.circles$$, '42501', null::text, 'anon tidak bisa SELECT circles');
select throws_ok($$select * from public.circle_members$$, '42501', null::text, 'anon tidak bisa SELECT circle_members');
select throws_ok($$select * from public.invites$$, '42501', null::text, 'anon tidak bisa SELECT invites');
select throws_ok($$select public.create_circle('x')$$, '42501', null::text, 'anon tidak bisa create_circle');
select throws_ok($$select public.join_circle('ABCDEF')$$, '42501', null::text, 'anon tidak bisa join_circle');
select throws_ok($$select public.is_circle_member('c1c1c1c1-0000-0000-0000-000000000001')$$, '42501', null::text,
  'anon tidak bisa memanggil fungsi bantu');

select * from finish();
rollback;
