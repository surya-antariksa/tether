# 10. Redesain: dark cyan glass

Status (2026-11-06): DIKERJAKAN. Menggantikan keputusan desain gaya Apple (docs/08).

Keputusan user: (1) tema tetap ikut sistem (gelap = palet mockup, terang = turunan bersih tanpa cahaya dan gradasi), (2) font dibundel (Plus Jakarta Sans, Inter) di `assets/fonts/`, (3) ikon Material Symbols (`material_symbols_icons`).

## 0. Patokan desain (sumber kebenaran)

Paket desain lengkap dari user (22 layar, kode HTML dan tangkapan layar) ada di [design/ui/](design/ui/). Spesifikasi tertulis: [design/ui/tether_glass_obsidian/DESIGN.md](design/ui/tether_glass_obsidian/DESIGN.md). Tiap layar: `design/ui/<nama>/code.html` dan `screen.png`. Bila ringkasan di dokumen ini berbeda dengan mockup, mockup yang benar.

| Layar | Folder |
|---|---|
| Peta | tether_peta_real_time |
| Aktivitas | tether_aktivitas_keluarga |
| Circle | tether_circle_anggota |
| Profil | tether_profil_pengaturan |
| Masuk, daftar | tether_masuk_login_aktif, tether_masuk_registrasi |
| Lupa sandi, sandi baru, berhasil | tether_lupa_kata_sandi_modal, tether_kata_sandi_baru, tether_kata_sandi_berhasil_modal |
| Undang anggota | tether_modal_undang_anggota_circle |
| Edit profil dan penanda | tether_modal_edit_profil_penanda |
| SOS | tether_modal_keselamatan_sos, tether_modal_hitung_mundur_sos |
| Riwayat, rute | tether_riwayat_lokasi, tether_detail_titik_lokasi, tether_playback_rute_animasi, tether_perbandingan_rute_perjalanan, tether_modal_bagikan_rute |
| Tempat | tether_kelola_tempat_empty_state, tether_modal_tambah_tempat |
| Notifikasi | tether_pengaturan_notifikasi |
| Hapus akun | tether_dialog_konfirmasi_hapus |

Cara melihat HTML: buka di browser (butuh internet untuk Tailwind CDN dan Google Fonts).

## Status implementasi
- Selesai (diverifikasi lewat render gelap dan terang): tab Peta (HUD, sheet anggota, marker), Aktivitas, Circle, Profil, halaman masuk/daftar (ikut sistem), tempat (daftar dan kosong), riwayat, notifikasi, lembar Keselamatan, undang anggota.
- Ikut token tapi belum dibandingkan piksel demi piksel dengan mockup: sheet lupa sandi, edit profil, bagikan rute, dialog hitung mundur SOS, pemilih lokasi tempat, edit tempat, hapus akun, onboarding lokasi.
- Belum ada fiturnya di aplikasi, jadi tidak didesain ulang: kata sandi baru dan berhasil, playback rute, perbandingan rute, detail titik lokasi.
- Ubin peta gelap: filter warna di klien pada ubin OSM (`map_theme.dart`), aktif otomatis di mode gelap di peta utama, riwayat, dan pemilih tempat. Diverifikasi pada satu ubin nyata, belum di layar Peta penuh.
- Tidak dibuat karena tidak ada datanya: lencana "Admin Circle", "Terenkripsi E2E", "Terverifikasi", "Terkoneksi", "Tandai Dibaca", chip lokasi dan baterai di kartu aktivitas.

## 1. Token desain (disalin dari tailwind-config mockup)

Mockup hanya mode gelap (`<html class="dark">`).

