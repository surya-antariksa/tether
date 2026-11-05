import 'dart:async';

import '../../location_tracking/data/simulated_location_source.dart';
import '../../location_tracking/domain/location_point.dart';
import '../../location_tracking/domain/location_source.dart';

/// Simulasi rute uji yang berulang dari awal sampai [stop], supaya layanan
/// pelacakan tetap berjalan (rute spike hanya sekali jalan).
class LoopingSimulatedSource implements LocationSource {
  LoopingSimulatedSource({
    Duration interval = const Duration(seconds: 3),
    SimulatedLocationSource Function(void Function() onCompleted)? factory,
  }) {
    _inner =
        factory?.call(_again) ??
        SimulatedLocationSource(interval: interval, onCompleted: _again);
  }

  late final SimulatedLocationSource _inner;
  bool _running = false;

  void _again() {
    if (_running) unawaited(_inner.start());
  }

  @override
  Stream<LocationPoint> get points => _inner.points;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _inner.start();
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _inner.stop();
  }
}
