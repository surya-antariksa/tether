# 08. Design System: Gaya Apple untuk Tether

Versi: Draf 1 | Tanggal: 2026-11-04

Dokumen ini menerjemahkan Apple Human Interface Guidelines (HIG) menjadi aturan desain Tether. Tujuannya: aplikasi terasa seperti aplikasi Apple (jernih, tenang, hierarki jelas, mengikuti sistem) tetapi tetap punya identitas sendiri lewat warna tint dan istilah.

## Status verifikasi
- Kutipan dan angka bertanda **(HIG)** diambil dari halaman HIG resmi pada 2026-11-04 lewat endpoint datanya. Bagian halaman yang panjang hanya terbaca lewat ringkasan model, ditandai **(HIG, ringkasan)**.
- Item **(keputusan Tether)** adalah pilihan kami, bukan aturan Apple.
- Item **[Belum diverifikasi]** perlu dicek sebelum dipakai.
- Halaman HIG tentang navigation bars (sekarang bernama Toolbars), haptics, dan requesting-permissions tidak berhasil diambil. Isinya tidak dipakai di sini.
- HIG tidak punya panduan khusus untuk aplikasi berbagi lokasi, tombol SOS, atau panel anggota di atas peta. Bagian itu adalah penerapan prinsip umum, bukan aturan Apple.

---

## 1. Prinsip desain

1. **Konten dulu.** Peta adalah panggung. Kontrol melayang di atasnya dan tidak menutupi.
2. **Ikuti sistem.** Pakai warna semantik, ukuran teks dinamis, mode gelap otomatis. Tidak ada pengaturan tampilan khusus di dalam aplikasi: "Avoid offering an app-specific appearance setting" **(HIG, Dark Mode)**.
3. **Warna sedikit, bermakna.** Tint untuk aksi utama, merah hanya untuk bahaya. "Apply color sparingly to the Liquid Glass material" **(HIG, Color, ringkasan)**.
4. **Jelas dalam hitungan detik.** Anggota keluarga membuka aplikasi untuk satu pertanyaan: "Dia di mana, aman?" Jawabannya harus terlihat tanpa mengetuk.
5. **Hormati privasi di UI.** Status "dijeda" dan alasan izin ditampilkan jujur, tidak disembunyikan.

---

## 2. Liquid Glass (iOS 26 ke atas)

Apple memperkenalkan Liquid Glass pada iOS 26. Aturan dari HIG Materials **(HIG)**:
- Liquid Glass adalah lapisan fungsional untuk kontrol dan navigasi (tab bar, sidebar) yang melayang di atas lapisan konten.
- **"Don't use Liquid Glass in the content layer."** Konten memakai material standar.
- Pakai seperlunya. Batasi pada elemen fungsional terpenting.
- Varian *regular* untuk komponen dengan banyak teks (alert, popover). Varian *clear* hanya di atas latar visual kaya (misalnya foto atau video). Jika latar terang, pertimbangkan lapisan peredup gelap 35%.
- Material iOS standar: ultra-thin, thin, regular (bawaan), thick.

Tab bar di iOS melayang di atas konten dan item-nya berada di atas latar Liquid Glass. Tab bar boleh diminimalkan saat menggulir bila ada aksesori yang menempel **(HIG, Tab bars)**.

### Penerapan di Tether
| Lapisan | Elemen | Material |
|---------|--------|----------|
| Konten | Peta, daftar anggota, kartu tempat, riwayat | Opak atau material standar |
| Fungsional | Tab bar, tombol melayang di peta (pusatkan lokasi saya, layer), toolbar | Glass |
| Peringatan | Alert, action sheet | Bawaan sistem (regular) |

Peta penuh layar adalah latar visual kaya, jadi tombol melayang di atas peta cocok memakai glass.

