# Sprint 1 sampai 5: Catatan dan Hasil (versi Linux)

Branch: `sprint/0-spike` | Tanggal: 2026-11-05 | Status: **selesai dikerjakan untuk bagian yang bisa diuji di Linux, menunggu review pemilik produk**

Cakupan: Sprint 1 (fondasi dan autentikasi), 2 (Circle), 3 (peta dan berbagi lokasi), 4 (tempat dan notifikasi), 5 (check-in, SOS, riwayat, akun), semuanya hanya sejauh bisa dibangun dan dibuktikan di komputer Linux dengan Supabase lokal. Semua bagian yang butuh Android, ponsel, layanan background, baterai, atau FCM **belum dikerjakan atau belum terbukti** (lihat bagian akhir).

Catatan git: pekerjaan Sprint 1 sampai 5 belum dipecah per sprint. Per snapshot awal sesi, hanya WIP sampai Sprint 3 yang masuk commit `21d3b8e`, sisanya (Sprint 4 dan 5) ada di working tree. Tidak ada tag `sprint-N`. Pemecahan commit menunggu keputusan Anda (lihat 09 bagian alur git).

## Yang dibangun per sprint
| Sprint | Isi | Berkas utama |
|--------|-----|--------------|
| 1 Fondasi dan auth | Struktur `lib/` per fitur, Riverpod dan `go_router`, kerangka tab bar (Peta, Circle, Aktivitas, Profil), teks Indonesia, CI (`ci.yml`: build_runner, analyze, test). Tabel `profiles` dengan trigger pembuatan profil. Masuk dan daftar dengan email. Profil: nama tampilan dan warna penanda | `lib/app`, `lib/features/auth`, `lib/features/profile`, migrasi `120000` |
| 2 Circle | Tabel `circles`, `circle_members`, `invites`, `join_attempts` dan RPC buat, undang, pratinjau, gabung, keluar, keluarkan. Kode undangan 6 karakter (hash, 48 jam, maks 10 pakai), batas 10 anggota, batas percobaan gabung. Onboarding izin lokasi | `lib/features/circle`, `lib/features/tracking`, migrasi `120100` |
| 3 Peta dan berbagi | Peta `flutter_map` (OSM), marker anggota, sheet anggota, status kehadiran, Realtime `member_status`, jeda berbagi 15 menit, 1 jam, atau tanpa batas. Kebijakan baca lokasi berbasis Circle, penegakan jeda di `upload_points`. Pelacakan produksi (antrean, pengunggah, kebijakan adaptif) dengan sumber lokasi simulasi | `lib/features/map`, `lib/features/location_tracking`, migrasi `120200`, `130000` |
| 4 Tempat dan notifikasi | Tempat per Circle (RPC, batas 5, radius 100 sampai 5000 m), pemilih titik di peta, geofence per Circle dengan debounce 2 titik, tab Aktivitas dengan paginasi, lencana belum dibaca, dan notifikasi lokal. Tabel `notification_settings`, `devices`, `push_outbox` dan trigger outbox | `lib/features/places`, `lib/features/activity`, migrasi `130100`, `130200`, `130400` |
| 5 Keselamatan dan akun | Check-in ("Saya sudah sampai", "Saya aman"), SOS (tahan 3 detik, hitung mundur 5 detik bisa dibatalkan, jalur tanpa tahan untuk pembaca layar, antrean berkas JSON, coba ulang), riwayat lokasi 48 jam dengan peta dan hapus riwayat, hapus akun dengan konfirmasi ganda, retensi dan penjadwalan `pg_cron`, perbaikan audit | `lib/features/safety`, `lib/features/history`, `lib/features/profile`, migrasi `130300`, `130500`, `130600`, `130700`, `130800` |

Keputusan arsitektur yang lahir di sini dicatat sebagai ADR-009 sampai ADR-018 di [03-architecture.md](../03-architecture.md). Skema dan RPC lengkap ada di [04-data-model.md](../04-data-model.md).

