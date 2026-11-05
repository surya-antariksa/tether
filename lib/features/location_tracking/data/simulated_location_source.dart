import 'dart:async';

import '../domain/geo.dart';
import '../domain/location_point.dart';
import '../domain/location_source.dart';

/// Place uji "Titik Uji" untuk geofence (dibuat di server pada T0.5).
const double testPlaceLat = -6.2000;
const double testPlaceLng = 106.8167;
const double testPlaceRadiusM = 150;

/// Titik jalur. [holdPoints] = jumlah titik diam tambahan saat tiba di sini.
class Waypoint {
  const Waypoint(this.lat, this.lng, {this.holdPoints = 0});

  final double lat;
  final double lng;
  final int holdPoints;
}

/// Rute bawaan: mulai 600 m di selatan place uji, masuk sampai ke tengah,
/// diam 4 titik, lalu keluar 600 m ke timur.
List<Waypoint> defaultTestRoute() {
  final start = offsetByMeters(testPlaceLat, testPlaceLng, northM: -600);
  final end = offsetByMeters(testPlaceLat, testPlaceLng, eastM: 600);
  return [
    Waypoint(start.lat, start.lng),
    const Waypoint(testPlaceLat, testPlaceLng, holdPoints: 4),
    Waypoint(end.lat, end.lng),
  ];
}

typedef TickerFactory = Stream<void> Function(Duration interval);

/// Memutar rute dari waypoint dengan kecepatan konstan, satu titik per tick.
/// Titik pertama dikirim saat [start], sisanya tiap [interval].
class SimulatedLocationSource implements LocationSource {
  SimulatedLocationSource({
    List<Waypoint>? route,
    this.speedMps = 10,
    this.interval = const Duration(seconds: 3),
    this.batteryPct = 80,
    this.accuracyM = 5,
    DateTime Function()? now,
    TickerFactory? ticker,
    this.onCompleted,
  }) : _now = now ?? DateTime.now,
       _ticker = ticker ?? Stream<void>.periodic,
       _samples = _plan(
         route ?? defaultTestRoute(),
         speedMps * interval.inMilliseconds / 1000,
       );

  final double speedMps;
  final Duration interval;
  final int batteryPct;
  final double accuracyM;
  final DateTime Function() _now;
  final TickerFactory _ticker;

  /// Dipanggil sekali setelah titik terakhir dikirim.
  final void Function()? onCompleted;

  final List<_Sample> _samples;
  final _controller = StreamController<LocationPoint>.broadcast();
  StreamSubscription<void>? _sub;
  int _next = 0;

  /// Jumlah titik yang akan dihasilkan satu putaran rute penuh.
  int get plannedPointCount => _samples.length;

  @override
  Stream<LocationPoint> get points => _controller.stream;

  @override
  Future<void> start() async {
    if (_sub != null) return;
    _next = 0;
    _emit();
    _sub = _ticker(interval).listen((_) => _emit());
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _emit() {
    if (_next >= _samples.length) return;
    final s = _samples[_next++];
    _controller.add(
      LocationPoint(
        lat: s.lat,
        lng: s.lng,
        accuracyM: accuracyM,
        speedMps: s.moving ? speedMps : 0,
        batteryPct: batteryPct,
        isMoving: s.moving,
        recordedAt: _now(),
      ),
    );
    if (_next >= _samples.length) {
      stop();
      // Tunda: event terakhir pada broadcast stream dikirim asinkron. Bila
      // onCompleted (mis. stop pemanggil) membatalkan langganan lebih dulu,
      // titik terakhir terbuang.
      final done = onCompleted;
      if (done != null) Timer.run(done);
    }
  }

  /// Rencana titik per ruas: dari waypoint sebelumnya, maju sejauh [stepM]
  /// per titik, lalu titik tiba di waypoint dan titik diam bila ada hold.
  static List<_Sample> _plan(List<Waypoint> route, double stepM) {
    if (route.isEmpty || stepM <= 0) return const [];
    final out = <_Sample>[
      _Sample(route.first.lat, route.first.lng, moving: false),
      for (var i = 0; i < route.first.holdPoints; i++)
        _Sample(route.first.lat, route.first.lng, moving: false),
    ];
    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1];
      final b = route[i];
      final len = haversineMeters(a.lat, a.lng, b.lat, b.lng);
      for (var d = stepM; d < len; d += stepM) {
        final t = d / len;
        out.add(
          _Sample(
            a.lat + (b.lat - a.lat) * t,
            a.lng + (b.lng - a.lng) * t,
            moving: true,
          ),
        );
      }
      final hold = b.holdPoints;
      out.add(_Sample(b.lat, b.lng, moving: hold == 0 && i < route.length - 1));
      for (var h = 0; h < hold; h++) {
        out.add(_Sample(b.lat, b.lng, moving: false));
      }
    }
    return out;
  }
}

class _Sample {
  const _Sample(this.lat, this.lng, {required this.moving});

  final double lat;
  final double lng;
  final bool moving;
}
