# 07. Diagram Analisis dan Perancangan (OOAD)

Semua diagram memakai Mermaid dan tampil otomatis di GitHub. Diagram komponen dan deployment ada di [03-architecture.md](03-architecture.md), DFD ada di [05-privacy-security.md](05-privacy-security.md), ERD ada di [04-data-model.md](04-data-model.md).

Catatan: Mermaid tidak punya tipe use case dan activity diagram bawaan, jadi keduanya digambar dengan `flowchart` memakai notasi yang mendekati UML. Nama kelas dan kode memakai bahasa Inggris, label alur memakai bahasa Indonesia.

Daftar isi:
1. Use case
2. Activity diagram (onboarding izin, gabung Circle, jeda berbagi, SOS)
3. Sequence diagram (unggah lokasi, tiba di tempat, SOS, hapus akun)
4. Class diagram (domain, lapisan aplikasi)
5. State machine (status anggota, SOS, undangan)

---

## 1. Use case

Aktor: **Anggota**, **Admin** (Admin adalah Anggota dengan hak tambahan), dan **Sistem Push (FCM)** sebagai aktor sekunder.

```mermaid
flowchart LR
    Anggota([Anggota])
    Admin([Admin Circle])
    Push([Sistem Push FCM])

    Admin -. "adalah jenis" .-> Anggota

    subgraph Tether["Sistem Tether"]
        UC1(("Daftar dan masuk"))
        UC2(("Kelola profil"))
        UC3(("Gabung Circle dengan kode"))
        UC4(("Lihat peta anggota"))
        UC5(("Bagikan lokasi di background"))
        UC6(("Jeda berbagi lokasi"))
        UC7(("Lihat riwayat lokasi 48 jam"))
        UC8(("Check-in"))
        UC9(("Kirim SOS"))
        UC10(("Terima notifikasi"))
        UC11(("Hapus akun"))
        UC12(("Buat Circle"))
        UC13(("Buat undangan"))
        UC14(("Kelola tempat"))
        UC15(("Keluarkan anggota"))
    end

    Anggota --> UC1
    Anggota --> UC2
    Anggota --> UC3
    Anggota --> UC4
    Anggota --> UC5
    Anggota --> UC6
    Anggota --> UC7
    Anggota --> UC8
    Anggota --> UC9
    Anggota --> UC10
    Anggota --> UC11

    Admin --> UC12
    Admin --> UC13
    Admin --> UC14
    Admin --> UC15

    UC8 -. "include" .-> UC10
    UC9 -. "include" .-> UC10
    UC5 -. "extend: tiba atau pergi dari tempat" .-> UC10

    UC10 --- Push
```

Ringkasan hubungan:
- Check-in dan SOS selalu memicu notifikasi (`include`).
- Notifikasi tiba atau pergi hanya muncul jika lokasi dibagikan dan ada tempat yang cocok (`extend`).
- Jeda berbagi membatasi use case "Bagikan lokasi di background".

---

## 2. Activity diagram

### 2.1 Onboarding dan izin (F13)

```mermaid
flowchart TD
    A([Mulai: aplikasi dibuka pertama kali]) --> B[Layar penjelasan: kenapa lokasi dibagikan]
    B --> C[Satu tombol: Lanjut]
    C --> D[Dialog izin lokasi sistem iOS atau Android]
    D --> E{Izin diberikan?}
    E -- Tidak --> F[Tampilkan dampak dan tombol buka pengaturan]
    F --> Z1([Selesai: tanpa berbagi lokasi])
    E -- Ya --> G[Penjelasan izin lokasi selalu]
    G --> H[Minta izin lokasi selalu]
    H --> I{Diberikan?}
    I -- Tidak --> J[Mode terbatas: lokasi hanya saat aplikasi terbuka]
    I -- Ya --> K[Minta izin notifikasi]
    J --> K
    K --> L[Panduan pengecualian hemat baterai sesuai merek ponsel]
    L --> M[Mulai layanan pelacakan]
    M --> Z2([Selesai: siap memakai peta])
```

