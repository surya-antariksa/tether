import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/history/data/supabase_history_repository.dart';

void main() {
  group('parseHistoryRow', () {
    test('GeoJSON dan kolom lain dipetakan', () {
      final p = parseHistoryRow({
        'point': {
          'type': 'Point',
          'coordinates': [106.8167, -6.2],
        },
        'recorded_at': '2026-11-05T02:30:00+00:00',
        'accuracy_m': 12.5,
        'is_moving': true,
      });
      expect(p, isNotNull);
      expect(p!.point.latitude, -6.2);
      expect(p.point.longitude, 106.8167);
      expect(p.recordedAt.toUtc(), DateTime.utc(2026, 11, 5, 2, 30));
      expect(p.accuracyM, 12.5);
      expect(p.isMoving, isTrue);
    });

    test('EWKB hex dari PostgREST diurai', () {
      // Point(106.8167 -6.2) SRID 4326, little endian (EWKB).
      final p = parseHistoryRow({
        'point':
            '0101000020E6100000'
            '${_f64le(106.8167)}${_f64le(-6.2)}',
        'recorded_at': '2026-11-05T02:30:00Z',
        'accuracy_m': null,
        'is_moving': false,
      });
      expect(p, isNotNull);
      expect(p!.point.latitude, closeTo(-6.2, 1e-9));
      expect(p.point.longitude, closeTo(106.8167, 1e-9));
      expect(p.accuracyM, isNull);
      expect(p.isMoving, isFalse);
    });

    test('titik atau waktu tidak sah -> null', () {
      expect(
        parseHistoryRow({'point': null, 'recorded_at': '2026-11-05T02:30:00Z'}),
        isNull,
      );
      expect(
        parseHistoryRow({
          'point': {
            'type': 'Point',
            'coordinates': [106.8, -6.2],
          },
          'recorded_at': 'bukan-waktu',
        }),
        isNull,
      );
    });
  });
}

String _f64le(double v) {
  final b = (ByteData(8)..setFloat64(0, v, Endian.little)).buffer.asUint8List();
  return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}
