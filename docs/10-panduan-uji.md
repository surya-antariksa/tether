# 10. Panduan Uji Manual (Linux)

Versi: Draf 1, 2026-11-05. Untuk pemilik proyek, dijalankan di komputer Linux dengan Supabase lokal. Mencakup hasil Sprint 1 sampai 5 versi Linux (lihat [sprints/sprint-1-5.md](sprints/sprint-1-5.md)). Bagian yang butuh Android atau ponsel ada di Bagian B dan **belum bisa diuji**.

Status verifikasi dokumen ini: langkah dan teks layar disusun dari kode dan berkas teks aplikasi, tetapi saya belum menjalankan panduan ini di layar. Jika teks tombol atau letaknya berbeda dari yang tertulis, catat di kolom revisi. Perintah dua instance (`XDG_DATA_HOME=/tmp/tether-b`) **belum diuji sungguhan**.

## 0. Persiapan

### 0.1 Jalankan Supabase lokal
```
cd /home/antariksa/project/pribadi/tether
npx supabase start
npx supabase db reset
```
`db reset` menghapus semua data lokal dan menerapkan ulang migrasi, sehingga uji mulai bersih. Port API 54321, DB 54322. Studio dan inbucket sengaja mati, jadi tidak ada email konfirmasi (konfirmasi email dimatikan di config lokal).

### 0.2 Ambil kunci lokal (jangan ditempel ke berkas atau chat)
```
set -a; eval "$(npx supabase status -o env)"; set +a
```
Perintah ini mengisi `API_URL` dan `ANON_KEY` di terminal itu saja. Ulangi di setiap terminal baru.

### 0.3 Dua instance aplikasi (dua pengguna)
Terminal A (Pengguna A, "Ayah"):
```
set -a; eval "$(npx supabase status -o env)"; set +a
flutter run -d linux --dart-define=SUPABASE_URL=$API_URL --dart-define=SUPABASE_ANON_KEY=$ANON_KEY --dart-define=SIMULATE_LOCATION=true
```
Terminal B (Pengguna B, "Ibu"), data sesi terpisah:
```
set -a; eval "$(npx supabase status -o env)"; set +a
XDG_DATA_HOME=/tmp/tether-b flutter run -d linux --dart-define=SUPABASE_URL=$API_URL --dart-define=SUPABASE_ANON_KEY=$ANON_KEY
```
Dasar: aplikasi Linux memakai `G_APPLICATION_NON_UNIQUE`, dan `XDG_DATA_HOME` terpisah memisahkan sesi dan antrean. **Belum diuji sungguhan.** Bila instance B memakai sesi A atau gagal terbuka, catat di bagian revisi.

Instance B tidak diberi `SIMULATE_LOCATION` supaya hanya A yang mengirim lokasi simulasi. Mengaktifkannya juga di B membuat B berjalan di rute yang sama (berguna untuk uji dua pengguna di satu Circle).

### 0.4 Perintah bantu pemeriksaan database
Pemeriksaan memakai `psql` di dalam container (nama container dari catatan Sprint 0A; sesuaikan bila berbeda):
```
docker exec supabase_db_tether psql -U postgres -c "<SQL>"
```
Kueri yang dipakai di bawah (jalankan dengan `-c`):
- Event terbaru: `select type, left(user_id::text,8) as pelaku, left(circle_id::text,8) as circle, payload->>'place_name' as tempat, created_at from public.events order by created_at desc limit 15`
- Jumlah titik per pengguna: `select left(user_id::text,8) as u, count(*) from public.location_points group by 1`
- Outbox: `select kind, count(*) , count(sent_at) as terkirim from public.push_outbox group by 1`

Kueri ini tidak menampilkan koordinat. Jangan menampilkan `payload` event `sos` di tempat umum.

### 0.5 Format catatan hasil
Pada setiap langkah isi: `[ ]` belum, `[x]` sesuai, `[!]` tidak sesuai (tulis apa yang terjadi di Bagian C).

---

## Bagian A. Yang bisa diuji di Linux

### A1. Daftar, masuk, keluar (Sprint 1)
Langkah (di A, lalu ulangi di B dengan email berbeda):
1. Di layar awal pilih "Daftar". Isi Email (mis. `ayah@contoh.com`), Kata sandi (minimal 8 karakter), Nama tampilan ("Ayah"). Tekan "Buat akun".
2. Kata sandi kurang dari 8 karakter atau email salah format: harus ada pesan galat, akun tidak dibuat.
3. Setelah masuk, tab bar menampilkan Peta, Circle, Aktivitas, Profil.
4. Profil: "Keluar" lalu konfirmasi. Masuk lagi dengan email yang sama.

