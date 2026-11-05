import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/domain/tracking_policy.dart';
import 'package:tether/features/tracking/domain/tracking_mode_governor.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('gerak', () {
    test('awalnya diam', () {
      expect(TrackingModeGovernor().mode, TrackingMode.stationary);
    });

    test('masuk mode bergerak segera saat melewati ambang', () {
      final g = TrackingModeGovernor();
      expect(g.onSample(speedMps: 1.5, at: at(0)), isTrue);
      expect(g.mode, TrackingMode.moving);
    });

    test('di bawah ambang tidak mengubah mode', () {
      final g = TrackingModeGovernor();
      expect(g.onSample(speedMps: 1.49, at: at(0)), isFalse);
      expect(g.onSample(speedMps: null, at: at(1)), isFalse);
      expect(g.mode, TrackingMode.stationary);
    });

    test('sampel cepat berikutnya tidak melaporkan perubahan', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 3, at: at(0));
      expect(g.onSample(speedMps: 3, at: at(10)), isFalse);
      expect(g.mode, TrackingMode.moving);
    });

    test('histeresis: tetap bergerak sebelum movingHold habis', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 3, at: at(0));
      expect(g.onSample(speedMps: 0, at: at(119)), isFalse);
      expect(g.mode, TrackingMode.moving);
    });

    test('keluar tepat saat movingHold terpenuhi', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 3, at: at(0));
      expect(g.onSample(speedMps: 0, at: at(120)), isTrue);
      expect(g.mode, TrackingMode.stationary);
    });

    test('sampel cepat memperpanjang masa tahan', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 3, at: at(0));
      g.onSample(speedMps: 3, at: at(100));
      expect(g.onSample(speedMps: 0, at: at(200)), isFalse);
      expect(g.mode, TrackingMode.moving);
      expect(g.onSample(speedMps: 0, at: at(220)), isTrue);
      expect(g.mode, TrackingMode.stationary);
    });

    test('onQuiet menurunkan mode setelah movingHold tanpa titik', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 3, at: at(0));
      expect(g.onQuiet(at(60)), isFalse);
      expect(g.onQuiet(at(120)), isTrue);
      expect(g.mode, TrackingMode.stationary);
      expect(g.onQuiet(at(500)), isFalse);
    });

    test('movingHold bisa diatur', () {
      final g = TrackingModeGovernor(movingHold: const Duration(seconds: 10));
      g.onSample(speedMps: 3, at: at(0));
      expect(g.onQuiet(at(9)), isFalse);
      expect(g.onQuiet(at(10)), isTrue);
    });
  });

  group('baterai', () {
    test('masuk mode hemat hanya di bawah 15 persen', () {
      final g = TrackingModeGovernor();
      expect(g.onSample(batteryPct: 15, at: at(0)), isFalse);
      expect(g.mode, TrackingMode.stationary);
      expect(g.onSample(batteryPct: 14, at: at(1)), isTrue);
      expect(g.mode, TrackingMode.batterySaver);
    });

    test('histeresis: keluar baru saat baterai mencapai 20 persen', () {
      final g = TrackingModeGovernor();
      g.onSample(batteryPct: 10, at: at(0));
      expect(g.onSample(batteryPct: 15, at: at(1)), isFalse);
      expect(g.onSample(batteryPct: 19, at: at(2)), isFalse);
      expect(g.mode, TrackingMode.batterySaver);
      expect(g.onSample(batteryPct: 20, at: at(3)), isTrue);
      expect(g.mode, TrackingMode.stationary);
    });

    test('baterai tidak diketahui tidak mengubah keadaan', () {
      final g = TrackingModeGovernor();
      g.onSample(batteryPct: 5, at: at(0));
      expect(g.onSample(batteryPct: null, at: at(1)), isFalse);
      expect(g.mode, TrackingMode.batterySaver);
    });

    test('mode hemat menang atas bergerak', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 5, at: at(0));
      expect(g.mode, TrackingMode.moving);
      expect(g.onSample(speedMps: 5, batteryPct: 10, at: at(1)), isTrue);
      expect(g.mode, TrackingMode.batterySaver);
    });

    test(
      'keluar dari mode hemat kembali ke bergerak bila masih dalam masa tahan',
      () {
        final g = TrackingModeGovernor();
        g.onSample(speedMps: 5, batteryPct: 10, at: at(0));
        expect(g.mode, TrackingMode.batterySaver);
        expect(g.onSample(speedMps: 0, batteryPct: 50, at: at(30)), isTrue);
        expect(g.mode, TrackingMode.moving);
      },
    );

    test('keluar dari mode hemat ke diam bila masa tahan lewat', () {
      final g = TrackingModeGovernor();
      g.onSample(speedMps: 5, batteryPct: 10, at: at(0));
      g.onSample(speedMps: 0, batteryPct: 50, at: at(300));
      expect(g.mode, TrackingMode.stationary);
    });

    test('ambang keluar bisa diatur', () {
      final g = TrackingModeGovernor(lowBatteryExitPct: 30);
      g.onSample(batteryPct: 10, at: at(0));
      expect(g.onSample(batteryPct: 29, at: at(1)), isFalse);
      expect(g.onSample(batteryPct: 30, at: at(2)), isTrue);
    });

    test('onQuiet tidak mengubah mode hemat', () {
      final g = TrackingModeGovernor();
      g.onSample(batteryPct: 5, at: at(0));
      expect(g.onQuiet(at(1000)), isFalse);
      expect(g.mode, TrackingMode.batterySaver);
    });
  });
}
