import 'location_point.dart';

/// Sumber titik lokasi (simulasi sekarang, GPS nyata di Sprint 0B).
abstract class LocationSource {
  Stream<LocationPoint> get points;
  Future<void> start();
  Future<void> stop();
}
