enum CheckinKind {
  /// "Saya sudah sampai".
  arrived('arrived'),

  /// "Saya aman".
  safe('safe');

  const CheckinKind(this.wire);

  /// Nilai p_kind di RPC checkin.
  final String wire;
}

/// Akses RPC check-in dan SOS. Melempar `SafetyError`.
abstract class SafetyRepository {
  Future<void> checkin(String circleId, CheckinKind kind);

  /// Memicu SOS ke semua Circle pengguna dan mengembalikan jumlah Circle yang
  /// diberi tahu. Idempoten menurut [clientId]: pengulangan tidak membuat
  /// event atau push baru.
  Future<int> triggerSos({
    required double lat,
    required double lng,
    double? accuracyM,
    required String clientId,
    required DateTime triggeredAt,
  });
}