Beda dari rencana 09: tidak ada Edge Function (geofence, SOS, hapus akun jadi RPC dan trigger); `location_points` belum dipartisi; Google sign-in, unggah foto profil, FCM, dan verifikasi email tidak dikerjakan (kode auth tidak memuat Google; konfirmasi email dimatikan di config lokal).

## Bukti (verifikasi terakhir)
Angka di bawah dilaporkan oleh sesi utama sebagai hasil terakhir. Saya (pelaksana dokumentasi) tidak menjalankan ulang tes dalam tugas ini; saya hanya membaca migrasi dan kode untuk menulis dokumen.

| Pemeriksaan | Hasil |
|-------------|-------|
| `flutter analyze` | Bersih |
| `flutter test` | 762 tes lulus, 19 dilewati |
| `npx supabase test db` (pgTAP) | 666 lulus, dijalankan dua kali |
| Tes integrasi (klien Flutter ke Supabase lokal) | `auth_circle_e2e`, `supabase_e2e`, `wave3_e2e` lulus (19 tes) |
| `flutter build linux --debug` | Berhasil |

Yang dibuktikan: RLS dan hak akses per tabel, batas laju (gabung, check-in, SOS), penegakan jeda di server, geofence per Circle, event dan outbox, hapus akun dan purge, idempotensi SOS, jendela baca SOS 48 jam, alur klien ke server nyata untuk auth, Circle, tempat, check-in, SOS.

## Temuan audit dan tinjauan
### Diperbaiki
| Temuan | Perbaikan |
|--------|-----------|
| Event DELETE Realtime pada `circle_members` membocorkan siapa keluar dari Circle mana | Tabel dikeluarkan dari publikasi (migrasi `130000`, ADR-016). Klien mengandalkan event `member_joined`, `member_left`, `member_removed` |
| SOS bisa menggandakan event dan push saat diulang (antrean offline) | `trigger_sos` menerima `p_client_id` dan idempoten; `p_triggered_at` membawa waktu pemicu asli, dijepit ke 1 hari terakhir (migrasi `130700`) |
| Koordinat SOS tersimpan lama dan terbaca anggota tanpa batas | Terbaca anggota hanya 48 jam (RLS), koordinat dibuang `purge_old_events` (migrasi `130700`) |
| Risiko: keanggotaan yang dijeda bisa bocor lewat arrive/leave | Dicegah sejak rancangan Sprint 4: geofence hanya mengevaluasi keanggotaan aktif (migrasi `130200`) |
| Akun terhapus masih bisa menulis selama JWT berlaku | Semua RPC tulis memanggil `assert_account_active()` yang menolak pemanggil ber-`deleted_at` (`28000`, migrasi `130900`, ADR-017). Tanpa penjaga: `delete_account` (idempoten) dan `leave_circle` (dipakai hapus akun) |
| `set_sharing_enabled` tanpa event | RPC menerbitkan event `sharing_changed` (payload `enabled`) hanya bila nilai berubah (migrasi `130900`, ADR-017). Klien menampilkan kalimat dan ikonnya di tab Aktivitas. Layar/teknik pemanggil ditunda | 
| Push SOS ganda untuk anggota di 2 Circle | Trigger `events_after_insert` tidak lagi membuat baris outbox kedua untuk `(penerima, client_id)` yang sama (migrasi `130900`); klien juga mendedup notifikasi lokal berdasarkan `client_id` |
| Hapus akun bisa melewati 30 hari | `purge_deleted_accounts()` dijadwalkan ulang dari harian 03:00 ke tiap jam menit 17 (migrasi `130900`) |
| `pg_cron` gagal senyap | Migrasi `130900` kini GAGAL bila ekstensi tersedia tetapi job tidak lengkap terdaftar (ADR-013); ekstensi tidak tersedia tetap NOTICE |
| Perubahan tempat hanya terlihat setelah muat ulang | Tabel `places` dipublikasikan lewat `supabase_realtime` (migrasi `131000`, ADR-018); klien peta memuat ulang daftar tempat saat ada perubahan |
| `set_sharing_enabled` belum dipakai UI | Sakelar "Berbagi lokasi" di tab Circle (milik sendiri) memanggil RPC; anggota lain melihat perubahan lewat event `sharing_changed`, tab Circle dan Peta memuat ulang otomatis. Masih perlu review GUI |

