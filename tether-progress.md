# Catatan Progres Tether

Log singkat progres pekerjaan. Detail per sprint ada di `docs/sprints/sprint-1-5.md`.

## 2026-11-05 — Gelombang 4 perbaikan audit + fitur pengaturan notifikasi

Branch `sprint/0-spike`. Semua perubahan masih di working tree, belum di-commit.

### Migrasi baru (tidak menyentuh migrasi lama)
- `20261104130900_guard_sharing_outbox.sql` (ADR-017):
  - Penjaga `assert_account_active()`: semua RPC tulis menolak akun terhapus (`28000`). Tanpa penjaga: `delete_account` (idempoten) dan `leave_circle` (dipakai hapus akun).
  - `set_sharing_enabled` menerbitkan event `sharing_changed` (payload `enabled`) hanya bila nilai berubah.
  - Dedup outbox SOS: tidak ada baris kedua untuk `(penerima, client_id)` yang sama.
  - `tether_purge_deleted_accounts` dijadwalkan tiap jam menit 17.
  - Alarm keras: migrasi GAGAL bila pg_cron ada tetapi job tidak lengkap (ADR-013).
- `20261104131000_places_realtime.sql` (ADR-018): tabel `places` dipublikasikan Realtime.

### Klien
- Tipe baru `sharingChanged` (tampil di tab Aktivitas dengan kalimat dan ikonnya) dan `PlacesChanged` (peta; refresh daftar tempat).
- Dedup notifikasi lokal SOS berdasarkan `client_id`.
- Halaman Pengaturan Notifikasi di Profil (3 sakelar per preferensi, catatan SOS selalu dikirim, galat memuat/simpan).
- Sakelar "Berbagi lokasi" di tab Circle: UI pertama untuk RPC `set_sharing_enabled` (milik sendiri, per Circle); gagal menyimpan mengembalikan sakelar dan menampilkan dialog. `memberEventTypes` circle memuat `sharing_changed` agar tab Circle muat ulang otomatis.

### Verifikasi
| Pemeriksaan | Hasil |
|-------------|-------|
| `flutter analyze` | Bersih |
| `flutter test` | 765 lulus, 19 dilewati |
| pgTAP `npx supabase test db` | 666 lulus, dua kali berurutan |
| Tes integrasi (sekali, batas pendaftaran lokal) | 19 lulus |
| `flutter build linux --debug` | Berhasil |

### Dokumen
- `docs/03-architecture.md`: ADR-013, ADR-014 diperbarui; ADR-016 (sisa DELETE diterima), ADR-017, ADR-018 baru.
- `docs/04-data-model.md`: event `sharing_changed`, penjaga RPC, publikasi `places`, jadwal purge, tes 666.
- `docs/05-privacy-security.md`: model ancaman dan hapus akun diperbarui.
- `docs/sprints/sprint-1-5.md`: tabel diperbaiki/ditunda diperbarui, bukti verifikasi.

### Terbuka (butuh keputusan/pengguna)
- Review GUI: sakelar "Berbagi lokasi" di tab Circle, pengaturan notifikasi di Profil, peta realtime (Langkah 3, manual).
- Lisensi Android, Sprint 0B, FCM, Google sign-in, Play Console, tinjauan hukum: belum dikerjakan.
- Sisa risiko baca token lama sampai kedaluwarsa; DELETE Realtime pada `member_status`, `events`, `places` membawa kunci tanpa filter (diterima).