### Realita di Flutter
- Widget Cupertino bawaan Flutter meniru iOS dan **tidak otomatis menjadi Liquid Glass**. Saya mencari kata "liquid" di folder `cupertino` pada Flutter 3.44.0 lokal dan tidak menemukannya.
- Ada paket pihak ketiga dengan dua pendekatan **[Belum diverifikasi, cek pemeliharaan, versi Flutter yang didukung, dan lisensi]**:
  - *Jembatan native* (misalnya `cupertino_native_ui`): memakai komponen SwiftUI/UIKit asli, paling mirip, tetapi butuh Xcode terbaru dan platform view.
  - *Pendekatan Dart murni* (misalnya `cupertino_liquid_glass`): hanya aproksimasi visual.
- **Keputusan Tether (usulan, ADR-009):** MVP memakai widget Cupertino standar dan efek kaca buatan sendiri (`BackdropFilter` ditambah warna tint tipis) hanya pada beberapa kontrol melayang. Evaluasi paket native setelah spike lokasi. Tidak menjadikan Liquid Glass sebagai syarat rilis.
- Liquid Glass tidak ada di Android. Di sana efek kaca cukup berupa blur tipis atau permukaan solid.

---

## 3. Warna

### 3.1 Aturan Apple
- Pakai warna sistem dan semantik. **"Avoid hard-coding system color values"** karena nilainya bisa berubah antarrilis **(HIG, Color)**.
- Latar iOS punya tiga tingkat: primary (seluruh layar), secondary (pengelompokan di dalamnya), tertiary (pengelompokan di dalam secondary). Ada dua set: *system* dan *grouped*. Grouped dipakai untuk tampilan tabel berkelompok **(HIG, Color)**.
- Warna teks bertingkat: label, secondaryLabel, tertiaryLabel, quaternaryLabel, placeholderText, separator, link **(HIG, Color)**.
- Warna kustom harus punya varian terang, gelap, dan opsi kontras tinggi untuk masing-masing **(HIG, Color)**.
- Di mode gelap, latar punya tingkat *base* (lebih gelap, terasa mundur) dan *elevated* (lebih terang, terasa maju) untuk sheet dan popover **(HIG, Dark Mode)**.
- Kontras minimum 4,5:1. Untuk teks kecil dengan warna kustom, usahakan 7:1 **(HIG, Dark Mode)**.
- **"Avoid relying solely on color"**: tambahkan label teks atau bentuk glyph **(HIG, Color)**.
- Untuk menonjolkan aksi utama, beri warna pada latar tombol, bukan pada ikon atau teks, dan jangan beri warna pada banyak kontrol sekaligus **(HIG, Color, ringkasan)**.

### 3.2 Token Tether
Latar, teks, dan pemisah **tidak** diberi nilai hex. Di Flutter dipetakan ke warna dinamis bawaan (nama sudah saya cek ada di SDK lokal):

| Token | Flutter |
|-------|---------|
| `bg.base` | `CupertinoColors.systemBackground` |
| `bg.grouped` | `CupertinoColors.systemGroupedBackground` |
| `bg.groupedItem` | `CupertinoColors.secondarySystemGroupedBackground` |
| `text.primary` | `CupertinoColors.label` |
| `text.secondary` | `CupertinoColors.secondaryLabel` |
| `separator` | `CupertinoColors.separator` |
| `danger` | `CupertinoColors.systemRed` (dipakai untuk SOS dan aksi merusak) |

Warna merek (hex karena kustom). Rasio kontras saya hitung sendiri (rumus WCAG), nilainya terhadap putih atau hitam murni, bukan terhadap warna latar sistem yang sebenarnya:

| Token | Terang | Gelap | Terang, kontras tinggi | Gelap, kontras tinggi |
|-------|--------|-------|------------------------|------------------------|
| `tint` (teal) | `#0F766E` (5,5 di putih) | `#2DD4BF` (11,3 di hitam) | `#0B5C55` (7,8 di putih) | `#5EEAD4` (14,2 di hitam) |
| `success` | `#15803D` (5,0 di putih) | `#30D158` (10,4 di hitam) | perlu didefinisikan | perlu didefinisikan |
| `warning` (amber) | `#B45309` (5,0 di putih) | `#FBBF24` (12,6 di hitam) | perlu didefinisikan | perlu didefinisikan |