### Warna
| Token mockup | Hex | Pemakaian utama |
|---|---|---|
| background / surface / surface-dim | `#0F131C` | latar halaman, bar atas (alpha 0.80) |
| surface-container-lowest | `#0A0E16` | latar luar, tab bar (alpha 0.85), sheet peta (alpha 0.90), pill HUD (alpha 0.80) |
| surface-container-low | `#181C24` | isi avatar marker |
| surface-container | `#1C2028` | kartu anggota (alpha 0.70 atau 0.50), kartu Circle (alpha 0.70) |
| surface-container-high | `#262A33` | badge, pill filter tak aktif (alpha 0.60) |
| surface-container-highest / surface-variant | `#31353E` | ikon geofence, hover |
| primary-container (AKSEN CYAN) | `#00F2FE` | tab aktif, tombol utama, tautan, ring marker "Kamu" |
| surface-tint | `#00DCE6` | ujung gradasi tombol |
| primary | `#E0FDFF` | judul halaman (Aktivitas, Circle) |
| on-primary | `#00373A` | teks di atas tombol cyan |
| on-primary-container | `#006A70` | teks di atas pill filter aktif; ujung gradasi marker |
| secondary (HIJAU) | `#4EDEA3` | status aman, online, baterai baik |
| secondary-container | `#00A572` | latar ikon hijau (alpha 0.20) |
| tertiary-fixed-dim | `#4CD7F6` | ikon geofence tiba |
| on-surface | `#DFE2EE` | teks utama |
| on-surface-variant | `#B9CACB` | teks sekunder |
| outline | `#849495` | teks tersier, waktu, ikon pasif |
| outline-variant | `#3A494B` | garis, handle sheet (alpha 0.60), border kartu (alpha 0.20 sampai 0.40) |
| error | `#FFB4AB` | teks kesalahan |
| error-container | `#93000A` | latar kesalahan |

Putih transparan untuk border kaca: `white/5`, `white/10`, `white/20` (alpha 0.05, 0.10, 0.20).
Latar peta: `#070B12`, kanvas SVG `#0A0F18`. Jalan: `#1F293D`, `#313B52`, `#263147`, `#1D2638`, `#161E2E`. Sungai: `#00DCE6` alpha 0.25.

### Tipografi
Plus Jakarta Sans untuk judul dan isi, Inter untuk label dan caption.
| Token | Font | Ukuran / tinggi baris | Berat | Letter spacing |
|---|---|---|---|---|
| headline-xl | Plus Jakarta Sans | 28 / 34 | 700 | -0.02em |
| headline-lg | Plus Jakarta Sans | 22 / 28 | 700 | -0.015em |
| headline-md | Plus Jakarta Sans | 18 / 24 | 600 | -0.01em |
| body-lg | Plus Jakarta Sans | 16 / 24 | 400 | 0 |
| body-md | Plus Jakarta Sans | 14 / 20 | 400 | 0 |
| body-sm | Plus Jakarta Sans | 12 / 16 | 400 | 0 |
| label-md | Inter | 13 / 16 | 600 | 0.02em |
| label-sm | Inter | 11 / 14 | 500 | 0.04em |
| caption | Inter | 10 / 12 | 500 | 0 |

### Radius dan jarak
- Kartu: `rounded-2xl` = 16 (Tailwind bawaan, bukan 0.75rem dari config). Sheet peta: 28 di sudut atas. Pill dan tombol bulat: penuh. Ikon kartu aktivitas: `rounded-xl` = 12 (config: 0.75rem).
- Jarak config: sm 8, md 12, lg 20, xl 28, xs 4, gutter 16, margin 16.
- Padding halaman 16 (`px-4`). Antar bagian 20 (`gap-5`). Antar kartu feed 10 (`gap-2.5`).

### Efek
- Kaca: blur 20 (`backdrop-blur-xl`), blur 40 untuk sheet peta (`backdrop-blur-2xl`), bar atas blur 12.
- `.glass-card`: latar `rgba(17,24,39,0.72)`, blur 20, border `rgba(255,255,255,0.08)`, hover border `rgba(0,242,254,0.25)`.
- Cahaya cyan: `0 0 28px -4px rgba(0,242,254,0.28)`. Cahaya hijau: `0 0 24px -4px rgba(78,222,163,0.24)`.
- Bayangan sheet peta: `0 -12px 40px rgba(0,0,0,0.7)`.
- Cincin berdenyut marker "Kamu": skala 0.95 ke 1.4, opasitas 0.8 ke 0, 2.5 detik, kurva `cubic-bezier(0.215,0.61,0.355,1)`, berulang.
- Tekan: skala 0.95 (tombol besar) atau 0.90 (tombol ikon bulat) selama 150 ms.
- Atmosfer halaman: dua lingkaran blur di belakang (cyan alpha 0.10 ukuran 384, hijau alpha 0.05 ukuran 256).