Daftar lengkap temuan tinjauan lain tidak tercatat di sini; hanya yang tampak di komentar migrasi yang saya cantumkan. Untuk temuan lain minta ringkasan dari sesi utama.

### Ditunda (belum diperbaiki)
| Temuan | Dampak | Catatan |
|--------|--------|---------|
| DELETE Realtime tanpa filter Circle | DELETE `member_status`, `events`, dan `places` membawa primary key ke semua pelanggan kanal (tidak difilter RLS). Isinya hanya kunci (UUID acak untuk tempat); pengguna lain tidak tahu tempat yang dihapus, tetapi menandakan ada penghapusan | Risikonya diterima dan didokumentasikan (ADR-016, ADR-018). Kurasi penuh tidak mungkin tanpa kanal privat atau filter DELETE yang belum tersedia |
| Realtime lambat tersambung sekali di tes | Satu kali tes integrasi menunggu koneksi Realtime lebih lama dari biasa lalu lulus. Penyebab belum diselidiki | Pantau; bila berulang, tambah penantian status `subscribed` di tes |

### Ke Supabase live (checklist deploy pertama)
1. **Commit dulu** — migrasi `130700`–`131000` dan seluruh perubahan klien masih di working tree; jangan push database dari mesin tanpa berkas ini tersingkron lewat git.
2. Buat proyek di supabase.com; ambil URL dan **anon key** (jangan service_role).
3. `npx supabase db push --db-url <DATABASE_URL>` — menyalin seluruh migrasi, RLS, RPC, dan trigger. Setelan auth TIDAK ikut; atur di Dashboard sebagai padanan `config.toml` lokal.
4. Di Dashboard Authentication: **matikan Anonymous sign-ins** (di lokal masih aktif, temuan Sprint 0A) dan **aktifkan konfirmasi email** sebelum dibuka untuk siapa pun.
5. Setelah push, cek `select jobname, schedule from cron.job;`: `tether_purge_location_points` (tiap jam), `tether_purge_deleted_accounts` (tiap jam menit 17), `tether_purge_events` (03:10 UTC) harus lengkap — bila tidak, migrasi tadi seharusnya sudah gagal eksplisit (ADR-013). Cek juga `cron.job_run_details` setelah satu jam untuk memastikan eksekusi jalan.
6. Jalankan klien dengan `--dart-define=SUPABASE_URL=<url live> --dart-define=SUPABASE_ANON_KEY=<anon live>`; nilai define ter-kompilasi, jadi ganti tujuan berarti jalankan ulang `flutter run`, bukan cukup memindahkan binary.
7. Fungsi yang belum berlaku di live: pengirim push (FCM, ADR-011); perilaku `banned_until` dan pencabutan sesi di versi cloud (hanya teruji di Supabase lokal); performa `shares_active_circle` per baris.

### Ditunda dari Sprint 0A dan statusnya sekarang
| Temuan | Status |
|--------|--------|
| Pendaftaran anonim aktif dan RPC tanpa pembatas laju | Pembatas laju sudah ada untuk gabung, check-in, SOS. Pendaftaran anonim MASIH aktif di `supabase/config.toml` (`enable_anonymous_sign_ins = true`) dan konfirmasi email mati. **Jangan** `config push` atau `db push` ke cloud sebelum ditinjau |
| Partisi `location_points` | Belum dikerjakan. Purge memakai indeks `recorded_at` |
| Tes pgTAP `04_purge` bergantung pada tabel bersih | Tidak saya periksa ulang |