Catatan:
- Ini merevisi palet awal: latar kini mengikuti warna semantik sistem, bukan `#F8FAFC` dan `#0B1220`. `success` terang `#16A34A` diganti `#15803D` karena kontras putih di atasnya hanya 3,3. `warning` untuk teks di latar terang memakai `#B45309`, karena `#F59E0B` tidak cukup kontras sebagai teks di atas putih (belum saya hitung, hanya perkiraan, hitung ulang sebelum dipakai).
- Teks putih di atas merah `#DC2626` hanya 4,8. Karena SOS memakai `systemRed`, kontras aktualnya bergantung pada nilai sistem dan perlu dicek di perangkat.
- Warna penanda anggota (`profiles.color`): sekitar 8 warna, selalu disertai foto atau inisial.
- Semua pasangan warna harus diuji dengan Increase Contrast aktif dan di mode gelap.

---

## 4. Tipografi

### 4.1 Aturan Apple
- iOS: ukuran bawaan **17 pt**, minimum **11 pt** **(HIG, Typography)**.
- Hindari bobot Ultralight, Thin, Light. Pilih Regular, Medium, Semibold, Bold **(HIG, Typography)**.
- Gunakan gaya teks bawaan dan pastikan tata letak beradaptasi ke semua ukuran font. Kurangi pemotongan teks dan jumlah kolom saat font membesar **(HIG, Typography)**.
- Beri opsi memperbesar teks minimal 200% **(HIG, Accessibility)**.
- Untuk tiga baris teks atau lebih, hindari leading yang rapat **(HIG, Typography)**.

### 4.2 Gaya teks (ukuran/leading dalam pt pada ukuran Large, bawaan)
Tabel ini berasal dari ringkasan model dan cocok dengan pengetahuan umum saya, tetapi **belum diverifikasi kata per kata**. Tabel untuk ukuran xSmall dan Small yang terbaca verbatim konsisten dengan nilai ini.

| Gaya | Ukuran/Leading | Bobot reguler | Bobot tegas |
|------|----------------|---------------|-------------|
| Large Title | 34/41 | Regular | Bold |
| Title 1 | 28/34 | Regular | Bold |
| Title 2 | 22/28 | Regular | Bold |
| Title 3 | 20/25 | Regular | Semibold |
| Headline | 17/22 | Semibold | Semibold |
| Body | 17/22 | Regular | Semibold |
| Callout | 16/21 | Regular | Semibold |
| Subhead | 15/20 | Regular | Semibold |
| Footnote | 13/18 | Regular | Semibold |
| Caption 1 | 12/16 | Regular | Semibold |
| Caption 2 | 11/13 | Regular | Semibold |

### 4.3 Font di Flutter
- Di iOS, widget Cupertino memakai font sistem (San Francisco) otomatis. Jangan menyematkan font sendiri di iOS.
- Di Android, font SF **tidak boleh disertakan** karena lisensinya membatasi penggunaan pada platform Apple **[Belum diverifikasi, baca lisensi di developer.apple.com/fonts]**. Untuk Android pakai font yang mirip dan berlisensi bebas, misalnya **Inter** **(keputusan Tether, usulan)**.
- Skala teks mengikuti `MediaQuery.textScaler`. Uji sampai ukuran aksesibilitas terbesar.

Pemetaan penggunaan di Tether:
| Elemen | Gaya |
|--------|------|
| Judul layar utama | Large Title |
| Nama anggota di daftar | Headline atau Body |
| Waktu pembaruan terakhir | Footnote |
| Label tab bar | Caption 2 sampai Caption 1 (ditentukan sistem) |
| Teks tombol | Body semibold |

