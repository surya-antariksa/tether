import 'package:latlong2/latlong.dart';

/// Satu titik riwayat lokasi milik sendiri (public.location_points).
class HistoryPoint {
  const HistoryPoint({
    required this.point,
    required this.recordedAt,
    this.accuracyM,
    this.isMoving = false,
  });

  final LatLng point;
  final DateTime recordedAt;
  final double? accuracyM;
  final bool isMoving;
}
