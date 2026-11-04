# 05. Privasi, Keamanan, dan Kepatuhan

Versi: Draf 1. **Ini bukan nasihat hukum.** Tinjau dengan konsultan hukum sebelum rilis publik. Kutipan aturan dan kebijakan store perlu diverifikasi ke versi terbaru **[Belum diverifikasi]**.

## 1. Prinsip
1. Consent eksplisit dan dapat ditarik kapan saja.
2. Transparansi: pengguna selalu tahu siapa yang bisa melihat lokasinya.
3. Minimalisasi data dan retensi pendek.
4. Tidak ada penjualan atau pembagian data lokasi ke pihak ketiga.
5. Tidak ada mode pelacakan tersembunyi.

## 2. Hukum Indonesia
- **UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi (UU PDP)**: data lokasi termasuk data pribadi. Perlu dasar pemrosesan (persetujuan), hak subjek data (akses, koreksi, hapus, tarik persetujuan), pemberitahuan insiden, dan kebijakan privasi berbahasa Indonesia.
- Perlu dipastikan: apakah data spesifik anak memerlukan persetujuan orang tua atau wali dan batas usianya.
- Lokasi server Supabase di luar negeri: periksa aturan transfer data lintas negara.

## 3. Pengguna anak
- Keputusan MVP (usulan): usia minimum 13 tahun untuk membuat akun sendiri. Anak di bawah itu tidak didukung di MVP.
- Anggota remaja tetap punya tombol jeda dan tahu bahwa lokasinya dibagikan.
- Dokumentasikan keputusan ini di kebijakan privasi dan tinjau secara hukum.

## 4. Persyaratan store
**Google Play** **[V]**
- Izin lokasi background perlu formulir deklarasi, video demo, dan pengungkapan yang menonjol (prominent disclosure) di dalam aplikasi sebelum meminta izin.
- Fitur inti aplikasi harus bergantung pada lokasi background, dan harus dijelaskan.
- Formulir keamanan data (Data safety) harus akurat.

**Apple App Store** **[V]**
- Teks alasan izin lokasi "Always" yang jelas di Info.plist.
- Penjelasan di App Review tentang kebutuhan lokasi background.
- Keterangan privasi aplikasi (App Privacy details) yang akurat.

**Tindakan:** baca ulang kebijakan resmi saat fase persiapan rilis, jangan mengandalkan catatan ini.

## 5. Model ancaman
| Ancaman | Contoh | Mitigasi |
|---------|--------|----------|
| Penguntitan | Pelaku memaksa korban memasang aplikasi | Notifikasi persisten "Tether aktif", tombol jeda, panduan keselamatan, kemampuan keluar Circle tanpa sepengetahuan anggota lain bila aman (dipertimbangkan) |
| Tebakan kode undangan | Orang asing masuk Circle | Kode panjang acak, kedaluwarsa, batas pemakaian, persetujuan admin |
| Pengambilalihan akun | Phishing atau pencurian sesi | Verifikasi email, penguncian percobaan berulang, tanda tangan sesi aman |
| Kebocoran data lewat RLS salah | Anggota Circle lain membaca lokasi | Tes RLS otomatis, review kebijakan |
| Kebocoran kunci | Kunci service role di klien | Kunci hanya di server, hanya kunci anon di klien |
| Pemalsuan lokasi | Mock location | Deteksi dasar (flag mock), tidak menjadi jaminan |
| Log berisi lokasi | Debugging tidak sengaja | Larangan log koordinat, tinjauan kode |

## 5a. Diagram aliran data (DFD)

### Level 0 (konteks)
```mermaid
flowchart LR
    Pengguna["Pengguna (Anggota dan Admin)"]
    Push["Layanan Push (FCM dan APNs)"]
    Google["Penyedia login Google"]
    Tile["Penyedia tile peta"]

    Sistem(("Sistem Tether"))

    Pengguna -- "kredensial, profil, lokasi, jeda, check-in, SOS, kode undangan" --> Sistem
    Sistem -- "peta anggota, status, notifikasi, riwayat 48 jam" --> Pengguna
    Sistem -- "token perangkat dan isi notifikasi" --> Push
    Push -- "notifikasi ke ponsel" --> Pengguna
    Pengguna -- "autentikasi" --> Google
    Google -- "identitas terverifikasi" --> Sistem
    Pengguna -- "permintaan tile berdasarkan area peta" --> Tile
```

