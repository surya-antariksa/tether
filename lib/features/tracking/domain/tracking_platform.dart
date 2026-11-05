import 'package:flutter/foundation.dart';

/// Kelompok platform untuk memilih sumber lokasi dan gateway izin.
enum TrackingPlatform { android, ios, desktop }

TrackingPlatform currentTrackingPlatform() {
  if (kIsWeb) return TrackingPlatform.desktop;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => TrackingPlatform.android,
    TargetPlatform.iOS => TrackingPlatform.ios,
    _ => TrackingPlatform.desktop,
  };
}

enum LocationSourceKind { geolocator, simulated, unavailable }

/// Flag build `--dart-define=SIMULATE_LOCATION=true`.
const bool simulateLocationFlag = bool.fromEnvironment('SIMULATE_LOCATION');

/// Simulasi hanya boleh di build debug atau dengan flag.
bool get simulationAllowedByBuild => kDebugMode || simulateLocationFlag;

/// Memilih sumber lokasi. Simulasi menang bila diizinkan dan sedang aktif.
/// Android/iOS memakai GPS; desktop tanpa simulasi tidak punya sumber.
LocationSourceKind chooseLocationSourceKind({
  required TrackingPlatform platform,
  required bool simulationAllowed,
  required bool simulationActive,
}) {
  if (simulationAllowed && simulationActive) {
    return LocationSourceKind.simulated;
  }
  return switch (platform) {
    TrackingPlatform.android ||
    TrackingPlatform.ios => LocationSourceKind.geolocator,
    TrackingPlatform.desktop => LocationSourceKind.unavailable,
  };
}
