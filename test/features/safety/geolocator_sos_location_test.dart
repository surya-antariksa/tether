import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tether/features/safety/data/geolocator_sos_location.dart';

Position at(DateTime t) => Position(
  longitude: 106.8456,
  latitude: -6.2088,
  timestamp: t,
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
  hasAccuracy: true,
);

void main() {
  final now = DateTime.utc(2026, 11, 5, 10);
  const maxAge = Duration(minutes: 10);

  test('posisi terakhir yang segar dipakai', () {
    final fix = GeolocatorSosLocation.fixFromLastKnown(
      at(now.subtract(const Duration(minutes: 9))),
      now,
      maxAge,
    );
    expect(fix!.lat, -6.2088);
    expect(fix.accuracyM, 12);
  });

  test('posisi terakhir lebih tua dari 10 menit ditolak', () {
    expect(
      GeolocatorSosLocation.fixFromLastKnown(
        at(now.subtract(const Duration(minutes: 11))),
        now,
        maxAge,
      ),
      isNull,
    );
  });

  test('batas bawaan 10 menit', () {
    expect(const GeolocatorSosLocation().maxLastKnownAge, maxAge);
  });
}
