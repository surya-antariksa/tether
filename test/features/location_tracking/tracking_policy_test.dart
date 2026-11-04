import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/domain/tracking_policy.dart';

void main() {
  group('modeFor', () {
    test('batas kecepatan 1.5 m/s', () {
      expect(TrackingPolicy.modeFor(1.5, 80), TrackingMode.moving);
      expect(TrackingPolicy.modeFor(1.49, 80), TrackingMode.stationary);
      expect(TrackingPolicy.modeFor(0, 80), TrackingMode.stationary);
      expect(TrackingPolicy.modeFor(20, 80), TrackingMode.moving);
    });

    test('batas baterai 15 persen', () {
      expect(TrackingPolicy.modeFor(0, 14), TrackingMode.batterySaver);
      expect(TrackingPolicy.modeFor(0, 15), TrackingMode.stationary);
      expect(TrackingPolicy.modeFor(5, 15), TrackingMode.moving);
    });

    test('batterySaver menang atas bergerak', () {
      expect(TrackingPolicy.modeFor(10, 14), TrackingMode.batterySaver);
      expect(TrackingPolicy.modeFor(10, 0), TrackingMode.batterySaver);
    });

    test('nilai tidak diketahui diabaikan', () {
      expect(TrackingPolicy.modeFor(null, null), TrackingMode.stationary);
      expect(TrackingPolicy.modeFor(3, null), TrackingMode.moving);
      expect(TrackingPolicy.modeFor(null, 10), TrackingMode.batterySaver);
    });
  });

  test('interval per mode', () {
    expect(
      TrackingPolicy.intervalFor(TrackingMode.moving),
      const Duration(seconds: 20),
    );
    expect(
      TrackingPolicy.intervalFor(TrackingMode.stationary),
      const Duration(minutes: 15),
    );
    expect(
      TrackingPolicy.intervalFor(TrackingMode.batterySaver),
      const Duration(minutes: 5),
    );
  });

  test('distance filter per mode', () {
    expect(TrackingPolicy.distanceFilterFor(TrackingMode.moving), 25);
    expect(TrackingPolicy.distanceFilterFor(TrackingMode.stationary), 100);
    expect(TrackingPolicy.distanceFilterFor(TrackingMode.batterySaver), 100);
  });
}
