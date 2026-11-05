# 06. Roadmap, Spike, dan Rencana Pengujian

Versi: Draf 1. Durasi adalah perkiraan kasar untuk satu pengembang dan harus dikoreksi setelah Fase 0.

> **Diganti sebagian oleh [09-sprint-plan.md](09-sprint-plan.md):** rilis pertama hanya Android lewat Google Play, perangkat uji hanya satu Redmi dan emulator (matriks perangkat dan langkah iOS di bawah belum berlaku), dan jadwal memakai siklus kerjakan, review, revisi per sprint tanpa tanggal kalender.

## Fase

### Fase 0: Validasi (spike) ~ 2 minggu
Tujuan: membuktikan inti teknis sebelum investasi besar.
- [ ] Aplikasi Flutter minimal yang mengirim lokasi di background ke Supabase.
- [ ] Uji di minimal 3 perangkat nyata: satu Samsung, satu Xiaomi/Oppo/Vivo, satu iPhone.
- [ ] Ukur: baterai per jam saat diam dan bergerak, ketahanan setelah aplikasi dibersihkan dari recent apps, perilaku setelah ponsel dikunci lama.
- [ ] Bandingkan 2 pustaka lokasi (ADR-005).
- [ ] Uji geofence server: latensi dan debounce.
- [ ] Putuskan peta (ADR-004) dan pustaka lokasi.

**Kriteria lulus:** titik lokasi tetap masuk di 3 perangkat selama 4 jam skenario campuran, dampak baterai dapat diterima. Bila gagal, tinjau ulang pendekatan (misalnya kode native) sebelum lanjut.

### Fase 1: Fondasi ~ 2 minggu
Repo, CI, struktur proyek, tema, routing, Supabase dev (skema, RLS, migrasi), autentikasi, profil.

### Fase 2: Circle dan Peta ~ 3 minggu
Buat dan gabung Circle, peta real-time, status anggota, kontrol jeda, onboarding izin.

### Fase 3: Tempat, Check-in, SOS, Push ~ 3 minggu
Places dan geofence, notifikasi, check-in, SOS, riwayat 48 jam.

### Fase 4: Pengerasan dan Rilis ~ 3 minggu
Pengujian beta tertutup (keluarga dan teman), perbaikan baterai dan keandalan, kebijakan privasi, submit ke store, penanganan review.

### Fase 5: Pasca-MVP
Evaluasi metrik, putuskan monetisasi, fitur tunda (chat, berkendara, dan lainnya).

## Rencana pengujian
| Level | Cakupan | Alat |
|-------|---------|------|
| Unit | Logika domain, pelacakan adaptif, debounce | `flutter test` |
| Widget | Layar utama, onboarding izin | `flutter test` |
| Integrasi | Alur Circle, jeda, SOS | `integration_test` |
| Database | RLS, fungsi geofence | Tes SQL (pgTAP atau skrip Supabase CLI) |
| Lapangan | Pelacakan sungguhan: berjalan, motor, mobil, ruangan tertutup, mode hemat daya | Perangkat nyata, catat hasil dalam tabel |
| Baterai | Selisih konsumsi dengan dan tanpa Tether | Pengukuran 24 jam per perangkat |

**Matriks perangkat minimum:** Samsung (One UI), Xiaomi (MIUI/HyperOS), Oppo/Realme (ColorOS), Vivo (Funtouch), iPhone. Android 10, 12, 14 jika memungkinkan.

## Perkiraan biaya awal **[Belum diverifikasi, cek harga terkini]**
| Item | Perkiraan |
|------|-----------|
| Apple Developer Program | sekitar USD 99 per tahun |
| Google Play Console | sekitar USD 25 sekali bayar |
| Supabase | Tier gratis untuk dev, berbayar saat produksi |
| Tile peta | Gratis sampai ambang tertentu, tergantung penyedia |
| Push (FCM) | Gratis |
| Domain dan halaman kebijakan | Biaya kecil |

## Risiko dan keputusan bergantung
| Risiko | Pemicu tinjauan |
|--------|-----------------|
| Pelacakan background tidak andal | Hasil Fase 0 |
| Biaya peta | Hasil Fase 0 dan proyeksi pengguna |
| Penolakan store | Persiapan rilis di Fase 4. Lakukan pra-cek kebijakan di Fase 2 |

## Definisi selesai (per fitur)
Kode ditinjau, tes relevan lulus, RLS diuji bila menyentuh data, teks Indonesia final, tidak ada koordinat di log, dicoba di perangkat nyata untuk fitur lokasi.

## Langkah berikutnya
1. Jalankan Fase 0.
2. Pasang pesaing dan lengkapi 02 (hapus tanda [V]).
3. Jawab pertanyaan terbuka di 01, 03, 04, 05.
4. Desain wireframe dan UI di Figma berdasarkan F1 sampai F13.
