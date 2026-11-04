# 04. Model Data

Versi: Draf 1. Nama dan tipe adalah usulan, finalisasi saat menulis migrasi.

## ERD
```mermaid
erDiagram
    profiles ||--o{ circle_members : "ikut"
    circles  ||--o{ circle_members : "punya"
    circles  ||--o{ places : "punya"
    circles  ||--o{ invites : "punya"
    profiles ||--o{ location_points : "menghasilkan"
    profiles ||--|| member_status : "status terakhir"
    circles  ||--o{ events : "mencatat"
    profiles ||--o{ devices : "memakai"

    profiles {
      uuid id PK "sama dengan auth.users.id"
      text display_name
      text avatar_url
      text color
      timestamptz created_at
      timestamptz deleted_at
    }
    circles {
      uuid id PK
      text name
      uuid created_by FK
      timestamptz created_at
    }
    circle_members {
      uuid circle_id FK
      uuid user_id FK
      text role "admin | member"
      boolean sharing_enabled
      timestamptz paused_until
      timestamptz joined_at
    }
    invites {
      uuid id PK
      uuid circle_id FK
      text code_hash
      timestamptz expires_at
      int max_uses
      int used_count
    }
    places {
      uuid id PK
      uuid circle_id FK
      text name
      geography center "Point"
      int radius_m
      uuid created_by FK
    }
    location_points {
      bigint id PK
      uuid user_id FK
      geography point
      real accuracy_m
      real speed_mps
      smallint battery_pct
      boolean is_moving
      timestamptz recorded_at
      timestamptz received_at
    }
    member_status {
      uuid user_id PK
      geography last_point
      timestamptz last_seen_at
      smallint battery_pct
      boolean is_moving
      uuid current_place_id
    }
    events {
      uuid id PK
      uuid circle_id FK
      uuid user_id FK
      text type "arrive | leave | checkin | sos | paused | resumed"
      uuid place_id
      jsonb payload
      timestamptz created_at
    }
    devices {
      uuid id PK
      uuid user_id FK
      text platform
      text push_token
      timestamptz last_active_at
    }
```

## Catatan desain
- `location_points` dipartisi per hari agar penghapusan retensi murah.
- Indeks: `(user_id, recorded_at desc)`, indeks GiST pada `places.center`.
- Kode undangan disimpan sebagai hash, bukan teks asli.
- `circle_members.paused_until` dan `sharing_enabled` ditegakkan juga di server: titik lokasi dari anggota yang sedang dijeda ditolak atau tidak disiarkan.
- Hapus akun: tandai `deleted_at`, hapus data turunan lewat job dalam 30 hari.

## Aturan RLS (usulan)
| Tabel | Baca | Tulis |
|-------|------|-------|
| profiles | Diri sendiri dan anggota Circle yang sama | Hanya diri sendiri |
| circles | Anggotanya | Pembuat (insert), admin (update, delete) |
| circle_members | Anggota Circle yang sama | Admin (kelola), diri sendiri (jeda, keluar) |
| places | Anggota Circle | Admin, atau anggota bila diizinkan (keputusan terbuka) |
| location_points | Pemilik; anggota Circle hanya 48 jam dan hanya bila `sharing_enabled` dan tidak dijeda | Hanya pemilik, lewat RPC tervalidasi |
| member_status | Anggota Circle yang sama selama berbagi aktif | Hanya lewat fungsi server |
| events | Anggota Circle | Hanya lewat fungsi server |
| devices | Pemilik | Pemilik |

## Pengujian RLS
Setiap kebijakan wajib punya tes: pengguna di luar Circle tidak bisa membaca, anggota yang dijeda tidak bocor, admin tidak bisa membaca lokasi anggota yang dijeda.

## Pertanyaan terbuka
- Apakah satu pengguna boleh ikut lebih dari satu Circle dengan pengaturan berbagi terpisah per Circle? (usulan: ya, `sharing_enabled` per keanggotaan)
- Siapa yang boleh membuat tempat?