---

## 5. Tata letak, jarak, dan ukuran sentuh

### 5.1 Aturan Apple
- Hormati *safe area* agar tidak tertutup Dynamic Island, indikator home, dan bar sistem **(HIG, Layout)**.
- Gunakan layout guides untuk margin standar dan batasi lebar teks agar nyaman dibaca **(HIG, Layout)**.
- Tentukan tata letak berdasarkan *size class* (compact atau regular), bukan jenis perangkat atau orientasi **(HIG, Layout)**.
- Kelompokkan elemen terkait dengan ruang kosong, bentuk wadah, atau garis pemisah **(HIG, Layout)**.
- Area sentuh minimal **44x44 pt**, minimum mutlak 28x28 pt **(HIG, Buttons dan Accessibility)**.
- Beri jarak sekitar 12 pt di sekitar elemen yang punya bezel, sekitar 24 pt untuk elemen tanpa bezel **(HIG, Accessibility)**.
- Halaman Layout tidak memuat angka margin iPhone.

### 5.2 Keputusan Tether
- Grid 8 pt. Margin layar 16 pt. Radius kartu 12 sampai 16 pt. Semua **(keputusan Tether)**, bukan angka dari Apple.
- Marker di peta: area sentuh minimal 44x44 pt walaupun gambarnya lebih kecil.
- Tombol melayang di peta memakai jarak 12 pt antar tombol.

---

## 6. Komponen dan penerapan di layar Tether

### 6.1 Navigasi: tab bar
Aturan **(HIG, Tab bars)**: untuk navigasi, bukan aksi. Tetap terlihat saat berpindah bagian. Jangan menonaktifkan atau menyembunyikan tab walau kontennya kosong, jelaskan alasannya. Label satu kata. Utamakan ikon varian *fill*. Hindari tab overflow ("More"). Lencana (badge) hanya untuk informasi penting. HIG tidak menetapkan jumlah maksimum tab.

Usulan 4 tab **(keputusan Tether)**:
| Tab | Isi | Ikon |
|-----|-----|------|
| Peta | Peta dan panel anggota | peta, fill |
| Circle | Anggota, undangan, tempat | grup orang, fill |
| Aktivitas | Event tiba, pergi, check-in, SOS | lonceng atau jam, fill |
| Profil | Akun, privasi, pengaturan | orang, fill |

Lencana merah di tab Aktivitas hanya untuk SOS atau peringatan penting.

### 6.2 Layar Peta
```
┌───────────────────────────┐
│  (status bar)             │
│                      [ ◎ ]│  ← tombol melayang (glass): pusatkan lokasi saya
│                      [ ⧉ ]│  ← layer peta
│      peta penuh layar     │
│    (marker anggota)       │
│ ┌───────────────────────┐ │
│ │ ━━ (grabber)          │ │  ← sheet nonmodal, detent medium dan large
│ │ Keluarga · 3 anggota  │ │
│ │ ● Ibu  Rumah   2 mnt  │ │
│ │ ● Raka Sekolah 5 mnt  │ │
│ └───────────────────────┘ │
│  Peta  Circle Aktiv. Profil│  ← tab bar (glass)
└───────────────────────────┘
```
Panduan terkait:
- **Sheet** **(HIG, Sheets)**: sheet iOS bisa modal atau *nonmodal*. Nonmodal membiarkan orang tetap memakai tampilan induk, cocok untuk panel anggota di atas peta. Detent sistem: *large* (penuh) dan *medium* (sekitar setengah). "Consider supporting the medium detent" di iPhone. Sertakan **grabber**. Dukung geser untuk menutup dan sediakan tombol untuk aksi yang sama.
- **Peta** **(HIG, Maps)**: buat peta interaktif. Pakai klaster untuk titik yang berdekatan. Beri kontras pada kontrol kustom lewat garis tipis atau bayangan ringan. Jaga lokasi tetap terlihat saat kartu tempat ditampilkan.
- Logo Apple dan tautan hukum yang diatur HIG berlaku untuk MapKit. Jika memakai OSM atau penyedia lain, **pasang atribusi sesuai syarat penyedia** dan letakkan di posisi serupa (10 pt di atas posisi istirahat terendah kartu) sebagai praktik yang baik **(keputusan Tether)**.
- Panel anggota adalah bagian konten. Gunakan material standar atau opak, bukan Liquid Glass.

