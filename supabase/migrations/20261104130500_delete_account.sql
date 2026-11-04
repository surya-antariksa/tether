-- Sprint 5: hapus akun (PRD F12). Rujukan: docs/07-uml-diagrams.md 3.4, docs/05-privacy-security.md.
--
-- Alur: delete_account() menonaktifkan akun SEGERA (deleted_at, login diblokir, sesi dicabut,
-- keluar dari semua Circle, data lokasi dan perangkat dihapus). purge_deleted_accounts() menghapus
-- tuntas baris auth.users (cascade ke semua data turunan) setelah 30 hari.

-- delete_account: tanpa argumen, user dari auth.uid(). Idempotensi: deleted_at asli dipertahankan.
-- Langkah:
--  1. Tandai profiles.deleted_at.
--  2. Hapus titik lokasi dan event milik pengguna (riwayat lokasi dan SOS tidak boleh tersisa di
--     Circle setelah akun dihapus), lalu keluar dari semua Circle lewat leave_circle (aturan sama:
--     promosi admin, Circle dihapus bila anggota terakhir; event member_left tetap diterbitkan
--     SETELAH penghapusan event pengguna agar anggota lain tahu).
--  3. Hapus devices, member_status, member_place_state, antrean push untuk pengguna ini.
--  4. Blokir login (auth.users.banned_until = 9999-12-31) dan cabut semua sesi
--     (auth.sessions; refresh_tokens ikut terhapus lewat cascade).
-- KETERBATASAN: access token (JWT) yang sudah terbit tetap valid secara kriptografis sampai
-- kedaluwarsa (jwt_expiry, 1 jam di config lokal); yang dicabut adalah kemampuan refresh dan login.
create function public.delete_account()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_circle uuid;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;

  update public.profiles set deleted_at = coalesce(deleted_at, now()) where id = v_uid;
  if not found then
    raise exception 'profil tidak ditemukan' using errcode = 'P0002';
  end if;

  delete from public.location_points where user_id = v_uid;
  delete from public.events where user_id = v_uid;

  -- Urut circle_id agar urutan kunci konsisten. leave_circle memakai auth.uid() yang sama.
  for v_circle in
    select m.circle_id from public.circle_members m where m.user_id = v_uid order by m.circle_id
  loop
    perform public.leave_circle(v_circle);
  end loop;

  delete from public.devices where user_id = v_uid;
  delete from public.member_status where user_id = v_uid;
  delete from public.member_place_state where user_id = v_uid;
  delete from public.push_outbox where recipient_id = v_uid;

  update auth.users set banned_until = timestamptz '9999-12-31 00:00:00+00' where id = v_uid;
  delete from auth.sessions where user_id = v_uid;
end;
$$;

revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;

-- purge_deleted_accounts: menghapus tuntas akun dengan deleted_at lebih tua dari 30 hari.
-- Hanya postgres/service_role (bukan klien). Menghapus auth.users: cascade ke profiles, devices,
-- notification_settings, circle_members, location_points, member_status, member_place_state,
-- events, push_outbox, join_attempts, sesi. Pengaman: Circle tanpa anggota (yatim) ikut dihapus.
-- Mengembalikan jumlah akun yang dihapus.
create function public.purge_deleted_accounts()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  c_grace constant interval := interval '30 days';
  v_deleted integer;
begin
  delete from auth.users u
  where u.id in (select p.id from public.profiles p
                 where p.deleted_at is not null and p.deleted_at < now() - c_grace);
  get diagnostics v_deleted = row_count;

  delete from public.circles c
  where not exists (select 1 from public.circle_members m where m.circle_id = c.id);

  return v_deleted;
end;
$$;

revoke all on function public.purge_deleted_accounts() from public, anon, authenticated;