### Ikon
Material Symbols Outlined (bobot 400, FILL 0 atau 1). Di Flutter dipetakan ke ikon yang tersedia. Pilihan pustaka (lihat bagian 5, keputusan 2).

## 2. Anatomi layar (ringkasan; detail ada di HTML)

### 2.1 Tab bar bawah (semua layar)
Latar `#0A0E16` alpha 0.85 + blur 20, bayangan besar. 4 item rata sama: Peta (`map`), Circle (`group`), Aktivitas (`notifications`), Profil (`person`). Item aktif: warna cyan `#00F2FE`, ikon FILL 1, bayangan cahaya cyan 8 px alpha 0.4, label tebal. Item pasif: `#B9CACB` opasitas 0.70. Ikon 24, label caption 10.

### 2.2 Peta
- Kanvas peta penuh. Zona akurasi di sekitar "Kamu": lingkaran 176 (cyan alpha 0.05, border alpha 0.20) berisi lingkaran 96 (alpha 0.10, border alpha 0.30).
- HUD kiri atas (16 dari tepi): (a) pill selector circle: titik hijau 8 dengan cahaya, nama circle headline-md tebal, ikon `expand_more` 18, latar `#0A0E16` alpha 0.80, blur, border `white/10`; (b) pill status di bawahnya: titik abu 6, teks label-sm "Lokasi tidak tersedia", latar `#0F131C` alpha 0.85.
- HUD kanan atas: tumpukan vertikal 4 tombol bulat 40, jarak 8, latar `#0F131C` alpha 0.80, blur, border `white/10`, ikon 20: `crop_free` (pusatkan), `near_me` (arah GPS), `location_on` (titik penting), `shield` (keamanan; hover hijau).
- Marker "Kamu": lingkaran 44, cincin gradasi (on-primary-container ke secondary-container), isi `#181C24`, border 2 cyan, huruf awal cyan tebal, cincin berdenyut 56, cahaya cyan 16. Di bawahnya pill "Kamu" (caption tebal cyan, border cyan alpha 0.5).
- Marker anggota lain: lingkaran 36, isi `#1C2028`, border `white/20`, huruf abu. Di bawahnya pill kecil: ikon baterai 11 + persen caption.
- Atribusi OSM: kiri bawah, 230 di atas dasar, teks 9 `#849495`, latar `#0A0E16` alpha 0.80.
- Sheet bawah: latar `#0A0E16` alpha 0.90 + blur 40, sudut atas 28, border atas `white/10`, padding `16, 8, 16, 80` (80 untuk tab bar). Handle 40x4 `outline-variant/60`. Header: judul "keluarga • 2 anggota" headline-md tebal + tombol teks "Jeda" cyan label-md. Daftar kartu anggota jarak 8.
- Kartu anggota: padding 12, radius 16, latar `#1C2028` alpha 0.70 (diri sendiri) atau 0.50, border `white/5`. Avatar 44 bulat dengan titik status 12 di pojok kanan bawah (hijau = aktif, abu = lama). Nama body-md tebal. Untuk diri sendiri tambah "(Kamu)" label-sm cyan. Baris status body-sm abu: "Diam • Diperbarui 25 mnt lalu". Kanan: persen baterai label-sm + ikon 18 (`radio_button_checked` hijau bila bergerak/aktif, `battery_3_bar` abu bila lama).