Baris anggota menampilkan: foto atau inisial, nama, nama tempat atau "Bergerak", waktu pembaruan terakhir, level baterai. Status mengikuti state machine di [07](07-uml-diagrams.md): dijeda dan basi memakai teks, bukan hanya warna.

### 6.3 Tombol
Aturan **(HIG, Buttons)**:
- Area sentuh minimal 44x44 pt. Selalu sediakan *press state* untuk tombol kustom.
- Satu atau dua tombol menonjol per layar. Bedakan pilihan utama dengan **gaya**, bukan ukuran.
- Peran: normal, primary, cancel, destructive. Tombol destruktif memakai merah sistem.
- **Jangan beri peran primary pada tombol destruktif**, walau itu pilihan yang paling mungkin.
- Aksi yang tidak selesai seketika menampilkan indikator aktivitas.

Penerapan: tombol primer berwarna `tint` di latar tombol (teks putih). "Keluar dari Circle" dan "Hapus akun" memakai gaya destruktif.

### 6.4 Tombol SOS
HIG tidak punya panduan khusus SOS, jadi ini keputusan Tether berdasarkan prinsip umum:
- Merah sistem. Posisi mudah dijangkau jempol tetapi tidak di tempat yang mudah tersentuh tanpa sengaja.
- Tahan 3 detik, lalu hitung mundur 5 detik yang bisa dibatalkan (lihat 01-PRD F9).
- **Aksesibilitas:** HIG meminta alternatif tombol untuk gestur geser. Untuk gestur tahan, sediakan jalur setara bagi VoiceOver dan Switch Control (misalnya aksi aksesibilitas "Kirim SOS" yang tetap melewati hitung mundur).
- HIG Accessibility menyarankan meminimalkan elemen berbatas waktu. Hitung mundur di sini adalah jendela pembatalan, bukan batas yang harus dikejar pengguna. Pastikan pembatalan satu ketukan jelas, dan pertimbangkan pengaturan untuk durasi yang lebih panjang.
- Sertakan umpan balik haptic dan teks, bukan hanya warna. (Panduan haptics tidak berhasil diambil, jadi pola haptic ditentukan saat implementasi **[Belum diverifikasi]**.)

### 6.5 Alert dan action sheet
Aturan **(HIG, Alerts)**:
- Pakai alert dengan hemat. Maksimal tiga tombol. Jangan tampilkan alert saat aplikasi dibuka.
- Hindari alert untuk aksi umum yang bisa dibatalkan. Untuk aksi merusak yang tidak bisa dibatalkan, alert penting.
- Judul tombol satu atau dua kata, spesifik ("Hapus", "Keluar"). Gunakan "Batal" untuk membatalkan. Hindari "OK" kecuali murni informasi.
- Tombol yang paling mungkin dipilih di sisi kanan (trailing), Batal biasanya di kiri (leading). Jangan jadikan Batal tombol bawaan pada alert destruktif.
- Gunakan **action sheet**, bukan alert, untuk memberi pilihan terkait aksi yang disengaja.

Penerapan:
| Situasi | Komponen |
|---------|----------|
| Pilih durasi jeda (15 menit, 1 jam, sampai dihidupkan) | Action sheet |
| Hapus akun | Alert destruktif, dengan konfirmasi ulang |
| Keluar Circle | Alert destruktif |
| Anggota dikeluarkan admin | Alert informasi |

