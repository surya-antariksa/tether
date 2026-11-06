import '../domain/history_repository.dart';

/// Teks UI riwayat lokasi (bahasa Indonesia).
abstract final class HistoryStrings {
  static const title = 'Riwayat lokasi';
  static const rowTitle = 'Riwayat lokasi';
  static const rowSubtitle = '30 hari terakhir';

  static const mapLabel = 'Peta jejak lokasi Anda dalam 30 hari terakhir';
  static const mapStart = 'Titik terlama';
  static const mapEnd = 'Titik terbaru';

  static String count(int n) => '$n titik dalam 30 hari terakhir';
  static String truncated(int n) =>
      'Menampilkan $n titik terbaru. Titik yang lebih lama tidak ditampilkan.';

  static const today = 'Hari ini';
  static const yesterday = 'Kemarin';
  static const moving = 'Bergerak';
  static const still = 'Diam';
  static String accuracy(int m) => 'akurasi ±$m m';
  static String rowLabel(String time, String state, String? accuracy) =>
      'Pukul $time, $state${accuracy == null ? '' : ', $accuracy'}';

  static const emptyTitle = 'Belum ada riwayat';
  static const emptyBody =
      'Titik lokasi Anda muncul di sini selama berbagi lokasi aktif.';

  static const loadFailed = 'Riwayat tidak bisa dimuat.';
  static const retry = 'Coba lagi';

  static const privacy =
      'Titik lokasi disimpan 30 hari, lalu dihapus otomatis. Menghapus riwayat '
      'membuang semua titik di atas dari server. Posisi terakhir yang tampil '
      'di peta keluarga tidak ikut dihapus; jeda berbagi lokasi bila ingin '
      'menghentikannya.';

  static const delete = 'Hapus riwayat';
  static const deleting = 'Menghapus riwayat';
  static const deleteTitle = 'Hapus riwayat lokasi?';
  static const deleteMessage =
      'Semua titik lokasi Anda dalam 30 hari terakhir akan dihapus dan tidak '
      'bisa dikembalikan.';
  static const cancel = 'Batal';
  static const deletedTitle = 'Riwayat dihapus';
  static String deletedMessage(int n) => '$n titik lokasi sudah dihapus.';

  static const errorTitle = 'Gagal menghapus';
  static const ok = 'Tutup';

  static String failure(HistoryFailureKind k) => switch (k) {
    HistoryFailureKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda.',
    HistoryFailureKind.unauthorized =>
      'Sesi berakhir. Masuk lagi untuk lanjut.',
    HistoryFailureKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };
}
