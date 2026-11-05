import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/data/simulated_location_source.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';
import 'package:tether/features/tracking/data/looping_simulated_source.dart';

/// Rute pendek (sekitar 100 m, langkah 30 m): 5 titik per putaran.
const _route = [Waypoint(-6.2000, 106.8167), Waypoint(-6.2009, 106.8167)];

void main() {
  late StreamController<void> ticks;
  late int tickerCalls;
  late LoopingSimulatedSource source;
  late List<LocationPoint> received;

  setUp(() {
    ticks = StreamController<void>.broadcast();
    tickerCalls = 0;
    received = [];
    source = LoopingSimulatedSource(
      factory: (onCompleted) => SimulatedLocationSource(
        route: _route,
        speedMps: 10,
        interval: const Duration(seconds: 3),
        ticker: (_) {
          tickerCalls++;
          return ticks.stream;
        },
        onCompleted: onCompleted,
      ),
    );
    source.points.listen(received.add);
  });

  tearDown(() async {
    await source.stop();
    await ticks.close();
  });

  Future<void> tick([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      ticks.add(null);
      await pumpEventQueue();
    }
  }

  test('start langsung mengirim titik pertama rute', () async {
    await source.start();
    await pumpEventQueue();
    expect(received, hasLength(1));
    expect(received.first.lat, -6.2000);
  });

  test('start dua kali tidak memulai ulang rute', () async {
    await source.start();
    await source.start();
    await pumpEventQueue();
    expect(received, hasLength(1));
    expect(tickerCalls, 1);
  });

  test('rute berulang dari awal setelah selesai', () async {
    await source.start();
    await pumpEventQueue();
    final first = received.first;

    await tick(3);
    expect(received, hasLength(4));

    // Titik terakhir rute; onCompleted (Timer.run) memulai putaran baru.
    await tick();
    expect(
      received.map((p) => p.lat).toList().sublist(0, 5).last,
      closeTo(-6.2009, 1e-9),
    );
    expect(received, hasLength(6));
    expect(received.last.lat, first.lat);
    expect(received.last.lng, first.lng);
    expect(tickerCalls, 2);

    await tick(4);
    expect(received, hasLength(5 + 6));
    expect(tickerCalls, 3);
  });

  test('stop menghentikan titik berikutnya', () async {
    await source.start();
    await tick(2);
    expect(received, hasLength(3));

    await source.stop();
    await tick(5);
    await pumpEventQueue();
    expect(received, hasLength(3));
  });

  test('stop tepat saat rute selesai tidak memicu putaran baru', () async {
    await source.start();
    await tick(3);
    expect(received, hasLength(4));

    ticks.add(null); // titik terakhir, onCompleted terjadwal (Timer.run)
    await Future<void>.microtask(() {}); // tick terkirim, timer belum jalan
    await source.stop();
    await pumpEventQueue();

    expect(received, hasLength(5));
    expect(tickerCalls, 1);
  });

  test('bisa dimulai lagi sesudah stop', () async {
    await source.start();
    await tick(1);
    await source.stop();

    await source.start();
    await pumpEventQueue();
    expect(received, hasLength(3));
    expect(received.last.lat, -6.2000);
    expect(tickerCalls, 2);
  });

  test('tanpa factory memakai sumber simulasi bawaan', () async {
    final s = LoopingSimulatedSource();
    expect(s.points, isA<Stream<LocationPoint>>());
    await s.stop(); // aman dipanggil tanpa start
  });
}