### 2.2 Gabung Circle dengan kode (F3)

```mermaid
flowchart TD
    A([Mulai: pengguna sudah masuk]) --> B[Masukkan kode undangan]
    B --> C[Kirim ke server]
    C --> D{Kode valid?}
    D -- Tidak ditemukan --> E[Pesan: kode salah]
    D -- Kedaluwarsa atau habis --> F[Pesan: minta kode baru ke admin]
    E --> B
    F --> Z1([Selesai: gagal])
    D -- Valid --> G{Circle penuh? maksimal 10 anggota}
    G -- Ya --> H[Pesan: Circle penuh]
    H --> Z1
    G -- Tidak --> I[Tampilkan pratinjau: nama Circle dan jumlah anggota]
    I --> J{Pengguna konfirmasi gabung?}
    J -- Tidak --> Z1
    J -- Ya --> K[Tambah ke circle_members, naikkan used_count]
    K --> L[Catat event dan kirim push: anggota baru bergabung]
    L --> Z2([Selesai: peta Circle tampil])
```

### 2.3 Jeda berbagi lokasi (F6)

```mermaid
flowchart TD
    A([Mulai: buka menu berbagi]) --> B[Pilih durasi: 15 menit, 1 jam, atau sampai dihidupkan]
    B --> C[Klien kirim permintaan jeda]
    C --> D[Server set paused_until dan catat event paused]
    D --> E[Klien hentikan pengiriman titik baru]
    E --> F[Anggota lain melihat: menjeda berbagi lokasi]
    F --> G{Durasi habis atau pengguna menghidupkan lagi?}
    G -- Belum --> G
    G -- Ya --> H[Server hapus paused_until dan catat event resumed]
    H --> I[Klien lanjutkan pelacakan]
    I --> Z([Selesai])
```

### 2.4 Kirim SOS (F9)

```mermaid
flowchart TD
    A([Mulai: pengguna menekan tombol SOS]) --> B{Ditahan 3 detik?}
    B -- Tidak --> Z1([Dibatalkan: tidak terjadi apa-apa])
    B -- Ya --> C[Hitung mundur 5 detik dengan tombol batal]
    C --> D{Dibatalkan?}
    D -- Ya --> Z1
    D -- Tidak --> E[Ambil lokasi terbaru]
    E --> F{Ada koneksi?}
    F -- Tidak --> G[Simpan di antrean dan coba lagi berkala]
    G --> F
    F -- Ya --> H[Panggil fungsi server trigger_sos]
    H --> I[Server buat event sos dan siapkan penerima]
    I --> J[Kirim push prioritas tinggi ke semua anggota Circle]
    J --> K[Pengirim melihat konfirmasi terkirim]
    K --> Z2([Selesai])
```

---

## 3. Sequence diagram

### 3.1 Unggah lokasi di background (F5)

```mermaid
sequenceDiagram
    autonumber
    participant OS as Sistem Operasi
    participant Svc as LocationTrackingService
    participant Q as LocationQueue (lokal)
    participant API as Supabase (RPC)
    participant DB as Postgres
    participant RT as Realtime
    participant Peer as Aplikasi Anggota Lain

    OS->>Svc: titik lokasi baru
    Svc->>Svc: terapkan TrackingPolicy (diam, bergerak, hemat)
    Svc->>Q: simpan titik
    alt jaringan tersedia dan batch siap
        Svc->>API: upload_points(batch)
        API->>DB: cek keanggotaan, jeda, dan validasi
        alt anggota sedang dijeda
            DB-->>API: tolak titik
            API-->>Svc: ditolak (jeda aktif)
            Svc->>Q: buang titik
        else diterima
            DB->>DB: insert location_points
            DB->>DB: upsert member_status
            DB-->>API: ok
            API-->>Svc: ok
            Svc->>Q: hapus titik terkirim
            DB-->>RT: perubahan member_status
            RT-->>Peer: posisi baru (jika sedang membuka peta)
        end
    else offline
        Svc->>Q: tahan, coba lagi nanti
    end
```

