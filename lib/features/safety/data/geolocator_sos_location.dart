import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/sos_location.dart';
import '../domain/sos_models.dart';

/// Posisi SOS lewat geolocator. Semua galat (izin, GPS mati, platform tanpa
/// dukungan) menjadi null; tidak ada log agar koordinat tidak bocor. Posisi
/// terakhir yang lebih tua dari [maxLastKnownAge] ditolak: SOS tidak boleh
/// membawa lokasi basi tanpa penanda (lebih baik gagal jelas daripada
/// mengarahkan penolong ke tempat lama).
class GeolocatorSosLocation implements SosLocationProvider {
  const GeolocatorSosLocation({
    this.timeout = const Duration(seconds: 8),
    this.maxLastKnownAge = const Duration(minutes: 10),
  });

  final Duration timeout;
  final Duration maxLastKnownAge;

  @override
  Future<SosFix?> current() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _fix(p);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SosFix?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null
          ? null
          : fixFromLastKnown(p, DateTime.now(), maxLastKnownAge);
    } catch (_) {
      return null;
    }
  }

  /// Posisi terakhir dipakai hanya bila umurnya paling lama [maxAge].
  @visibleForTesting
  static SosFix? fixFromLastKnown(Position p, DateTime now, Duration maxAge) =>
      now.difference(p.timestamp) > maxAge ? null : _fix(p);

  static SosFix? _fix(Position p) {
    final fix = SosFix(
      lat: p.latitude,
      lng: p.longitude,
      accuracyM: (p.hasAccuracy || p.accuracy > 0) && p.accuracy >= 0
          ? p.accuracy
          : null,
    );
    return fix.isValid ? fix : null;
  }
}
