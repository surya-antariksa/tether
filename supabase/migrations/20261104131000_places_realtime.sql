-- Tempat (places) dijadikan sumber Realtime: perubahan tempat oleh anggota lain dulu hanya
-- terlihat setelah muat ulang. Sekarang tabel diterbitkan lewat publikasi supabase_realtime dan
-- klien peta memuat ulang daftar tempat saat ada perubahan.
--
-- Keterbatasan yang sama dengan ADR-016: Postgres Changes tidak memfilter event DELETE dengan
-- RLS, jadi DELETE membawa primary key tempat (UUID acak, tanpa nama maupun Circle) ke semua
-- pelanggan kanal. INSERT dan UPDATE tetap diperiksa kebijakan SELECT per pelanggan (hanya
-- anggota Circle). Risiko ini diterima dan tercatat di dokumen data.
alter publication supabase_realtime add table public.places;
