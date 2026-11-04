-- Sprint 4/5: perbaikan kebocoran Realtime.
-- Event DELETE pada Postgres Changes TIDAK difilter RLS (membawa primary key ke semua pelanggan
-- kanal), sehingga tabel circle_members (PK = circle_id + user_id) membocorkan siapa keluar dari
-- Circle mana. Tabel dikeluarkan dari publikasi. Klien mengandalkan events member_joined,
-- member_left, member_removed (diterbitkan RPC) lalu mengambil ulang daftar anggota.
-- member_status dan events tetap dipublikasikan: PK member_status hanya user_id dan INSERT/UPDATE
-- tetap diperiksa RLS; events tidak pernah dihapus klien.
alter publication supabase_realtime drop table public.circle_members;
