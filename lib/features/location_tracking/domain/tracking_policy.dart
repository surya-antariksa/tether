enum TrackingMode { stationary, moving, batterySaver }

/// Kebijakan pelacakan adaptif (ADR-007). Murni, tanpa efek samping.
/// Semua angka di bawah awal dan perlu kalibrasi di Sprint 0B.
class TrackingPolicy {
  const TrackingPolicy._();

  /// Perlu kalibrasi di Sprint 0B.
  static const double movingSpeedThresholdMps = 1.5;

  /// Perlu kalibrasi di Sprint 0B.
  static const int lowBatteryThresholdPct = 15;

  /// Perlu kalibrasi di Sprint 0B.
  static const Duration movingInterval = Duration(seconds: 20);

  /// Perlu kalibrasi di Sprint 0B.
  static const Duration stationaryInterval = Duration(minutes: 15);

  /// Perlu kalibrasi di Sprint 0B.
  static const Duration batterySaverInterval = Duration(minutes: 5);

  /// Perlu kalibrasi di Sprint 0B.
  static const double movingDistanceFilterM = 25;

  /// Perlu kalibrasi di Sprint 0B.
  static const double stationaryDistanceFilterM = 100;

  /// Perlu kalibrasi di Sprint 0B.
  static const double batterySaverDistanceFilterM = 100;

  /// Baterai rendah menang atas mode lain. Nilai null (tidak diketahui)
  /// diabaikan: kecepatan null dianggap diam.
  static TrackingMode modeFor(double? speedMps, int? batteryPct) {
    if (batteryPct != null && batteryPct < lowBatteryThresholdPct) {
      return TrackingMode.batterySaver;
    }
    if (speedMps != null && speedMps >= movingSpeedThresholdMps) {
      return TrackingMode.moving;
    }
    return TrackingMode.stationary;
  }

  static Duration intervalFor(TrackingMode mode) => switch (mode) {
    TrackingMode.moving => movingInterval,
    TrackingMode.stationary => stationaryInterval,
    TrackingMode.batterySaver => batterySaverInterval,
  };

  static double distanceFilterFor(TrackingMode mode) => switch (mode) {
    TrackingMode.moving => movingDistanceFilterM,
    TrackingMode.stationary => stationaryDistanceFilterM,
    TrackingMode.batterySaver => batterySaverDistanceFilterM,
  };
}
