import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/map/domain/vehicle_type.dart';

void main() {
  group('detectVehicle & speedMpsToKmh', () {
    test('tidak bergerak: none terlepas dari kecepatan', () {
      expect(detectVehicle(speedMps: 15.0, isMoving: false), VehicleType.none);
      expect(detectVehicle(speedMps: null, isMoving: false), VehicleType.none);
    });

    test('kecepatan null: none', () {
      expect(detectVehicle(speedMps: null, isMoving: true), VehicleType.none);
    });

    test('kecepatan sangat rendah (< 1.5 km/jam): none (diam)', () {
      // 0.3 m/s = 1.08 km/jam
      expect(detectVehicle(speedMps: 0.3, isMoving: true), VehicleType.none);
    });

    test('kecepatan jalan kaki (1.5 - <15 km/jam): walking', () {
      // 1.5 m/s = 5.4 km/jam
      expect(detectVehicle(speedMps: 1.5, isMoving: true), VehicleType.walking);
      // 3.0 m/s = 10.8 km/jam
      expect(detectVehicle(speedMps: 3.0, isMoving: true), VehicleType.walking);
    });

    test('kecepatan motor (15 - <45 km/jam): motorcycle', () {
      // 5.0 m/s = 18.0 km/jam
      expect(
        detectVehicle(speedMps: 5.0, isMoving: true),
        VehicleType.motorcycle,
      );
      // 10.0 m/s = 36.0 km/jam
      expect(
        detectVehicle(speedMps: 10.0, isMoving: true),
        VehicleType.motorcycle,
      );
    });

    test('kecepatan mobil (>= 45 km/jam): car', () {
      // 15.0 m/s = 54.0 km/jam
      expect(detectVehicle(speedMps: 15.0, isMoving: true), VehicleType.car);
      // 25.0 m/s = 90.0 km/jam
      expect(detectVehicle(speedMps: 25.0, isMoving: true), VehicleType.car);
    });

    test('speedMpsToKmh dan formatSpeedKmh', () {
      expect(speedMpsToKmh(null), isNull);
      expect(speedMpsToKmh(10.0), closeTo(36.0, 0.01));
      expect(formatSpeedKmh(36.4), '36 km/jam');
      expect(formatSpeedKmh(36.6), '37 km/jam');
    });

    test('VehicleType isDriving dan label', () {
      expect(VehicleType.motorcycle.isDriving, isTrue);
      expect(VehicleType.car.isDriving, isTrue);
      expect(VehicleType.walking.isDriving, isFalse);
      expect(VehicleType.none.isDriving, isFalse);

      expect(VehicleType.motorcycle.label, 'Motor');
      expect(VehicleType.car.label, 'Mobil');
      expect(VehicleType.walking.label, 'Berjalan');
      expect(VehicleType.none.label, 'Diam');
    });
  });
}