### 3.2 Tiba atau pergi dari tempat (F7)

```mermaid
sequenceDiagram
    autonumber
    participant DB as Postgres
    participant Fn as Edge Function (geofence)
    participant FCM as FCM
    participant Peer as Ponsel Anggota Lain

    DB->>Fn: titik baru tersimpan (trigger)
    Fn->>DB: ambil places milik Circle pengguna
    Fn->>Fn: ST_DWithin dibanding radius
    Fn->>DB: baca current_place_id dan titik sebelumnya
    alt dua titik berurutan di dalam radius dan sebelumnya di luar
        Fn->>DB: insert event arrive, update current_place_id
        Fn->>DB: ambil push_token anggota lain
        Fn->>FCM: kirim notifikasi: tiba di tempat
        FCM-->>Peer: tampilkan notifikasi
    else dua titik berurutan di luar radius dan sebelumnya di dalam
        Fn->>DB: insert event leave, kosongkan current_place_id
        Fn->>FCM: kirim notifikasi: pergi dari tempat
        FCM-->>Peer: tampilkan notifikasi
    else tidak ada perubahan atau belum cukup titik
        Fn->>Fn: tidak melakukan apa-apa (debounce)
    end
```

### 3.3 SOS (F9)

```mermaid
sequenceDiagram
    autonumber
    actor U as Pengirim
    participant App as Aplikasi
    participant Fn as Edge Function trigger_sos
    participant DB as Postgres
    participant FCM as FCM
    participant Peer as Anggota Lain

    U->>App: tahan tombol SOS 3 detik
    App->>U: hitung mundur 5 detik (bisa batal)
    U->>App: tidak membatalkan
    App->>App: ambil lokasi terbaru
    App->>Fn: trigger_sos(circle_id, lokasi)
    Fn->>DB: verifikasi pengirim anggota Circle
    Fn->>DB: insert event sos dengan payload lokasi
    Fn->>DB: ambil push_token semua anggota lain
    Fn->>FCM: kirim push prioritas tinggi
    Fn-->>App: sukses
    App-->>U: tampilkan: peringatan terkirim
    FCM-->>Peer: notifikasi SOS dengan lokasi
    Peer->>App: buka notifikasi
    App-->>Peer: peta menuju lokasi pengirim
```

### 3.4 Hapus akun (F12)

```mermaid
sequenceDiagram
    autonumber
    actor U as Pengguna
    participant App as Aplikasi
    participant Fn as Edge Function delete_account
    participant DB as Postgres
    participant Cron as pg_cron

    U->>App: pilih hapus akun
    App->>U: peringatan dan minta konfirmasi ulang
    U->>App: konfirmasi
    App->>Fn: delete_account()
    Fn->>DB: set profiles.deleted_at, cabut sesi
    Fn->>DB: keluarkan dari semua Circle, hapus devices
    Fn-->>App: sukses
    App->>App: bersihkan data lokal dan keluar
    App-->>U: akun dinonaktifkan
    Note over Cron,DB: dalam 30 hari
    Cron->>DB: hapus tuntas profil, titik lokasi, events, foto
```

---

## 4. Class diagram

### 4.1 Model domain

