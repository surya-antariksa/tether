import '../../location_tracking/data/simulated_location_source.dart';
import '../domain/sos_location.dart';
import '../domain/sos_models.dart';

/// Posisi SOS tetap di titik uji, untuk build uji di desktop atau dengan
/// --dart-define=SIMULATE_LOCATION=true (geolocator tidak punya lokasi di
/// Linux). Tidak pernah dipakai di build rilis tanpa flag itu.
class SimulatedSosLocation implements SosLocationProvider {
  const SimulatedSosLocation();

  static const _fix = SosFix(
    lat: testPlaceLat,
    lng: testPlaceLng,
    accuracyM: 10,
  );

  @override
  Future<SosFix?> current() async => _fix;

  @override
  Future<SosFix?> lastKnown() async => _fix;
}