Hasil yang diharapkan:
- [ ] Akun dibuat tanpa langkah verifikasi email (config lokal mematikannya).
- [ ] Setelah keluar dan masuk lagi, nama dan data Circle tetap ada.
- [ ] Email kedua dengan nama berbeda menghasilkan profil terpisah.

Cek database: `select left(id::text,8), display_name, deleted_at from public.profiles` menampilkan dua profil, `deleted_at` kosong.

### A2. Profil (Sprint 1)
Langkah: tab Profil, "Ubah nama" (isi "Ayah Budi"; coba kosong dan lebih dari 40 karakter), pilih "Warna penanda".
Hasil yang diharapkan:
- [ ] Nama kosong ditolak ("Nama tidak boleh kosong."), lebih dari 40 ditolak ("Nama maksimal 40 karakter.").
- [ ] Nama dan warna baru tersimpan, tampil lagi setelah aplikasi dibuka ulang.
- [ ] Foto profil dan Google sign-in TIDAK ada (tidak dikerjakan).

### A3. Buat Circle dan undang (Sprint 2)
Langkah di A:
1. Tab Circle: "Buat Circle", nama "Keluarga", "Buat".
2. "Undang": catat kode 6 karakter dan waktu berlaku. Kode tidak mengandung 0, O, 1, I, L.
3. Tekan "Salin kode".
Hasil yang diharapkan:
- [ ] Circle muncul, A berperan Admin.
- [ ] Kode berlaku sampai sekitar 48 jam ke depan.
- [ ] Menekan "Undang" lagi membuat kode baru dan kode lama tidak berlaku lagi.
- [ ] Database tidak menyimpan kode asli: `select left(code_hash,8), expires_at, used_count from public.invites`.

### A4. Gabung dengan kode (Sprint 2)
Langkah di B:
1. Tab Circle: "Gabung dengan kode", masukkan kode dari A, "Lanjut". Layar pratinjau menampilkan nama Circle dan jumlah anggota.
2. "Gabung".
3. Coba juga kode salah (6 karakter acak). Ulangi 10 kali berturut-turut.
4. Kedaluwarsa: di database jalankan `update public.invites set expires_at = now() - interval '1 minute'` lalu coba gabung dengan kode itu dari akun C (atau B setelah keluar).
Hasil yang diharapkan:
- [ ] B menjadi Anggota. A melihat B di daftar anggota tanpa menutup aplikasi (lewat event `member_joined`).
- [ ] Kode salah dan kode kedaluwarsa menghasilkan pesan yang sama (tidak membedakan sebab).
- [ ] Setelah sekitar 10 percobaan gagal dalam 15 menit muncul pesan terlalu banyak percobaan (kode `TH002`).
- [ ] Admin bisa "Keluarkan" anggota; anggota yang dikeluarkan hilang dari daftar. "Keluar dari Circle" oleh anggota biasa berhasil. Bila A (admin terakhir) keluar saat ada anggota lain, B menjadi Admin.
- [ ] Catatan keselamatan: keluar Circle tetap menghasilkan event "member_left" yang terlihat anggota lain.

Opsional (butuh banyak akun, bisa dilewati): batas 10 anggota per Circle (`TH003`) dan 5 Circle per pengguna (`TH004`) lebih mudah dicek di tes pgTAP.

