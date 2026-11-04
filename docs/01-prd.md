# 01. PRD: Tether MVP

Versi: Draf 1 | Tanggal: 2026-11-04

## 1. Tujuan
- Membuktikan keluarga mau memakai berbagi lokasi harian dengan Tether.
- Pelacakan background yang andal di Android dan iOS dengan dampak baterai wajar.
- Siap lolos review Google Play dan App Store.

## 2. Metrik sukses (MVP)
| Metrik | Target awal [asumsi, sesuaikan] |
|--------|----------------|
| Circle aktif dengan 2+ anggota, hari ke-7 | 40% dari Circle yang dibuat |
| Anggota dengan lokasi diperbarui dalam 15 menit terakhir (saat izin aktif) | 90% |
| Konsumsi baterai tambahan per hari | di bawah 5% [perlu diukur di spike] |
| Crash-free sessions | 99% |
| Waktu dari instal ke bergabung Circle | di bawah 3 menit |

## 3. Persona
Lihat [00-product-brief](00-product-brief.md): Ibu Rina (admin Circle), Raka (anggota remaja), Dedi (anggota dewasa).

## 4. Ruang lingkup MVP

### Wajib (Must)
| ID | Fitur | Keterangan |
|----|-------|------------|
| F1 | Autentikasi | Daftar dan masuk dengan email + Google. Verifikasi email. |
| F2 | Profil | Nama, foto, warna penanda peta. |
| F3 | Circle | Buat Circle, undang lewat kode atau tautan, gabung, keluar. Admin dapat mengeluarkan anggota. |
| F4 | Peta real-time | Posisi anggota Circle, waktu pembaruan terakhir, level baterai, status bergerak atau diam. |
| F5 | Berbagi lokasi di background | Pelacakan adaptif, jalan saat aplikasi ditutup. |
| F6 | Kontrol privasi anggota | Tombol jeda berbagi (15 menit, 1 jam, sampai dihidupkan lagi). Anggota lain melihat status "dijeda". |
| F7 | Tempat (Places) | Admin atau anggota membuat tempat (rumah, sekolah, kantor) dengan radius. Notifikasi saat anggota tiba atau pergi. |
| F8 | Check-in | Tombol "Saya sudah sampai" dan "Saya aman" dengan satu ketukan, kirim notifikasi ke Circle. |
| F9 | SOS | Tombol darurat dengan konfirmasi (tahan 3 detik), kirim notifikasi prioritas dengan lokasi ke semua anggota. |
| F10 | Notifikasi push | Tiba atau pergi, check-in, SOS, undangan. |
| F11 | Riwayat lokasi | 48 jam terakhir per anggota, dapat dihapus oleh pemiliknya. |
| F12 | Pengaturan akun | Ubah profil, keluar, hapus akun dan seluruh datanya. |
| F13 | Onboarding izin | Penjelasan jujur sebelum meminta izin lokasi "selalu", notifikasi, dan pengecualian baterai. |

### Sebaiknya ada (Should)
- Mode hemat baterai otomatis saat baterai di bawah 15%.
- Peringatan saat anggota baterai hampir habis.
- Peringatan jika ponsel anggota berhenti mengirim lokasi lebih dari X waktu.

### Ditunda (Won't, fase berikutnya)
Chat, laporan berkendara, deteksi tabrakan, berbagi kecepatan, riwayat lokasi lebih dari 48 jam, langganan berbayar, widget, dukungan web, lokasi untuk perangkat non-ponsel.

## 5. User story dan kriteria penerimaan

**F3 Circle**
- Sebagai Ibu Rina, saya membuat Circle "Keluarga" dan mendapat kode undangan 6 karakter yang berlaku 48 jam.
  - Kode tidak dapat ditebak mudah, kedaluwarsa, dan bisa dibuat ulang.
  - Satu Circle maksimal 10 anggota di MVP. [asumsi]

**F5/F6 Berbagi lokasi**
- Sebagai Raka, saya dapat menjeda berbagi lokasi tanpa memberi alasan.
  - Setelah dijeda, tidak ada titik lokasi baru yang dikirim ke server.
  - Anggota lain melihat "Raka menjeda berbagi lokasi", bukan lokasi terakhir yang tampak seolah terkini.

**F7 Places**
- Sebagai Ibu Rina, saya mendapat notifikasi saat Raka tiba di sekolah.
  - Notifikasi terkirim dalam 2 menit setelah masuk radius (asumsi, validasi di spike).
  - Radius minimal 100 m, maksimal 5 jumlah tempat per Circle di MVP.
  - Tidak ada notifikasi ganda untuk satu kedatangan (debounce).

**F9 SOS**
- Sebagai Dedi, saya menahan tombol SOS 3 detik untuk mengirim peringatan.
  - Semua anggota menerima notifikasi prioritas tinggi dengan lokasi terbaru.
  - Ada hitung mundur pembatalan 5 detik.
  - SOS bukan pengganti layanan darurat resmi, ada keterangan jelas di aplikasi.

**F12 Hapus akun**
- Seluruh data pribadi dan lokasi terhapus dalam 30 hari, akun tidak bisa masuk segera setelah permintaan.

## 6. Kebutuhan non-fungsional
| Kategori | Kebutuhan |
|----------|-----------|
| Performa | Peta memuat posisi anggota di bawah 2 detik pada jaringan 4G. Pembaruan real-time di bawah 5 detik. |
| Baterai | Pelacakan adaptif: lebih jarang saat diam, lebih rapat saat bergerak. |
| Jaringan | Antrean lokal saat offline, kirim batch saat tersambung. Hemat kuota. |
| Keamanan | TLS, RLS di database, tidak ada kunci rahasia di klien. Lihat 05. |
| Kompatibilitas | Android 8.0+ (API 26+), iOS 15+. [asumsi, sesuaikan] |
| Lokalisasi | Bahasa Indonesia penuh, English sebagai cadangan. |
| Aksesibilitas | Kontras cukup, ukuran sentuh minimal 48 dp, mendukung font besar. |
| Observabilitas | Crash reporting, metrik keberhasilan upload lokasi, tanpa menyimpan lokasi di log. |

## 7. Risiko utama
| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Pelacakan background dihentikan OS atau pabrikan | Inti produk gagal | Spike awal, panduan pengaturan per merek, deteksi "lokasi basi" |
| Ditolak Google Play karena izin lokasi background | Tidak bisa rilis | Pengungkapan jelas, video demo, justifikasi inti fitur |
| Penyalahgunaan sebagai alat penguntit | Risiko etika dan hukum | Consent, notifikasi ke anggota, tombol jeda, tidak ada mode tersembunyi |
| Biaya peta atau realtime membengkak | Biaya | Tile OSM, batching lokasi, retensi singkat |
| Baterai boros | Pengguna uninstall | Pelacakan adaptif, pengujian baterai terukur |

## 8. Pertanyaan terbuka
1. Login nomor telepon (OTP) dibutuhkan? Lebih akrab bagi pengguna Indonesia tetapi ada biaya SMS/WhatsApp OTP.
2. Apakah admin Circle boleh melihat lokasi anggota yang dijeda? (rekomendasi: tidak)
3. Batas usia minimum dan alur persetujuan orang tua. Lihat 05.
4. Batas anggota per Circle dan jumlah Circle per pengguna.
