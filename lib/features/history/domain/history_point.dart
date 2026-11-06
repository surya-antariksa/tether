import 'package:latlong2/latlong.dart';

/// Satu titik riwayat lokasi milik sendiri (public.location_points).
class HistoryPoint {
  const HistoryPoint({
    required this.point,
    required this.recordedAt,
    this.accuracyM,
    this.isMoving = false,
    this.speedMps,
    this.batteryPct,
  });

  final LatLng point;
  final DateTime recordedAt;
  final double? accuracyM;
  final bool isMoving;

  /// Kecepatan dari GPS (m/s); null bila perangkat tidak melaporkannya.
  final double? speedMps;

  /// Baterai saat titik dicatat (0..100); null bila tidak tersedia.
  final int? batteryPct;

  double? get speedKmh => speedMps == null ? null : speedMps! * 3.6;
}