### A5. Peta dan lokasi simulasi (Sprint 3)
Langkah di A dan B: tab Peta, pilih Circle "Keluarga". Ikuti onboarding izin lokasi bila muncul (tombol "Lanjut"; di desktop izin bersifat simulasi, bukan dialog Android).
1. Di A, ketuk indikator pelacakan di peta untuk membuka sheet detail. Dengan flag `SIMULATE_LOCATION=true` simulasi sudah aktif dari awal; jika belum, tekan "Mulai simulasi". Rute simulasi memutar jalur di sekitar Monas, Jakarta (bukan lokasi Anda): mulai 600 m di selatan titik uji, masuk ke tengah, diam sekitar 4 titik, lalu keluar 600 m ke timur, kira-kira 2 sampai 3 menit.
2. Di B, lihat marker A bergerak. Buka "Daftar anggota" (sheet) dan ketuk anggota untuk memusatkan peta.
3. Tombol "Pusatkan semua anggota" dan "Ke lokasi saya".
Hasil yang diharapkan:
- [ ] Marker A di peta B berpindah beberapa detik sekali tanpa muat ulang. Status A "Bergerak" lalu "Diam".
- [ ] Lencana atau teks "Menyambung ulang" tidak menetap saat jaringan normal.
- [ ] Atribusi "© OpenStreetMap contributors" terlihat. Tile butuh internet; tanpa internet peta kosong (itu bukan bug aplikasi).
- [ ] `select left(user_id::text,8), count(*) from public.location_points group by 1` bertambah untuk A selama simulasi.

### A6. Jeda berbagi (Sprint 3)
Langkah di A (saat simulasi berjalan atau setelah dimulai lagi):
1. Tombol "Jeda" di peta, pilih "15 menit" (lalu uji juga "Sampai saya nyalakan lagi").
2. Perhatikan jumlah titik A di database sebelum dan sesudah beberapa menit.
3. Di B perhatikan status A. Lalu A menekan "Lanjutkan".
Hasil yang diharapkan:
- [ ] Di A tampil "Kamu menjeda berbagi lokasi".
- [ ] Di B status A menjadi "Menjeda berbagi lokasi" dan marker berhenti bergerak.
- [ ] Jumlah titik A di database TIDAK bertambah selama jeda (server menolak diam-diam, `upload_points` mengembalikan 0).
- [ ] Tidak ada event `arrive`/`leave` baru untuk A selama jeda.
- [ ] Setelah "Lanjutkan" titik kembali bertambah. Event `paused` dan `resumed` tercatat (di Aktivitas B).

### A7. Tempat dan tiba/pergi (Sprint 4)
Langkah di A atau B:
1. Pada peta tekan "Kelola tempat" lalu "Tambah tempat". Geser peta sampai titik tengah berada di Monas (sekitar -6.2000, 106.8167; selisih di bawah 50 m tidak masalah), tekan "Pilih titik tengah peta". Nama "Monas", radius 150 sampai 300 m, "Simpan".
2. Pastikan simulasi A berjalan dari awal (hentikan lalu "Mulai simulasi" lagi).
3. Amati Aktivitas B.
Hasil yang diharapkan:
- [ ] Tepat satu "tiba" lalu satu "pergi" untuk A di Circle itu, tanpa duplikat (debounce 2 titik, jadi muncul setelah titik kedua di dalam atau luar).
- [ ] Event berisi nama tempat, tanpa koordinat.
- [ ] Radius di bawah 100 m ditolak. Tempat keenam di satu Circle ditolak (batas 5, kode `TH005`).
- [ ] Pembuat atau admin bisa mengubah nama dan radius atau menghapus tempat; anggota lain yang bukan pembuat tidak bisa (kecuali admin). Posisi tempat tidak bisa diubah (hapus lalu buat ulang).
- [ ] Saat A dijeda, tidak ada event tiba/pergi.
- [ ] Opsional dua Circle: tempat di Circle 1 saja menghasilkan event hanya di Circle 1.

Cek database: `select type, payload->>'place_name' from public.events where type in ('arrive','leave') order by created_at`.

### A8. Aktivitas dan notifikasi (Sprint 4)
Langkah di B dengan tab Aktivitas, sementara A membuat peristiwa (gabung, jeda, tiba/pergi, check-in).
Hasil yang diharapkan:
- [ ] Daftar aktivitas bertambah di atas tanpa muat ulang. Kalimat memakai nama pelaku.
- [ ] Lencana belum dibaca muncul di tab Aktivitas saat B di tab lain, dan hilang setelah dibuka.
- [ ] Notifikasi desktop lokal muncul di B saat aplikasi B terbuka. **Belum diverifikasi** di desktop Linux Anda (butuh layanan notifikasi desktop). Tidak ada notifikasi saat aplikasi ditutup: itu batasan yang disengaja untuk sementara (ADR-011).
- [ ] "Muat yang lebih lama" memuat halaman berikutnya bila ada banyak event.
- [ ] Tidak ada layar pengaturan notifikasi (`notification_settings` ada di server tanpa UI).
- [ ] Baris `push_outbox` bertambah (`select kind, count(*), count(sent_at) from public.push_outbox group by 1`) dan `sent_at` tetap kosong: pengirim FCM belum ada.

