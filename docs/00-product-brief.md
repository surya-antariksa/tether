# 00. Product Brief: Tether

## Ringkasan
Tether membantu anggota keluarga saling tahu posisi dan keadaan satu sama lain secara real-time, dengan persetujuan semua pihak, supaya orang tua tenang dan anak atau pasangan merasa aman.

## Masalah
- Keluarga sering saling bertanya "sudah sampai mana?" lewat chat, mengganggu orang yang sedang berkendara.
- Orang tua khawatir saat anak pulang larut atau bepergian, dan tidak punya cara cepat memastikan.
- Saat darurat, anggota keluarga sulit memberi tahu lokasi tepatnya.
- Aplikasi berbagi lokasi yang ada kebanyakan berbahasa asing, harga dalam dolar, dan belum dirancang untuk konteks Indonesia.

## Target pengguna
**Utama:** keluarga Indonesia (orang tua dengan anak usia sekolah sampai dewasa, pasangan, dan anggota keluarga besar).

**Persona awal:**
- **Ibu Rina (42)**: ingin tahu anak sudah sampai sekolah atau rumah tanpa menelepon.
- **Raka (16)**: mau privasi, tidak mau merasa dimata-matai, ingin bisa mematikan berbagi sementara.
- **Dedi (45)**: sering berkendara jauh, ingin keluarga bisa melihat posisinya dan bisa menekan SOS.

## Proposisi nilai
1. **Tahu tanpa bertanya**: peta real-time anggota Circle dan notifikasi tiba atau pergi dari tempat penting.
2. **Aman saat darurat**: tombol SOS mengirim lokasi ke semua anggota.
3. **Berbasis persetujuan**: setiap anggota mengontrol berbagi lokasinya sendiri.
4. **Lokal**: bahasa Indonesia, harga rupiah (saat monetisasi), memperhatikan baterai dan kuota.

## Pembeda dari Life360
| Aspek | Life360 | Tether (rencana) |
|-------|---------|------------------|
| Bahasa dan konteks | Global | Indonesia dulu |
| Privasi | Ada, tapi model bisnis menjual data agregat [Belum diverifikasi] | Privasi sebagai nilai inti, tidak menjual data lokasi |
| Harga | Langganan USD | Gratis dulu |
| Kontrol anggota | Terbatas pada beberapa kondisi [Belum diverifikasi] | Tombol jeda yang jelas untuk setiap anggota |

## Prinsip produk
1. **Consent first**: tidak ada pelacakan tersembunyi. Anggota selalu tahu dirinya dibagikan.
2. **Hemat baterai**: pelacakan adaptif, bukan polling terus-menerus.
3. **Data seminimal mungkin**: riwayat lokasi dibatasi dan bisa dihapus.
4. **Sederhana**: satu layar utama (peta), tindakan penting maksimal 2 ketukan.

## Di luar visi awal
Chat penuh, pelacakan aset atau kendaraan tanpa pengguna, pengawasan tersembunyi, penjualan data.

## Asumsi
- Pengguna mau memberi izin lokasi "selalu" jika alasannya jelas.
- Mayoritas pengguna Android, sebagian iOS. [Belum diverifikasi]
- Pelacakan background bisa andal di perangkat Android pabrikan Tiongkok dengan konfigurasi yang tepat. **Ini harus dibuktikan di spike (lihat 06).**

## Pertanyaan terbuka
- Nama dan identitas visual final.
- Apakah anak di bawah 13 tahun didukung di MVP? (lihat 05, berdampak hukum)
