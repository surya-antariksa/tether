import 'dart:math';

import 'safety_error.dart';

/// Posisi untuk SOS. Sengaja tanpa koordinat di toString.
class SosFix {
  const SosFix({required this.lat, required this.lng, this.accuracyM});

  final double lat;
  final double lng;
  final double? accuracyM;

  /// Rentang yang diterima trigger_sos (selain itu 22023).
  bool get isValid =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      (accuracyM == null || (accuracyM!.isFinite && accuracyM! >= 0));

  @override
  String toString() => 'SosFix()';
}

/// SOS yang sudah dipicu dan menunggu terkirim. [clientId] dan [triggeredAt]
/// dibuat saat dipicu dan tidak berubah antar percobaan.
class PendingSos {
  const PendingSos({
    required this.clientId,
    required this.userId,
    required this.triggeredAt,
    required this.fix,
  });

  factory PendingSos.fromJson(Map<String, dynamic> j) => PendingSos(
    clientId: j['client_id'] as String,
    userId: j['user_id'] as String,
    triggeredAt: DateTime.parse(j['triggered_at'] as String).toUtc(),
    fix: SosFix(
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
    ),
  );

  final String clientId;

  /// Pemilik SOS: tidak dikirim atas nama akun lain.
  final String userId;
  final DateTime triggeredAt;
  final SosFix fix;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'user_id': userId,
    'triggered_at': triggeredAt.toUtc().toIso8601String(),
    'lat': fix.lat,
    'lng': fix.lng,
    'accuracy_m': fix.accuracyM,
  };

  @override
  String toString() => 'PendingSos($clientId)';
}

sealed class SosOutcome {
  const SosOutcome();
}

/// Server menerima; [circles] = jumlah Circle yang diberi tahu.
final class SosSent extends SosOutcome {
  const SosSent(this.circles);

  final int circles;
}

/// Gagal sementara; tersimpan di antrean dan akan dicoba ulang.
final class SosQueued extends SosOutcome {
  const SosQueued(this.clientId);

  /// Untuk mencocokkan [SosDelivery] yang datang belakangan.
  final String clientId;
}

/// Gagal permanen; sudah dibuang dari antrean.
final class SosRejected extends SosOutcome {
  const SosRejected(this.kind);

  final SafetyErrorKind kind;
}

/// Hasil akhir satu SOS (dari kirim langsung maupun coba ulang di latar).
class SosDelivery {
  const SosDelivery(this.clientId, this.outcome);

  final String clientId;

  /// [SosSent] atau [SosRejected].
  final SosOutcome outcome;
}

/// UUID v4 acak (RFC 4122).
String generateUuidV4([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int from, int to) => [
    for (var i = from; i < to; i++) b[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}