### A9. Check-in (Sprint 5)
Langkah di A: tekan tombol perisai berlabel "Keselamatan: check-in dan SOS" di peta, lembar "Keselamatan" terbuka. Tekan "Saya sudah sampai", lalu langsung tekan "Saya aman".
Hasil yang diharapkan:
- [ ] Pesan "Terkirim ke Circle: Saya sudah sampai."
- [ ] Check-in kedua dalam 30 detik ditolak: "Check-in terlalu sering. Coba lagi dalam 30 detik." Setelah 30 detik berhasil.
- [ ] B melihat check-in di Aktivitas. Tidak ada koordinat di event: `select payload from public.events where type='checkin' order by created_at desc limit 1` hanya `kind` dan `display_name`.
- [ ] Check-in tetap bisa dilakukan saat A sedang dijeda.

### A10. SOS: tahan 3 detik, hitung mundur, batal (Sprint 5)
Langkah di A, lembar "Keselamatan", bagian SOS (ada pernyataan bahwa SOS bukan pengganti layanan darurat dan nomor 112):
1. Tahan tombol "Tahan 3 detik untuk SOS" kurang dari 3 detik lalu lepas.
2. Tahan penuh 3 detik. Hitung mundur "SOS dikirim dalam 5 detik" muncul. Tekan "Batalkan" sebelum 0.
3. Ulangi, biarkan hitung mundur selesai.
4. Jalur tanpa tahan: "Mulai SOS (hitung mundur 5 detik)".
5. Picu SOS empat kali dalam 10 menit.
Hasil yang diharapkan:
- [ ] Lepas sebelum 3 detik: tidak terjadi apa-apa.
- [ ] Setelah dibatalkan, TIDAK ada event `sos` di database (`select count(*) from public.events where type='sos'`).
- [ ] Hitung mundur selesai: "SOS terkirim", B melihat SOS di Aktivitas (lencana SOS) dengan tombol "Lihat di peta" yang membuka lokasi. Satu event per Circle milik A.
- [ ] SOS tetap terkirim walau A sedang dijeda.
- [ ] Percobaan keempat dalam 10 menit ditolak: "Terlalu sering memicu SOS (maksimal 3 kali per 10 menit)...".
- [ ] A tanpa Circle: pesan "Kamu belum punya Circle, jadi tidak ada yang bisa diberi tahu."
- [ ] **Risiko di Linux, belum diverifikasi:** lokasi SOS diambil lewat `geolocator` langsung, bukan dari lokasi simulasi. Di desktop bisa muncul "Lokasi tidak tersedia. Aktifkan GPS dan izin lokasi untuk Tether..." dan SOS tidak terkirim. Bila itu terjadi, catat di Bagian C. Itu temuan, bukan kesalahan Anda. Uji tetap penting untuk alur batal dan antrean.

### A11. SOS offline (Sprint 5)
Langkah (perlu lokasi SOS berhasil diperoleh, lihat risiko di A10):
1. Di A, picu SOS tetapi sebelum hitung mundur selesai matikan Supabase lokal di terminal lain: `npx supabase stop`. (Alternatif yang lebih ringan: `docker stop supabase_kong_tether`; nama container belum dipastikan.)
2. Biarkan hitung mundur selesai. Muncul "SOS belum terkirim ... disimpan dan dicoba lagi otomatis".
3. Tunggu sekitar 1 menit, lalu nyalakan lagi: `npx supabase start` (atau `docker start supabase_kong_tether`). Data lokal seharusnya tetap ada setelah `stop` biasa; bila akun hilang, `db reset` telah terjadi dan uji ulang dari A1. Itu **belum diverifikasi**.
4. Amati A dan B.
Hasil yang diharapkan:
- [ ] Setelah server hidup, SOS terkirim sendiri dalam sekitar 1 menit (jeda coba ulang 2, 4, 8, 16, 32 lalu 60 detik).
- [ ] B menerima tepat satu SOS per Circle, tidak ganda walau dicoba berkali-kali (`client_id` idempoten).
- [ ] Coba juga: matikan server, picu SOS, tutup aplikasi A, nyalakan server, buka A lagi. SOS terkirim setelah aplikasi dibuka (antrean disimpan di berkas `tether_sos_queue.json`; cari dengan `find ~/.local/share /tmp/tether-b -name tether_sos_queue.json 2>/dev/null`). Berkas memuat koordinat, jangan dibagikan.
- [ ] Bila server mati lebih dari 1 hari, SOS dibuang dengan pesan "SOS tertunda terlalu lama dan dibatalkan". Tidak praktis diuji; cukup dicatat.

