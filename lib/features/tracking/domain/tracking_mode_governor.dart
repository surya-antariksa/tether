import '../../location_tracking/domain/tracking_policy.dart';

/// Memilih mode pelacakan adaptif dengan histeresis supaya pengaturan stream
/// tidak bolak-balik (ADR-007). Murni, tanpa efek samping.
///
/// - Baterai: masuk mode hemat di bawah [TrackingPolicy.lowBatteryThresholdPct],
///   keluar baru saat baterai >= [lowBatteryExitPct].
/// - Gerak: masuk mode bergerak segera saat kecepatan melewati ambang, keluar
///   baru bila tidak ada kecepatan di atas ambang selama [movingHold].
/// Semua angka awal dan perlu kalibrasi di Sprint 0B.
class TrackingModeGovernor {
  TrackingModeGovernor({
    this.movingHold = const Duration(minutes: 2),
    this.lowBatteryExitPct = 20,
  });

  final Duration movingHold;
  final int lowBatteryExitPct;

  bool _lowBattery = false;
  DateTime? _lastFastAt;
  TrackingMode _mode = TrackingMode.stationary;

  TrackingMode get mode => _mode;

  /// Memproses satu titik. Mengembalikan true bila mode berubah.
  bool onSample({double? speedMps, int? batteryPct, required DateTime at}) {
    if (batteryPct != null) {
      if (batteryPct < TrackingPolicy.lowBatteryThresholdPct) {
        _lowBattery = true;
      } else if (batteryPct >= lowBatteryExitPct) {
        _lowBattery = false;
      }
    }
    if (speedMps != null &&
        speedMps >= TrackingPolicy.movingSpeedThresholdMps) {
      _lastFastAt = at;
    }
    return _update(at);
  }

  /// Dipanggil saat lama tidak ada titik (mis. berhenti bergerak sehingga
  /// filter jarak tidak menghasilkan kejadian). Mengembalikan true bila berubah.
  bool onQuiet(DateTime now) => _update(now);

  bool _update(DateTime at) {
    final next = _lowBattery
        ? TrackingMode.batterySaver
        : (_lastFastAt != null && at.difference(_lastFastAt!) < movingHold)
        ? TrackingMode.moving
        : TrackingMode.stationary;
    final changed = next != _mode;
    _mode = next;
    return changed;
  }
}
