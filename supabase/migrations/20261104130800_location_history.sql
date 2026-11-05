-- Sprint 5: riwayat lokasi 48 jam dan hapus riwayat (PRD F11).
-- Membaca riwayat sendiri sudah dibolehkan kebijakan location_points_select_circle
-- (user_id = auth.uid()). Klien tidak punya hak DELETE, jadi penghapusan lewat RPC ini.

-- delete_my_location_history: menghapus SEMUA titik lokasi milik pemanggil. Mengembalikan jumlah
-- titik yang dihapus. Yang TIDAK dihapus: member_status (posisi terakhir yang dilihat Circle;
-- itu lokasi saat ini, bukan riwayat, dan berhenti diperbarui bila berbagi dijeda atau dimatikan)
-- dan events (check-in, SOS, datang/pergi).
create function public.delete_my_location_history()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_deleted integer;
begin
  if v_uid is null then
    raise exception 'tidak terautentikasi' using errcode = '28000';
  end if;
  delete from public.location_points where user_id = v_uid;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.delete_my_location_history() from public, anon;
grant execute on function public.delete_my_location_history() to authenticated;