### A12. Riwayat 48 jam dan hapus (Sprint 5)
Langkah di A setelah simulasi mengirim titik: tab Profil, "Riwayat lokasi" (48 jam terakhir).
1. Lihat peta jejak dan daftar titik (Hari ini, Kemarin; Bergerak atau Diam).
2. "Hapus riwayat", konfirmasi.
Hasil yang diharapkan:
- [ ] Jejak dan daftar muncul, titik terlama dan terbaru bertanda.
- [ ] Setelah hapus, tampilan "Belum ada riwayat" dan `select count(*) from public.location_points where user_id = (select id from public.profiles where display_name='Ayah Budi')` bernilai 0.
- [ ] Posisi terakhir A di peta B TIDAK hilang (itu `member_status`, bukan riwayat) dan event Aktivitas tetap ada. Ini perilaku yang dirancang; catat bila Anda ingin lain.
- [ ] Hanya titik 48 jam terakhir yang tampil. Titik lebih lama dari 48 jam (bila ada) tidak tampil. Uji dengan menyisipkan titik lama lewat SQL sebagai postgres bila perlu.

### A13. Hapus akun (Sprint 5)
Gunakan akun uji (mis. akun C atau B), bukan akun yang masih dibutuhkan.
1. Tab Profil, "Hapus akun". Baca daftar yang dihapus dan masa tenggang 30 hari. Tekan "Hapus akun saya", "Lanjutkan", ketik `HAPUS`, "Hapus akun".
2. Coba masuk lagi dengan email yang sama.
3. Cek database sebagai postgres:
   - `select left(id::text,8), deleted_at from public.profiles where deleted_at is not null`
   - `select count(*) from public.location_points` untuk pengguna itu (harus 0), `select count(*) from public.circle_members` untuk pengguna itu (harus 0).
4. Uji pembersihan 30 hari secara lokal: `update public.profiles set deleted_at = now() - interval '31 days' where deleted_at is not null; select public.purge_deleted_accounts();` (mengembalikan jumlah akun yang dihapus) lalu `select count(*) from auth.users`.
Hasil yang diharapkan:
- [ ] Konfirmasi ganda, tidak bisa lanjut sebelum `HAPUS` diketik dengan benar (perilaku tombol akhir belum saya periksa di layar).
- [ ] Setelah hapus, aplikasi kembali ke layar masuk. Masuk lagi GAGAL.
- [ ] Anggota lain (A) melihat event bahwa anggota itu keluar dari Circle.
- [ ] Bila akun itu admin terakhir, anggota tertua dipromosikan; bila anggota terakhir, Circle hilang.
- [ ] Setelah `purge_deleted_accounts()` baris `auth.users` hilang.
- [ ] **Keterbatasan diketahui:** token lama masih sah sampai 1 jam. Instance lain yang masih terbuka dengan akun itu mungkin masih bisa mengirim lokasi sampai token habis (ditunda, lihat sprint-1-5).

### A14. Retensi dan penjadwalan (Sprint 5)
Sebagai postgres:
- `select jobname, schedule from cron.job order by jobname` (bila error `relation "cron.job" does not exist`, pg_cron tidak tersedia di image lokal: catat, itu perilaku yang diantisipasi ADR-013).
- `select public.purge_old_location_points()` mengembalikan jumlah titik > 48 jam yang dihapus.
- `select public.purge_old_events()` dan cek bahwa event `sos` lebih dari 48 jam tidak lagi menyimpan `lat`/`lng` (sisipkan data uji lewat SQL; jangan tampilkan nilainya).
Hasil yang diharapkan:
- [ ] Bila pg_cron tersedia: tiga job `tether_purge_deleted_accounts` (0 3 * * *), `tether_purge_events` (10 3 * * *), `tether_purge_location_points` (0 * * * *).
- [ ] Fungsi purge berjalan tanpa galat.

