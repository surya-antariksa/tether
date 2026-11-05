-- Sprint 5: retensi (fungsi purge_old_events), indeks jalur panas, dan penjadwalan pg_cron.

-- ---------------------------------------------------------------------------
-- purge_old_events: events lebih dari 90 hari (docs/05 bagian 7). Cascade ke push_outbox.
-- Hanya postgres/service_role.
-- ---------------------------------------------------------------------------
create function public.purge_old_events()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.events where created_at < now() - interval '90 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.purge_old_events() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Indeks
-- ---------------------------------------------------------------------------
-- Sudah ada dari migrasi sebelumnya: events (circle_id, created_at desc), circle_members (user_id),
-- places (circle_id, migrasi places), push_outbox belum terkirim (migrasi notifikasi).
--
-- events: purge menurut waktu, dan (user_id, ...) untuk cascade hapus akun serta batas laju SOS.
create index events_created_idx on public.events (created_at);
create index events_user_created_idx on public.events (user_id, created_at desc);

-- location_points: unique (user_id, recorded_at) sudah dipakai kueri menaik MAUPUN menurun
-- (btree bisa dipindai mundur), jadi indeks menurun spike redundan. Indeks recorded_at murni
-- untuk purge_old_location_points. Catatan: saat tabel dipartisi nanti, indeks ini ikut ditinjau.
drop index public.location_points_user_recorded_idx;
create index location_points_recorded_idx on public.location_points (recorded_at);

-- ---------------------------------------------------------------------------
-- Penjadwalan pg_cron (aman dijalankan walau ekstensi tidak ada)
-- ---------------------------------------------------------------------------
-- Dijadwalkan: purge titik lokasi tiap jam, purge akun terhapus harian 03:00 UTC, purge events
-- harian 03:10 UTC. cron.schedule(nama, ...) memperbarui job bernama sama, jadi idempoten.
-- Bila pg_cron tidak tersedia (image lain / tanpa shared_preload_libraries), migrasi hanya memberi
-- NOTICE dan fungsi purge tetap tanpa jadwal: panggil dari scheduler lain.
do $$
begin
  if not exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    raise notice 'pg_cron tidak tersedia: purge TIDAK dijadwalkan';
    return;
  end if;

  begin
    create extension if not exists pg_cron;
    perform cron.schedule('tether_purge_location_points', '0 * * * *',
      'select public.purge_old_location_points()');
    perform cron.schedule('tether_purge_deleted_accounts', '0 3 * * *',
      'select public.purge_deleted_accounts()');
    perform cron.schedule('tether_purge_events', '10 3 * * *',
      'select public.purge_old_events()');
  exception when others then
    raise notice 'pg_cron gagal dijadwalkan (%): purge TIDAK dijadwalkan', sqlstate;
  end;
end;
$$;
