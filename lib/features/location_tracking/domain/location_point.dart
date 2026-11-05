/// Satu titik lokasi hasil sampling, siap diantre dan diunggah.
class LocationPoint {
  LocationPoint({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.batteryPct,
    required this.isMoving,
    required DateTime recordedAt,
  }) : recordedAt = recordedAt.toUtc();

  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final int? batteryPct;
  final bool isMoving;

  /// Selalu UTC.
  final DateTime recordedAt;

  /// Bentuk untuk RPC `upload_points` (elemen `p_points`).
  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'accuracy_m': accuracyM,
    'speed_mps': speedMps,
    'battery_pct': batteryPct,
    'is_moving': isMoving,
    'recorded_at': recordedAt.toIso8601String(),
  };

  // Sengaja tanpa koordinat agar tidak bocor ke log.
  @override
  String toString() => 'LocationPoint(recordedAt: $recordedAt)';
}