### A15. Tes otomatis (opsional, untuk pembanding)
```
flutter analyze
flutter test
npx supabase test db
set -a; eval "$(npx supabase status -o env)"; set +a
SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY flutter test test/integration
```
Jangan menjalankan tes integrasi berulang terlalu sering (batas pendaftaran anonim 30 per jam per IP). `npx supabase db reset` sebelum tes pgTAP bila tabel berisi data uji manual (sebelumnya `04_purge` pernah gagal pada tabel berisi data).

---

## Bagian B. Butuh Android atau ponsel (BELUM bisa diuji)

Semua di bagian ini belum dikerjakan atau belum terbukti. Jangan menandainya lulus sebelum diuji sungguhan.

- [ ] Sprint 0B: pelacakan lokasi background di Redmi (foreground service, interval, akurasi, kematian oleh sistem), konsumsi baterai 24 jam, panduan hemat baterai Redmi. Menentukan ADR-005 (pustaka lokasi background).
- [ ] Build dan jalan di Android (emulator dan ponsel), termasuk dialog izin lokasi (saat dipakai, sepanjang waktu) dan izin notifikasi.
- [ ] Pengungkapan menonjol (prominent disclosure) izin lokasi background sesuai kebijakan Google Play.
- [ ] Notifikasi persisten "Tether aktif" saat melacak.
- [ ] FCM: pendaftaran token (`register_device` dipanggil dengan token nyata), pengirim dari `push_outbox`, push saat aplikasi ditutup dan ponsel terkunci, prioritas tinggi untuk SOS, tidak ada push ganda (termasuk anggota yang ada di 2 Circle).
- [ ] Notifikasi lokal di Android (kanal `tether_activity` dan `tether_sos`, penahanan oleh pabrikan).
- [ ] SOS di ponsel: lokasi GPS nyata, antrean saat jaringan putus, pemulihan setelah aplikasi dimatikan paksa.
- [ ] TalkBack: jalur SOS tanpa tahan, urutan fokus, pengumuman hitung mundur, label tombol.
- [ ] Layar dan font: ukuran font sistem terbesar, mode gelap, kontras tinggi di ponsel.
- [ ] Google sign-in (belum dibangun).
- [ ] Uji di berbagai merek (Samsung, Xiaomi, Oppo/Realme, Vivo) sesuai matriks di 06.

## Prasyarat dari pemilik (belum dilakukan)
1. Setujui lisensi Android SDK: `flutter doctor --android-licenses`, lalu `flutter doctor` untuk memastikan toolchain Android lengkap. Tanpa ini build Android terblokir.
2. Buat proyek Firebase (Cloud Messaging untuk FCM) dan putuskan penyimpanan `google-services.json` (T4.7). Kunci rahasia tidak dikirim lewat chat.
3. Siapkan proyek Google Cloud dan OAuth (client ID, SHA-1 keystore) bila Google sign-in akan dibuat.
4. Buat akun Google Play Console dan cek aturan uji tertutup untuk akun baru (T1.10).
5. Tinjauan hukum: kebijakan privasi, syarat layanan, teks persetujuan, usia minimum, dan pendaftaran PSE (lihat 05 bagian 8 dan 9).
6. Satu ponsel Redmi untuk Sprint 0B (dan perangkat tambahan untuk matriks bila ada).
7. Sebelum deploy ke Supabase cloud: tinjau pendaftaran anonim (`enable_anonymous_sign_ins`) dan konfirmasi email, dan pastikan `pg_cron` tersedia. Jangan `config push` atau `db push` sebelum itu.

---

## Bagian C. Catatan revisi dari pemilik

Isi satu baris per temuan. Kolom "Langkah" merujuk nomor di atas (mis. A7).

| Tanggal | Langkah | Yang terjadi | Yang diharapkan | Tingkat (blokir, mengganggu, kosmetik) | Status |
|---------|---------|--------------|-----------------|----------------------------------------|--------|
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

Keputusan yang menunggu Anda (dari [sprints/sprint-1-5.md](sprints/sprint-1-5.md)):
- [ ] SOS tetap berlaku saat dijeda dan membawa koordinat (ADR-012): setuju atau ubah?
- [ ] Nasib `set_sharing_enabled` (dipakai UI atau dihapus).
- [ ] Penanganan akun terhapus dengan JWT berlaku.
- [ ] Cara memantau `pg_cron` setelah deploy.
- [ ] Pemecahan commit per sprint dan tag.
