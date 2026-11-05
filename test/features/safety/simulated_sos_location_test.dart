import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/data/simulated_location_source.dart';
import 'package:tether/features/safety/data/simulated_sos_location.dart';

void main() {
  test('posisi simulasi SOS di titik uji dan valid', () async {
    const source = SimulatedSosLocation();
    final fix = await source.current();
    expect(fix, isNotNull);
    expect(fix!.lat, testPlaceLat);
    expect(fix.lng, testPlaceLng);
    expect(fix.isValid, isTrue);
    expect(await source.lastKnown(), isNotNull);
  });
}
