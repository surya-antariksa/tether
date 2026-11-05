# Sprint 0A: Catatan dan Hasil

Branch: `sprint/0-spike` | Tanggal: 2026-11-04 | Status: **selesai dikerjakan, menunggu review pemilik produk**

Cakupan: alur data lokasi ujung ke ujung di Linux (T0.1 bagian Linux, T0.2 sampai T0.5, T0.7). Bagian Android (T0.6) dan seluruh Sprint 0B (ponsel) **belum dikerjakan**.

## Yang dibangun
| Area | Isi |
|------|-----|
| Target | Folder `linux/` ditambahkan. Aplikasi desktop Linux bisa dibangun. |
| Domain | `LocationPoint`, `LocationSource`, `TrackingPolicy` (angka awal, perlu kalibrasi di 0B) |
| Data | `SimulatedLocationSource` (rute lewat "Titik Uji"), `PointQueue` (SQLite via drift, dan versi memori untuk tes), `LocationUploader`, `SupabaseLocationApi`, `TrackingController` |
| Harness | `SpikePage`: mulai atau berhenti rute simulasi, saklar putus jaringan simulasi, penghitung antrean, terkirim, dilewati server, dibuang |
| Backend | Supabase lokal (Docker). Tabel `location_points`, `member_status`, `places`, `events` dengan RLS. RPC `upload_points`. Trigger geofence dengan debounce 2 titik. `purge_old_location_points()` |

## Bukti (dijalankan ulang oleh saya setelah perbaikan)
| Pemeriksaan | Hasil |
|-------------|-------|
| `flutter analyze` | Bersih |
| `flutter test` tanpa server | 60 lulus, 10 dilewati (tes integrasi, butuh server) |
| `npx supabase test db` | 98 lulus, 0 gagal |
| Tes integrasi (klien Flutter ke Supabase lokal) | 10 lulus |
| `flutter build linux --debug` | Berhasil |

Tes integrasi membuktikan, terhadap server sungguhan: rute simulasi menghasilkan tepat satu event `arrive` lalu satu `leave`, kirim ulang tidak menggandakan baris, nilai null untuk akurasi/kecepatan/baterai diterima, dan titik buruk dibuang tanpa menghalangi titik sehat.

## Temuan tinjauan dan tindak lanjut
| Temuan | Tingkat | Status |
|--------|---------|--------|
| Kode galat 22023 dipakai juga untuk "waktu di masa depan", sehingga jam perangkat maju membuat klien membuang semua titik sehat tanpa jejak | Tinggi | Diperbaiki: server memakai kode khusus `TH001`, klien menahan titik. Pemutus sirkuit: batch ukuran 3 atau lebih yang ditolak seluruhnya ditahan, bukan dibuang |
| Titik terakhir rute bisa hilang saat rute selesai | Rendah | Diperbaiki, tes baru terbukti gagal pada kode lama |
| `sqlite3_flutter_libs` sudah tidak berfungsi | Rendah | Dihapus |
| "Terkirim" menghitung titik yang dilewati server | Rendah | Diperbaiki, ada penghitung "Dilewati server" |
| Indeks redundan, purge tanpa indeks `recorded_at` | Rendah | **Ditunda** ke Sprint 3 (partisi) |
| Pendaftaran anonim aktif dan RPC tanpa pembatas laju | Rendah | **Ditunda** ke Sprint 1. Aman di Supabase lokal. **Jangan** `supabase config push` atau `db push` ke proyek cloud sebelum itu |

Catatan: tinjauan dilakukan dengan membaca kode (peninjau tidak bisa menjalankan tes). Perbaikan sudah saya verifikasi dengan menjalankan semua tes.

## Keputusan
- **ADR-004 (peta): `flutter_map` dengan tile OSM atau penyedia tile.** Dasar: tag platform di pub.dev (diperiksa 2026-11-04) menunjukkan `flutter_map` mendukung Android, iOS, Linux, web, Windows, macOS, sedangkan `google_maps_flutter` hanya Android, iOS, dan web. Karena Anda menguji di Linux, hanya `flutter_map` yang bisa dipakai di semua klien. Yang belum diputuskan: penyedia tile (biaya dan kebijakan pemakaian OSM). Itu diputuskan di Sprint 3.
- **ADR-005 (pustaka lokasi): ditunda ke Sprint 0B**, karena butuh GPS asli dan ponsel. `geolocator` terdaftar mendukung Linux di pub.dev, tetapi perilaku GPS-nya di Linux belum diuji.

## Yang BELUM terverifikasi
- Seluruh perilaku di Android (izin, foreground service, build APK). Lisensi Android SDK belum disetujui.
- Emulator belum dijalankan. UI `SpikePage` belum pernah dilihat di layar.
- Pelacakan background, GPS asli, baterai (Sprint 0B).
- Skenario server diputus di tengah rute pada aplikasi sungguhan (hanya diuji lewat tes unit dengan API palsu).
- Batas pendaftaran anonim lokal (30 per jam per IP): tes integrasi membuat 3 user per run, jadi lebih dari sekitar 10 run per jam akan gagal.
- Tes pgTAP `04_purge` sempat gagal sekali ketika tabel berisi data dari tes integrasi, dan lulus setelah `db reset`. Kemungkinan tes bergantung pada tabel yang bersih. Belum diperbaiki.

## Cara menjalankan sendiri
Supabase lokal sudah berjalan. Bila komputer dinyalakan ulang, jalankan `npx supabase start` di folder proyek.

Harness (jendela desktop Linux):
```
set -a; eval "$(npx supabase status -o env)"; set +a
flutter run -d linux --dart-define=SUPABASE_URL=$API_URL --dart-define=SUPABASE_ANON_KEY=$ANON_KEY
```
Kunci lokal ini adalah kunci bawaan Supabase lokal, tetapi jangan ditempel ke berkas atau chat.

Tes:
```
flutter test
npx supabase test db
set -a; eval "$(npx supabase status -o env)"; set +a
SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY flutter test test/integration
```

## Checklist review untuk Anda
- [ ] Jalankan harness. Tekan "Mulai rute simulasi". Penghitung "Terkirim" naik sampai rute selesai.
- [ ] Ulangi, lalu nyalakan "Putuskan jaringan (simulasi)" di tengah rute dan matikan lagi. Antrean naik saat putus, lalu turun sampai 0 setelah tersambung, tanpa titik hilang.
- [ ] Periksa event geofence di database:
  `docker exec supabase_db_tether psql -U postgres -c "select type, payload->>'recorded_at' as waktu from events order by payload->>'recorded_at'"`
  Harus ada `arrive` lalu `leave` untuk setiap rute.
- [ ] Baca ADR-004 dan setujui `flutter_map`.
- [ ] Setujui atau minta revisi, lalu putuskan commit dan push (lihat di bawah).

## Siap di-commit (belum dilakukan)
Perubahan dibagi dua commit supaya riwayat rapi:
1. Dokumen perancangan (Sprint P): `docs/` (08, 09, revisi 01, 06, 07, README) dan commit `4970d06` yang sudah ada.
2. Sprint 0A: `lib/`, `test/`, `supabase/`, `linux/`, `pubspec.*`, `.metadata`, dan `docs/sprints/`.

Berkas `*.g.dart` hasil drift tidak diabaikan `.gitignore` bawaan. Saran: ikut di-commit agar build tidak membutuhkan `build_runner`. Perlu persetujuan Anda.
