import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/data/simulated_location_source.dart';
import 'package:tether/features/location_tracking/domain/geo.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';

double _distToPlace(LocationPoint p) =>
    haversineMeters(p.lat, p.lng, testPlaceLat, testPlaceLng);

/// Memutar satu rute penuh dengan waktu palsu dan mengumpulkan titiknya.
({List<LocationPoint> points, int completed}) _runFull({
  List<Waypoint>? route,
  double speedMps = 10,
  Duration interval = const Duration(seconds: 3),
}) {
  final points = <LocationPoint>[];
  var completed = 0;
  final base = DateTime.utc(2026, 1, 1);
  FakeAsync().run((async) {
    final source = SimulatedLocationSource(
      route: route,
      speedMps: speedMps,
      interval: interval,
      now: () => base.add(async.elapsed),
      onCompleted: () => completed++,
    );
    source.points.listen(points.add);
    source.start();
    async.elapse(interval * (source.plannedPointCount + 5));
  });
  return (points: points, completed: completed);
}

void main() {
  group('geo', () {
    test('offsetByMeters sesuai haversine di utara dan timur', () {
      final n = offsetByMeters(testPlaceLat, testPlaceLng, northM: 600);
      final e = offsetByMeters(testPlaceLat, testPlaceLng, eastM: 600);
      expect(
        haversineMeters(testPlaceLat, testPlaceLng, n.lat, n.lng),
        closeTo(600, 2),
      );
      expect(
        haversineMeters(testPlaceLat, testPlaceLng, e.lat, e.lng),
        closeTo(600, 2),
      );
    });

    test('1 derajat lintang sekitar 111 km', () {
      expect(haversineMeters(0, 0, 1, 0), closeTo(111195, 200));
    });
  });

  group('SimulatedLocationSource', () {
    test('jumlah titik sama dengan rencana, waktu naik ketat', () {
      final r = _runFull();
      final source = SimulatedLocationSource();
      expect(r.points.length, source.plannedPointCount);
      expect(r.points.length, greaterThan(30));
      for (var i = 1; i < r.points.length; i++) {
        expect(
          r.points[i].recordedAt.isAfter(r.points[i - 1].recordedAt),
          isTrue,
        );
      }
      expect(r.points.every((p) => p.recordedAt.isUtc), isTrue);
    });

    test('geometri: awal dan akhir di luar radius, tengah di dalam', () {
      final pts = _runFull().points;
      expect(_distToPlace(pts.first), closeTo(600, 5));
      expect(_distToPlace(pts.first), greaterThan(testPlaceRadiusM));
      expect(_distToPlace(pts.last), closeTo(600, 5));
      expect(_distToPlace(pts.last), greaterThan(testPlaceRadiusM));

      final inside = pts.indexed.where(
        (e) => _distToPlace(e.$2) < testPlaceRadiusM,
      );
      expect(inside, isNotEmpty);
      // Titik diam di tengah: minimal 2 titik berturut-turut di dalam radius.
      expect(inside.length, greaterThanOrEqualTo(2));
      expect(
        inside.map((e) => e.$1).reduce((a, b) => b) -
            inside.map((e) => e.$1).reduce((a, b) => a < b ? a : b) +
            1,
        inside.length,
        reason: 'titik di dalam radius harus berurutan',
      );
      // Ada titik yang tepat di tengah dan diam.
      final center = pts.where((p) => _distToPlace(p) < 1);
      expect(center.length, 5); // tiba + 4 titik diam
      expect(center.every((p) => !p.isMoving && p.speedMps == 0), isTrue);
    });

    test(
      'kecepatan konstan: jarak antar titik bergerak tidak melebihi langkah',
      () {
        final pts = _runFull().points;
        for (var i = 1; i < pts.length; i++) {
          final d = haversineMeters(
            pts[i - 1].lat,
            pts[i - 1].lng,
            pts[i].lat,
            pts[i].lng,
          );
          expect(d, lessThanOrEqualTo(30.5));
        }
        expect(
          pts.where((p) => p.isMoving).every((p) => p.speedMps == 10),
          isTrue,
        );
      },
    );

    test('onCompleted sekali dan tidak ada titik setelah rute selesai', () {
      final r = _runFull();
      expect(r.completed, 1);
    });

    test('ticker injeksi: satu titik per tick', () {
      fakeAsync((async) {
        final ticks = StreamController<void>();
        final got = <LocationPoint>[];
        final source = SimulatedLocationSource(
          route: const [Waypoint(-6.2, 106.8167), Waypoint(-6.2, 106.8267)],
          ticker: (_) => ticks.stream,
        );
        source.points.listen(got.add);
        source.start();
        async.flushMicrotasks();
        expect(got.length, 1);
        ticks.add(null);
        async.flushMicrotasks();
        expect(got.length, 2);
      });
    });

    test('stop menghentikan titik', () {
      final got = <LocationPoint>[];
      fakeAsync((async) {
        final source = SimulatedLocationSource();
        source.points.listen(got.add);
        source.start();
        async.elapse(const Duration(seconds: 7));
        final n = got.length;
        source.stop();
        async.elapse(const Duration(seconds: 60));
        expect(got.length, n);
      });
    });
  });
}
