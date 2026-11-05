enum SafetyErrorKind {
  /// TH006 (check-in, 1 per 30 detik) atau TH007 (SOS, 3 per 10 menit).
  rateLimited,

  /// TH008: pengguna tidak punya Circle, tak ada yang bisa diberi tahu.
  noCircle,

  /// 42501: bukan anggota Circle.
  notMember,

  /// 28000 atau JWT kedaluwarsa.
  notSignedIn,

  /// 22023: argumen ditolak server.
  invalidArgument,
  network,
  unknown,

  /// Hanya antrean SOS: tertunda lebih lama dari batas usia, dibuang.
  expired,

  /// Hanya SOS: tidak terkirim dan juga gagal disimpan di antrean, jadi tidak
  /// akan dicoba ulang otomatis.
  notSaved,
}

/// Galat check-in/SOS yang sudah dipetakan. Sengaja tanpa pesan server,
/// detail, atau koordinat.
class SafetyError implements Exception {
  const SafetyError(this.kind);

  final SafetyErrorKind kind;

  /// Sementara: kirim ulang nanti masih mungkin berhasil. Selain itu permanen
  /// (server menolak dengan alasan yang tidak berubah sendiri).
  bool get isTransient => switch (kind) {
    SafetyErrorKind.network ||
    SafetyErrorKind.notSignedIn ||
    SafetyErrorKind.unknown => true,
    _ => false,
  };

  @override
  String toString() => 'SafetyError($kind)';
}