### Catatan tambahan dari pembacaan migrasi dan kode
- Pengaturan notifikasi per fitur (tiba/tiba-tiba pergi, check-in, perubahan anggota) kini punya halaman di Profil, membaca dan menulis `notification_settings` lewat RPC; SOS selalu memakai preferensi `sos`. SOS tidak bisa dimatikan dari halaman itu dan halaman menjelaskannya. Pantau lewat review GUI.
- Keluar dari Circle menerbitkan `member_left` yang terlihat anggota lain, dan tidak menghapus `member_status`. Itu bertentangan dengan gagasan "keluar tanpa sepengetahuan" di model ancaman 05. Putuskan bila fitur keselamatan itu diinginkan.
- `push_outbox` terus bertambah tanpa pengirim; hanya dibersihkan lewat cascade dari `events` (90 hari).
- Jendela baca SOS 48 jam dihitung dari `created_at` (waktu server), bukan `triggered_at`. SOS yang tertunda dikirim terlambat tetap terbaca 48 jam sejak tiba.
- Lokasi SOS memakai `geolocator` langsung, tidak lewat sumber simulasi. Di Linux pengambilan lokasi bisa gagal ("Lokasi tidak tersedia") dan SOS tidak terkirim. Belum diverifikasi di layar. Lihat [10-panduan-uji.md](../10-panduan-uji.md).
- Instance kedua aplikasi Linux lewat `XDG_DATA_HOME=/tmp/tether-b` belum pernah diuji sungguhan.

## Yang BELUM terbukti
- Seluruh perilaku Android: build APK, izin lokasi (foreground, background, notifikasi), foreground service, notifikasi persisten, onboarding hemat baterai Redmi. Lisensi Android SDK belum disetujui (`flutter doctor --android-licenses`).
- Pelacakan background, GPS asli, akurasi, dan konsumsi baterai (Sprint 0B, gerbang Sprint 3 di rencana 09).
- FCM: tidak ada proyek Firebase, tidak ada pengirim dari `push_outbox`, tidak ada pendaftaran token nyata. Notifikasi saat ini hanya lokal dan hanya saat aplikasi terbuka.
- Notifikasi lokal di Android (kanal, izin, penahanan oleh pabrikan).
- TalkBack dan jalur SOS aksesibel di pembaca layar sungguhan. Hanya ada tes widget.
- SOS offline di jaringan nyata dan saat aplikasi dimatikan OS. Di Linux hanya dengan mematikan Supabase lokal.
- Tampilan visual di layar, mode gelap, kontras tinggi, dan font sistem terbesar: belum diverifikasi oleh saya.
- `pg_cron` di proyek cloud, performa di volume nyata, pencadangan.
- Google sign-in, verifikasi email, foto profil (tidak dikerjakan).
- Tinjauan hukum dan dokumen kebijakan privasi.

## Cara menjalankan sendiri
Lihat [10-panduan-uji.md](../10-panduan-uji.md) untuk checklist uji manual. Perintah tes:
```
flutter analyze
flutter test
npx supabase test db
set -a; eval "$(npx supabase status -o env)"; set +a
SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY flutter test test/integration
flutter build linux --debug
```
Batas pendaftaran anonim lokal (30 per jam per IP): jangan menjalankan tes integrasi berulang terlalu sering.

## Checklist review untuk Anda
- [ ] Baca ADR-009 sampai ADR-016 di 03 dan setujui atau minta revisi, terutama ADR-012 (SOS tetap berlaku saat dijeda dan membawa koordinat) dan ADR-011 (notifikasi lokal dulu).
- [ ] Putuskan nasib temuan yang ditunda di atas (terutama akun terhapus dengan JWT berlaku, dan alarm `pg_cron`).
- [ ] Jalankan [10-panduan-uji.md](../10-panduan-uji.md) bagian Linux dan catat revisi di tempat yang disediakan.
- [ ] Putuskan pemecahan commit per sprint dan tag.
- [ ] Siapkan prasyarat pemilik (bagian akhir 10) agar Sprint 0B dan FCM bisa jalan.