### 6.6 Daftar dan pengaturan
- Pengaturan memakai daftar berkelompok (grouped) dengan warna `bg.grouped` dan `bg.groupedItem`.
- Gunakan indikator disclosure untuk masuk ke tingkat berikutnya. Info button hanya untuk informasi tambahan **(HIG, Lists and tables)**.
- Gaya wajib iOS. Di Android tetap memakai gaya sama untuk konsistensi merek.

### 6.7 Ikon (SF Symbols)
- Tab bar memakai varian *fill*, toolbar memakai varian *outline* **(HIG, SF Symbols)**.
- Animasi simbol secukupnya. Ikon bermakna ikut membesar saat font membesar **(HIG, Typography)**.
- **SF Symbols hanya untuk platform Apple**, jadi di Flutter pakai paket `cupertino_icons` (sudah ada di `pubspec.yaml`) yang berbentuk mirip. Cek apakah semua ikon yang dibutuhkan tersedia, dan ikon khusus dibuat sendiri dalam gaya yang sama. Lisensi SF Symbols **[Belum diverifikasi]**.

### 6.8 Gerak dan animasi
Aturan **(HIG, Motion dan Accessibility)**:
- Tambahkan gerak dengan tujuan, bukan sekadar hiasan. Hindari gerak pada interaksi yang sering terjadi.
- Jadikan gerak opsional dan hormati **Reduce Motion** (kurangi zoom, scaling, dan gerak berulang otomatis).
- Jangan buat pengguna menunggu animasi selesai. Gerak bisa dibatalkan.

Penerapan: marker anggota berpindah halus, tanpa animasi berulang. Transisi sheet memakai bawaan.

---

## 7. Izin dan onboarding (menyentuh PRD F13)

Aturan **(HIG, Privacy dan Onboarding)**:
- Minta izin hanya bila aplikasi jelas membutuhkannya. Idealnya tunggu sampai pengguna memakai fitur yang membutuhkan izin itu. Hindari meminta saat peluncuran **kecuali** data tersebut wajib agar aplikasi berfungsi. Bila wajib, izin boleh diintegrasikan ke onboarding.
- Pada layar penjelasan sebelum dialog sistem: **hanya satu tombol**, jelas bahwa tombol itu membuka dialog sistem, dan beri label "Lanjut" atau "Berikutnya", **bukan "Izinkan"**. Jangan tambahkan opsi menutup atau membatalkan.
- Jangan mendahului dialog izin pelacakan dengan layar yang menyesatkan.
- Teks alasan (purpose string): satu kalimat lengkap, spesifik, huruf besar hanya di awal, tanpa kalimat pasif, diakhiri titik.
- Onboarding: cepat, menyenangkan, opsional. Ajarkan lewat interaksi. Tunda penyiapan yang tidak penting. Beri pengaturan bawaan yang masuk akal.
- Pengguna bisa mengubah pilihan di Pengaturan > Privasi.

### Dampak ke dokumen lain
- **Diagram activity onboarding di [07](07-uml-diagrams.md) bagian 2.1** memiliki cabang "Pengguna setuju lanjut? Tidak". Itu bertentangan dengan aturan layar penjelasan satu tombol di iOS. Perlu direvisi: di iOS, layar penjelasan hanya punya "Lanjut", dan penolakan terjadi di dialog sistem. Sudah diperbarui: diagram itu kini memakai satu tombol "Lanjut" sebelum dialog sistem, dan penolakan terjadi di dialog sistem.
- Lokasi adalah inti aplikasi, jadi meminta izin saat onboarding dapat dibenarkan, tetapi alasannya harus tertulis di PRD.
- Rencana meminta izin "selalu": HIG yang berhasil saya ambil tidak membahas alur peningkatan dari "saat dipakai" ke "selalu" **[Belum diverifikasi]**. Pelajari perilaku iOS terbaru saat spike dan sebelum membuat layar penjelasannya.

