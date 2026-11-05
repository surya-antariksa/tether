# Tether: Indeks Dokumen

Tether adalah aplikasi berbagi lokasi dan keselamatan untuk keluarga Indonesia, dibangun dengan Flutter dan Supabase.

| No | Dokumen | Isi | Status |
|----|---------|-----|--------|
| 00 | [Product Brief](00-product-brief.md) | Visi, masalah, target, pembeda | Draf 1 |
| 01 | [PRD](01-prd.md) | Fitur MVP, user story, kebutuhan non-fungsional, metrik | Draf 1 |
| 02 | [Analisis Kompetitor](02-competitor-analysis.md) | Perbandingan dengan Life360 dan lainnya | Draf 1, perlu verifikasi |
| 03 | [Arsitektur & ADR](03-architecture.md) | Arsitektur sistem dan keputusan teknologi (ADR-001 sampai 016) | Draf 2, selaras migrasi Sprint 1-5 |
| 04 | [Model Data](04-data-model.md) | ERD, tabel, RPC, kode galat, aturan RLS, retensi | Draf 2, selaras migrasi Sprint 1-5 |
| 05 | [Privasi, Keamanan, Kepatuhan](05-privacy-security.md) | UU PDP, kebijakan store, model ancaman, retensi, hapus akun | Draf 2, selaras migrasi Sprint 1-5 |
| 06 | [Roadmap & Rencana Uji](06-roadmap.md) | Fase kerja, spike, rencana pengujian, risiko | Draf 1 |
| 07 | [Diagram OOAD](07-uml-diagrams.md) | Use case, activity, sequence, class, state (Mermaid) | Draf 1 |
| 08 | [Design System (gaya Apple)](08-design-system.md) | Warna, tipografi, komponen, izin, Liquid Glass berbasis HIG | Draf 1 |
| 09 | [Sprint Plan](09-sprint-plan.md) | Jadwal sprint 0 sampai 7, tugas, definisi selesai, alur push per sprint | Draf 1 |
| 10 | [Panduan Uji Manual](10-panduan-uji.md) | Checklist uji di Linux (dua instance), bagian yang butuh Android, prasyarat pemilik, tempat catatan revisi | Draf 1, belum dijalankan |

Catatan hasil sprint: [Sprint 0A](sprints/sprint-0.md), [Sprint 1 sampai 5 (versi Linux)](sprints/sprint-1-5.md).

Diagram lain: komponen dan deployment di 03 (rancangan target), ERD di 04, DFD di 05.

## Keputusan yang sudah diambil
- Target: keluarga Indonesia.
- Monetisasi: gratis dulu, diputuskan setelah MVP.
- Backend: Supabase.
- Desain: satu desain gaya Apple untuk Android dan iOS (lihat 08).
- Git: satu push per sprint, branch `sprint/N-nama`, tag `sprint-N` (lihat 09).
- Platform rilis pertama: Android saja, ke Google Play. iOS ditunda (tidak ada Mac dan iPhone).
- Lingkungan uji: komputer Linux ini (desktop Linux, Chrome, emulator Android). Satu Redmi hanya untuk uji lokasi background (Sprint 0B, sebelum Sprint 3).
- Pelaksana: Claude. Pemilik produk mereview tiap sprint, menguji di Redmi, lalu revisi sebelum sprint berikutnya.
- Klien: Flutter (Android dan iOS).

## Aturan dokumen
- Hal yang belum diverifikasi ditandai **[Belum diverifikasi]**.
- Pertanyaan yang belum terjawab dikumpulkan di bagian "Pertanyaan terbuka" tiap dokumen.
- Perubahan keputusan teknologi dicatat sebagai ADR baru di dokumen 03, bukan menimpa yang lama.