```mermaid
classDiagram
    class Profile {
        +UUID id
        +String displayName
        +String avatarUrl
        +String color
        +DateTime createdAt
        +DateTime deletedAt
    }
    class Circle {
        +UUID id
        +String name
        +UUID createdBy
        +DateTime createdAt
        +addMember(userId)
        +removeMember(userId)
    }
    class CircleMember {
        +UUID circleId
        +UUID userId
        +Role role
        +bool sharingEnabled
        +DateTime pausedUntil
        +DateTime joinedAt
        +isSharing(now) bool
        +pause(duration)
        +resume()
    }
    class Invite {
        +UUID id
        +UUID circleId
        +String codeHash
        +DateTime expiresAt
        +int maxUses
        +int usedCount
        +isValid(now) bool
    }
    class Place {
        +UUID id
        +UUID circleId
        +String name
        +GeoPoint center
        +int radiusM
        +contains(point) bool
    }
    class LocationPoint {
        +int id
        +UUID userId
        +GeoPoint point
        +double accuracyM
        +double speedMps
        +int batteryPct
        +bool isMoving
        +DateTime recordedAt
        +DateTime receivedAt
    }
    class MemberStatus {
        +UUID userId
        +GeoPoint lastPoint
        +DateTime lastSeenAt
        +int batteryPct
        +bool isMoving
        +UUID currentPlaceId
        +PresenceState presence(now)
    }
    class Event {
        +UUID id
        +UUID circleId
        +UUID userId
        +EventType type
        +UUID placeId
        +Map payload
        +DateTime createdAt
    }
    class Device {
        +UUID id
        +UUID userId
        +String platform
        +String pushToken
        +DateTime lastActiveAt
    }
    class GeoPoint {
        +double lat
        +double lng
        +distanceTo(other) double
    }
    class Role {
        <<enumeration>>
        admin
        member
    }
    class EventType {
        <<enumeration>>
        arrive
        leave
        checkin
        sos
        paused
        resumed
    }
    class PresenceState {
        <<enumeration>>
        active
        paused
        stale
        noPermission
    }

    Profile "1" --> "0..*" CircleMember : ikut
    Circle "1" *-- "1..10" CircleMember : memiliki
    Circle "1" *-- "0..*" Invite : memiliki
    Circle "1" *-- "0..5" Place : memiliki
    Circle "1" *-- "0..*" Event : mencatat
    Profile "1" --> "0..*" LocationPoint : menghasilkan
    Profile "1" --> "1" MemberStatus : status terakhir
    Profile "1" --> "0..*" Device : memakai
    CircleMember --> Role
    Event --> EventType
    MemberStatus --> PresenceState
    Place --> GeoPoint
    LocationPoint --> GeoPoint
    MemberStatus --> GeoPoint
```

### 4.2 Lapisan aplikasi Flutter (usulan)

Mengikuti struktur `features/` pada [03-architecture.md](03-architecture.md). Nama kelas bersifat usulan.

```mermaid
classDiagram
    direction LR

    class AuthRepository {
        <<interface>>
        +signInWithEmail(email, password)
        +signInWithGoogle()
        +signOut()
        +deleteAccount()
        +currentUser() Profile
    }
    class CircleRepository {
        <<interface>>
        +createCircle(name) Circle
        +createInvite(circleId) Invite
        +joinWithCode(code) Circle
        +leave(circleId)
        +removeMember(circleId, userId)
        +watchMembers(circleId) Stream
    }
    class PlaceRepository {
        <<interface>>
        +list(circleId) List
        +create(place)
        +delete(placeId)
    }
    class LocationRepository {
        <<interface>>
        +uploadBatch(points)
        +history(userId, hours) List
        +clearHistory()
        +pause(circleId, duration)
        +resume(circleId)
    }
    class SosRepository {
        <<interface>>
        +trigger(circleId, point)
    }

    class SupabaseCircleRepository
    class SupabasePlaceRepository
    class SupabaseLocationRepository
    class SupabaseAuthRepository
    class SupabaseSosRepository

    class LocationTrackingService {
        +start()
        +stop()
        +onPoint(point)
        -flush()
    }
    class TrackingPolicy {
        +modeFor(speed, battery) TrackingMode
        +intervalFor(mode) Duration
        +distanceFilterFor(mode) int
    }
    class LocationQueue {
        +enqueue(point)
        +takeBatch(n) List
        +ack(ids)
        +size() int
    }
    class PermissionService {
        +requestWhenInUse()
        +requestAlways()
        +requestNotifications()
        +batteryOptimizationGuide() Guide
    }
    class PushService {
        +registerToken()
        +onMessage(handler)
    }
    class SosController {
        +hold()
        +cancel()
        +confirm()
    }
    class MapController {
        +members() Stream
        +focus(userId)
    }
    class TrackingMode {
        <<enumeration>>
        stationary
        moving
        batterySaver
    }

    AuthRepository <|.. SupabaseAuthRepository
    CircleRepository <|.. SupabaseCircleRepository
    PlaceRepository <|.. SupabasePlaceRepository
    LocationRepository <|.. SupabaseLocationRepository
    SosRepository <|.. SupabaseSosRepository

    LocationTrackingService --> TrackingPolicy : memakai
    LocationTrackingService --> LocationQueue : menyimpan ke
    LocationTrackingService --> LocationRepository : mengunggah lewat
    TrackingPolicy --> TrackingMode
    SosController --> SosRepository
    SosController --> LocationTrackingService : minta lokasi terbaru
    MapController --> CircleRepository
    PermissionService ..> LocationTrackingService : izin dibutuhkan
    PushService ..> AuthRepository : butuh user aktif
```