### 2.3 Aktivitas
- Judul "Aktivitas" headline-xl cyan muda `#E0FDFF`, di sebelahnya badge "Realtime" (caption, latar `#262A33`, border outline-variant/30). Kanan: pill selector circle (ikon `groups` cyan FILL 1, nama, `expand_more`).
- Subjudul body-sm abu: "Pemberitahuan lokasi, status keamanan, dan riwayat lingkaran Anda."
- Kartu "Status Anda" (glass-card, radius 16, padding 14): gradasi dari cyan alpha 0.10 ke transparan ke hijau alpha 0.10. Kiri: ikon `verified_user` 22 di kotak 40 hijau (radius 12, cahaya hijau) + "Status Anda" + "Terakhir diperbarui 1 jam lalu". Kanan: tombol "Kabar Aman" tinggi 40, bulat penuh, gradasi cyan `#00F2FE` ke `#00DCE6`, teks `#00373A` tebal, ikon `check_circle` 16, cahaya cyan.
- Pill filter (gulir horizontal): Semua (aktif: latar cyan, teks `#006A70`, cahaya), Keamanan (`shield`), Tempat (`pin_drop`), Circle (`group`). Pasif: latar `#262A33` alpha 0.60, border outline-variant/30, teks abu. Ikon 14, teks 12.
- Header daftar: "HARI INI" caption huruf kapital, jarak huruf lebar, `#849495`; kanan tautan cyan "Tandai Dibaca".
- Kartu feed (glass-card, radius 16, padding 16, jarak 10): ikon 44 radius 12 di kiri, judul label-md tebal (satu baris, elipsis) + waktu caption `#849495` di kanan, deskripsi body-sm abu.
  - Aman (Gita): ikon `security` hijau, chip lokasi (`location_on` cyan + teks) dan "Baterai 84%" hijau.
  - Aman (Anda): ikon `check_circle` hijau, garis kiri hijau 2, lencana "KAMU", baris "Dilihat oleh ..." dengan `done_all`.
  - Bergabung: ikon `person_add` cyan dengan cahaya cyan, chip "Peran: Anggota" dan "Berbagi Lokasi Aktif".
  - Geofence tiba: ikon `home_pin` `#4CD7F6` di latar `#31353E`, baris "Zona Aman: Rumah Utama" dengan `my_location` dan jam "14.32 WIB".
- Footer: ikon `history` dalam lingkaran 32, "Tidak ada aktivitas yang lebih lama", "Aktivitas dienkripsi dan disimpan selama 30 hari".

### 2.4 Circle (HANYA bagian yang diterima)
- Judul "Circle" headline-xl extrabold `#E0FDFF`, subjudul "Kelola lingkar aman keluarga & perangkat". Kanan: badge "Aktif" dengan titik hijau berdenyut, latar `#1C2028` alpha 0.90.
- Kartu ringkasan (radius 16, padding 20, latar `#1C2028` alpha 0.70, blur 20, border outline-variant/30, bayangan `0 8px 30px rgba(0,0,0,0.45)`), ada dekorasi blur cyan di pojok kanan bawah. ISI KARTU DAN BAGIAN SESUDAHNYA TIDAK DITERIMA.

### 2.5 Profil (HANYA bagian yang diterima)
- Tanpa tombol kembali. Bar atas: "tether" kiri; kanan ikon `settings` dan `more_vert` (20), latar bar `#0F131C` alpha 0.80, blur, garis bawah outline-variant/20. Latar halaman: gradasi radial cyan alpha 0.08 dari tengah atas ke `#0A0E16`.
- Judul "Profil" headline-xl extrabold `#DFE2EE` (BUKAN cyan muda seperti Aktivitas dan Circle), subjudul "Kelola visibilitas, warna penanda, dan privasi akun Anda". Kanan: badge "TERKONEKSI" (titik cyan berdenyut dengan cahaya, caption huruf kapital `#00DCE6`, latar `#262A33` alpha 0.60).
- Jarak antar bagian 24 (`gap-6`).
- Kartu identitas (radius 16, padding 20, latar `#1C2028` alpha 0.70, blur 20, border outline-variant/30), dekorasi blur cyan di pojok kanan atas, isi rata tengah. Avatar 96 dengan cincin cyan bercahaya (terpotong). Isi kartu dan bagian sesudahnya TIDAK DITERIMA.

## 3. Hubungan dengan kode yang ada

