import '../domain/map_repository.dart';
import '../domain/presence.dart';

/// Teks UI fitur peta (bahasa Indonesia).
abstract final class MapStrings {
  static const title = 'Peta';
  static const osmAttribution = '© OpenStreetMap contributors';
  static const osmAttributionHint =
      'Data peta © OpenStreetMap contributors, tersedia di bawah lisensi ODbL. '
      'Selengkapnya di openstreetmap.org/copyright.';
  static const attributionTitle = 'Atribusi peta';
  static const attributionLabel = 'Atribusi peta, © OpenStreetMap contributors';

  static const loadFailed = 'Peta tidak bisa dimuat.';
  static const retry = 'Coba lagi';
  static const close = 'Tutup';

  // Tanpa Circle
  static const noCircleTitle = 'Belum ada Circle';
  static const noCircleBody =
      'Buat Circle atau gabung dengan kode undangan untuk melihat lokasi keluarga.';
  static const openCircleTab = 'Buka tab Circle';

  // Judul dan pemilih Circle
  static const circlePickerTitle = 'Pilih Circle';
  static const circlePickerCancel = 'Batal';
  static String circleTitleLabel(String name, {required bool canSwitch}) =>
      canSwitch ? 'Circle $name, ketuk untuk ganti Circle' : 'Circle $name';

  // Kontrol melayang
  static const centerAll = 'Pusatkan semua anggota';
  static const centerMe = 'Ke lokasi saya';

  // Realtime
  static const realtimeOffline = 'Menyambung ulang';
  static const realtimeOfflineLabel =
      'Koneksi langsung terputus, mencoba menyambung ulang';

  // Panel
  static const sheetLabel = 'Daftar anggota';
  static String sheetTitle(String circleName, int count) =>
      '$circleName · $count anggota';
  static const you = 'Kamu';
  static const noMembers = 'Belum ada anggota.';

  static const statusPaused = 'Menjeda berbagi lokasi';
  static const statusNoLocation = 'Belum ada lokasi';
  static const statusMoving = 'Bergerak';
  static const statusStill = 'Diam';
  static const statusActive = 'Aktif';
  static String statusStale(String ago) => 'Terakhir terlihat $ago';
  static String updated(String ago) => 'Diperbarui $ago';
  static String battery(int pct) => 'Baterai $pct%';

  static String statusText(
    PresenceState presence, {
    required bool? isMoving,
    required String? ago,
  }) => switch (presence) {
    PresenceState.paused => statusPaused,
    PresenceState.noLocation => statusNoLocation,
    PresenceState.stale => statusStale(ago ?? ''),
    PresenceState.active =>
      isMoving == null ? statusActive : (isMoving ? statusMoving : statusStill),
  };

  // Jeda berbagi (F6)
  static const pause = 'Jeda';
  static const resume = 'Lanjutkan';
  static const pauseSheetTitle = 'Jeda berbagi lokasi';
  static const pauseSheetMessage =
      'Anggota lain melihat kamu sebagai menjeda di Circle ini.';
  static const pause15 = '15 menit';
  static const pause60 = '1 jam';
  static const pauseUntilResume = 'Sampai saya nyalakan lagi';
  static const cancel = 'Batal';
  static const selfPaused = 'Kamu menjeda berbagi lokasi';
  static const selfPausedIndefinite = 'Sampai kamu menyalakannya lagi';
  static String selfPausedUntil(String clock) => 'Sampai pukul $clock';
  static const pauseFailedTitle = 'Gagal menjeda';
  static const resumeFailedTitle = 'Gagal melanjutkan';

  static String failure(MapFailureKind k) => switch (k) {
    MapFailureKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda.',
    MapFailureKind.notMember => 'Kamu bukan anggota Circle ini lagi.',
    MapFailureKind.unauthenticated => 'Sesi berakhir. Masuk lagi untuk lanjut.',
    MapFailureKind.invalid ||
    MapFailureKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };

  // Semantics
  static String avatarLabel(String name) => 'Avatar $name';
  static String memberLabel(
    String name, {
    required bool isSelf,
    required String status,
    String? updated,
    int? batteryPct,
  }) => [
    isSelf ? '$name, $you' : name,
    status,
    ?updated,
    if (batteryPct != null) battery(batteryPct),
  ].join(', ');
  static const centerOnMember = 'Pusatkan peta ke anggota';
}
