import 'history_point.dart';

enum HistoryFailureKind { network, unauthorized, unknown }

/// Galat riwayat yang sudah dipetakan, tanpa detail teknis atau koordinat.
class HistoryFailure implements Exception {
  const HistoryFailure(this.kind);

  final HistoryFailureKind kind;

  @override
  String toString() => 'HistoryFailure($kind)';
}

abstract interface class HistoryRepository {
  /// Jendela riwayat (sama dengan retensi server).
  static const window = Duration(hours: 48);

  /// Titik milik pengguna yang sedang masuk dalam [window] terakhir, TERBARU
  /// dulu. Maksimal [maxHistoryPoints] (batas baris PostgREST); yang terlama terpotong.
  Future<List<HistoryPoint>> fetchLast48h();

  /// Hapus semua titik lokasi milik sendiri. Mengembalikan jumlah yang dihapus.
  Future<int> deleteAll();
}

/// Batas baris per permintaan (max_rows PostgREST di supabase/config.toml).
const int maxHistoryPoints = 1000;
