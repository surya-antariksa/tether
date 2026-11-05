import 'dart:math' as math;

/// Meter per derajat lintang (aproksimasi bola).
const double metersPerDegreeLat = 111320;

const double _earthRadiusM = 6371000;

/// Geser koordinat sejauh [northM] ke utara dan [eastM] ke timur.
/// Bujur dikali cos(lintang) karena derajat bujur menyempit ke kutub.
({double lat, double lng}) offsetByMeters(
  double lat,
  double lng, {
  double northM = 0,
  double eastM = 0,
}) {
  final dLat = northM / metersPerDegreeLat;
  final dLng = eastM / (metersPerDegreeLat * math.cos(lat * math.pi / 180));
  return (lat: lat + dLat, lng: lng + dLng);
}

/// Jarak lingkaran besar dalam meter (haversine).
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(a));
}