Prinsip: antarmuka repository dipisah dari implementasi Supabase agar mudah diuji dengan tiruan (mock) dan agar backend bisa diganti tanpa mengubah UI.

---

## 5. State machine

### 5.1 Status anggota di peta

Dihitung dari `member_status`, `circle_members`, dan izin. Batas waktu "basi" masih usulan dan perlu dikalibrasi di spike (06).

```mermaid
stateDiagram-v2
    [*] --> NoPermission : akun baru tanpa izin
    NoPermission --> Active : izin lokasi diberikan dan titik diterima
    Active --> Paused : pengguna menjeda
    Paused --> Active : jeda habis atau dihidupkan lagi
    Active --> Stale : tidak ada titik baru melebihi batas basi
    Stale --> Active : titik baru diterima
    Stale --> Paused : pengguna menjeda
    Active --> NoPermission : izin dicabut
    Stale --> NoPermission : izin dicabut
    Paused --> NoPermission : izin dicabut
    Active --> [*] : keluar Circle atau akun dihapus
    Paused --> [*] : keluar Circle atau akun dihapus
    Stale --> [*] : keluar Circle atau akun dihapus

    state Active {
        [*] --> Stationary
        Stationary --> Moving : kecepatan atau jarak melewati ambang
        Moving --> Stationary : diam melewati durasi tertentu
    }
```

Tampilan pada peta:
- `Active`: marker normal dengan waktu pembaruan.
- `Paused`: marker abu-abu dengan teks "menjeda berbagi lokasi".
- `Stale`: marker pudar dengan teks "terakhir terlihat X lalu".
- `NoPermission`: tanpa marker, teks "izin lokasi belum aktif".

### 5.2 Siklus SOS

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Holding : tombol ditekan
    Holding --> Idle : dilepas sebelum 3 detik
    Holding --> Countdown : ditahan 3 detik
    Countdown --> Idle : dibatalkan dalam 5 detik
    Countdown --> Sending : hitung mundur selesai
    Sending --> Queued : tidak ada koneksi
    Queued --> Sending : koneksi kembali
    Sending --> Sent : server menerima dan push dikirim
    Sending --> Failed : gagal berulang
    Failed --> Sending : pengguna coba lagi
    Sent --> [*]
```

### 5.3 Siklus undangan

```mermaid
stateDiagram-v2
    [*] --> Active : admin membuat undangan
    Active --> Active : dipakai (used_count naik, belum mencapai max_uses)
    Active --> Exhausted : used_count mencapai max_uses
    Active --> Expired : melewati expires_at (48 jam)
    Active --> Revoked : admin membuat ulang atau mencabut
    Exhausted --> [*]
    Expired --> [*]
    Revoked --> [*]
```

---

## Cara memperbarui
- Ubah diagram bersamaan dengan perubahan PRD, model data, atau ADR terkait.
- Cek tampilan di pratinjau Markdown GitHub atau editor [mermaid.live](https://mermaid.live) sebelum commit.