Warna terpusat di `lib/app/theme/app_colors.dart` (token: tint, success, warning, danger, background, groupedBackground, groupedItemBackground, textPrimary, textSecondary, separator). Tema di `app_theme.dart`, gaya teks di `app_text_styles.dart`. Ada juga pemakaian langsung `CupertinoColors.*` (secondaryLabel 21, white 21, systemRed 7, systemBackground 6, separator 5, label 5, black 4, dan lainnya) yang harus dialihkan ke token.

Tes yang terpengaruh: `test/app/theme/app_theme_test.dart` mengunci hex teal lama, kontras WCAG empat mode, `onTint` hitam, dan teks iOS 17/22. Harus ditulis ulang.

Berkas yang diubah per tahap (daftar kerja):

| Tahap | Berkas |
|---|---|
| 1 Fondasi | `lib/app/theme/app_colors.dart`, `app_theme.dart`, `app_text_styles.dart`, `lib/features/map/presentation/glass.dart`, `lib/app/app_shell.dart`, `lib/features/activity/presentation/activity_tab_icon.dart`, `pubspec.yaml` (font), `test/app/theme/app_theme_test.dart` |
| 2a Peta | `map_tab_page.dart`, `circle_map_view.dart`, `members_sheet.dart`, `member_marker.dart`, `osm_attribution.dart`, `core/widgets/member_avatar.dart` |
| 2b Aktivitas | `activity_tab_page.dart`, `activity_tile.dart` |
| 2c Circle | `circle_tab_page.dart` |
| 3 Sisanya | Profil, auth, sheet dan dialog (invite, SOS, forgot password, edit profil, share route, pause), riwayat, tempat, `core/member_colors.dart` |

## 4. Tahapan

1. **Fondasi** (dikerjakan sesi utama): ganti token, kunci tema gelap, font, kaca, tab bar. Jalankan `flutter analyze` dan tes tema.
2. **Tiga tab** (tiga pelaksana paralel, berkas tidak tumpang tindih). Tiap pelaksana membaca mockup layarnya. Hanya tampilan yang berubah; logika, provider, dan string tidak. Elemen mockup yang belum ada fiturnya dicatat, tidak dibuat diam-diam. Kandidat: filter kategori Aktivitas, "Tandai Dibaca", tombol `crop_free` dan `near_me` di peta, lencana "KAMU" dan "Dilihat oleh", chip "Peran" di feed.
3. **Sisanya**: sisir `CupertinoColors.*` yang tersisa, cek kontras teks di atas latar gelap, samakan sheet dan dialog.
4. **Verifikasi**: `flutter analyze`, tes sempit per fitur lalu penuh, tinjauan diff oleh peninjau, tangkapan layar (emulator atau Linux desktop). Bagian visual yang tidak bisa dijalankan ditandai "belum terverifikasi".
5. **Dokumen**: perbarui `docs/08` dan memori keputusan desain. Tanpa commit kecuali diminta.

## 5. Keputusan (sudah dijawab user)
1. Tema ikut sistem. 2. Font dibundel. 3. Ikon Material Symbols.

## Jalur terpisah: lokasi latar belakang
Tidak termasuk redesain. Kode dasarnya sudah ada (layanan foreground, izin lokasi selalu, panduan hemat baterai), tapi belum terbukti di ponsel. Lihat docs/10-panduan-uji.md dan Sprint 0B.

## 6. Risiko
- Kunci gelap menurunkan aksesibilitas bagi pengguna yang butuh mode terang. Kontras teks tetap dijaga minimal 4,5:1.
- `BackdropFilter` di banyak kartu berat di ponsel murah. Kartu feed memakai warna semi-solid; blur hanya di HUD peta, sheet, dan tab bar.
- Pustaka ikon baru menambah ukuran aplikasi dan dependensi.
- 17 berkas lama yang belum di-commit ada di tree yang sama, jadi diff nanti bercampur.
- Mockup HTML bukan Flutter: ukuran piksel Tailwind dipetakan ke logical pixel Flutter secara langsung, dan hasilnya perlu dicek visual.