### Contoh teks alasan (draf, bahasa Indonesia)
- Lokasi saat dipakai: "Tether menampilkan posisi Anda di peta Circle keluarga."
- Lokasi selalu: "Tether membagikan lokasi Anda ke Circle keluarga saat aplikasi ditutup, supaya keluarga tahu Anda sampai dengan selamat."
- Notifikasi: "Tether mengirim pemberitahuan saat anggota keluarga tiba, pergi, atau mengirim SOS."

Nama kunci Info.plist yang biasa dipakai: `NSLocationWhenInUseUsageDescription` dan `NSLocationAlwaysAndWhenInUseUsageDescription` **[Belum diverifikasi ke dokumentasi terbaru]**.

---

## 8. Aksesibilitas (ringkas)
- Teks dapat diperbesar minimal 200%. Tata letak tidak boleh rusak.
- Kontras minimal 4,5:1 (teks sampai 17 pt), 3:1 untuk teks 18 pt ke atas atau tebal **(HIG, Accessibility)**. Usahakan 7:1 untuk teks kecil.
- Area sentuh 44x44 pt.
- Jangan hanya mengandalkan warna.
- Dukung VoiceOver: setiap marker, tombol, dan status punya label yang bermakna.
- Dukung Reduce Motion dan Increase Contrast.
- Konfirmasi dua kali untuk tindakan yang sulit dipulihkan, seperti hapus akun **(HIG, Accessibility, Assistive Access)**.

---

## 9. Satu desain untuk dua platform

Pengguna Android kemungkinan besar mayoritas di Indonesia **[Belum diverifikasi]**. Pilihan:

| Opsi | Keterangan |
|------|------------|
| A. Satu desain gaya Apple di Android dan iOS (usulan) | Identitas konsisten, satu basis UI. Perilaku sistem tetap mengikuti platform: tombol kembali Android, gestur kembali prediktif, izin, dan notifikasi |
| B. Adaptif: Cupertino di iOS, Material di Android | Terasa asli di tiap platform, biaya desain dan uji hampir dua kali lipat |

**Keputusan: opsi A** (dipilih pengguna pada 2026-11-04). Efek Liquid Glass hanya di iOS 26 ke atas, dan di tempat lain memakai fallback solid atau blur tipis.

---

## 10. Hal yang perlu dilakukan
- [x] Putuskan opsi A atau B (bagian 9): opsi A.
- [ ] Putuskan ADR-009 (Liquid Glass) setelah spike, dan catat di [03](03-architecture.md).
- [ ] Definisikan varian kontras tinggi untuk `success` dan `warning`, serta hitung ulang kontras `warning` terang.
- [ ] Cek ketersediaan ikon `cupertino_icons` untuk semua kebutuhan.
- [ ] Baca ulang lisensi font SF dan SF Symbols.
- [ ] Buat wireframe di Figma dengan Apple Design Resources (kit UI resmi di developer.apple.com/design/resources).
- [ ] Implementasikan tema di Flutter (`CupertinoThemeData` dengan token di atas).
- [ ] Uji tampilan: mode terang, gelap, Increase Contrast, teks terbesar, Reduce Motion.

---

## Sumber
- [Human Interface Guidelines, indeks](https://developer.apple.com/design/human-interface-guidelines/)
- Halaman yang diambil: [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Color](https://developer.apple.com/design/human-interface-guidelines/color), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars), [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [Maps](https://developer.apple.com/design/human-interface-guidelines/maps), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding), [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts)
- [Apple Fonts](https://developer.apple.com/fonts/) dan [Apple Design Resources](https://developer.apple.com/design/resources/)
- [WWDC25 sesi 323, Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/323/)
- Paket Flutter untuk Liquid Glass (belum dievaluasi): [cupertino_native_ui](https://pub.dev/packages/cupertino_native_ui), [cupertino_liquid_glass](https://pub.dev/packages/cupertino_liquid_glass)