Catatan privasi: permintaan tile peta dikirim dari ponsel ke penyedia tile, sehingga penyedia bisa mengetahui area yang dilihat. Pertimbangkan saat memilih penyedia (ADR-004).

### Level 1
```mermaid
flowchart TB
    Pengguna["Pengguna"]
    Push["Layanan Push"]

    P1(("1. Autentikasi dan profil"))
    P2(("2. Kelola Circle dan undangan"))
    P3(("3. Terima dan simpan lokasi"))
    P4(("4. Geofence dan notifikasi"))
    P5(("5. Check-in dan SOS"))
    P6(("6. Tampilkan peta dan riwayat"))
    P7(("7. Retensi dan hapus data"))

    D1[("D1 profiles dan devices")]
    D2[("D2 circles, members, invites")]
    D3[("D3 places")]
    D4[("D4 location_points")]
    D5[("D5 member_status")]
    D6[("D6 events")]

    Pengguna -- "kredensial dan profil" --> P1
    P1 <--> D1
    P1 -- "status login" --> Pengguna

    Pengguna -- "buat Circle, kode, jeda" --> P2
    P2 <--> D2
    P2 -- "keanggotaan" --> Pengguna

    Pengguna -- "titik lokasi" --> P3
    P3 --> D4
    P3 --> D5
    D2 -- "status jeda dan keanggotaan" --> P3

    D5 --> P4
    D3 --> P4
    P4 --> D6
    D1 -- "token push" --> P4
    P4 -- "isi notifikasi" --> Push

    Pengguna -- "check-in dan SOS" --> P5
    P5 --> D6
    D1 -- "token push" --> P5
    P5 -- "notifikasi prioritas" --> Push

    D5 --> P6
    D4 --> P6
    D2 -- "izin lihat per Circle" --> P6
    P6 -- "peta dan riwayat" --> Pengguna

    P7 -- "hapus titik lebih dari 48 jam" --> D4
    P7 -- "hapus data akun setelah 30 hari" --> D1
    P7 -- "hapus data akun" --> D5
    P7 -- "hapus event lama" --> D6
```

Pemetaan ke prinsip privasi: data lokasi hanya mengalir ke D4 dan D5, dibaca lewat P6 dengan filter keanggotaan dan jeda, dan dihapus oleh P7. Tidak ada aliran data lokasi ke pihak ketiga selain notifikasi yang memuat lokasi SOS.

## 6. Kontrol keamanan teknis
- TLS di semua koneksi, enkripsi diam pada penyimpanan Supabase.
- Penyimpanan token di Keychain dan Keystore.
- RLS aktif pada semua tabel, tanpa pengecualian.
- Edge Function memvalidasi masukan dan membatasi laju (rate limit).
- Dependensi dipantau kerentanannya. Jalankan analisis keamanan sebelum rilis.
- Pencadangan database dan uji pemulihan.

## 7. Hak pengguna dan retensi
| Data | Retensi |
|------|---------|
| Titik lokasi | 48 jam |
| Posisi terakhir | Selama berbagi aktif, hapus saat keluar Circle |
| Events | 90 hari (usulan) |
| Akun | Sampai dihapus. Penghapusan tuntas dalam 30 hari |

Pengguna dapat: melihat data sendiri, menjeda, keluar Circle, menghapus riwayat, menghapus akun.

## 8. Dokumen yang harus ada sebelum rilis
- [ ] Kebijakan Privasi (Indonesia dan English)
- [ ] Syarat dan Ketentuan
- [ ] Teks pengungkapan izin lokasi dalam aplikasi
- [ ] Halaman keamanan untuk korban penguntitan
- [ ] Prosedur penanganan insiden kebocoran data
- [ ] Prosedur permintaan hapus data

## 9. Pertanyaan terbuka
- Usia minimum final.
- Kebijakan admin terhadap anggota yang menjeda.
- Perlu pendaftaran penyelenggara sistem elektronik (PSE) di Kominfo/Komdigi? **[V]**
