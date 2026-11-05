import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/places/data/place_mappers.dart';
import 'package:tether/features/places/domain/place.dart';
import 'package:tether/features/places/domain/place_error.dart';
import 'package:tether/features/places/presentation/place_strings.dart';

import 'fake_place_repository.dart';

// EWKB hex titik (lon 106.8456, lat -6.2088) SRID 4326, bentuk bawaan PostgREST.
String _ewkb(double lon, double lat) {
  final b = ByteData(25);
  b.setUint8(0, 1);
  b.setUint32(1, 0x20000001, Endian.little);
  b.setUint32(5, 4326, Endian.little);
  b.setFloat64(9, lon, Endian.little);
  b.setFloat64(17, lat, Endian.little);
  return [
    for (var i = 0; i < 25; i++)
      b.getUint8(i).toRadixString(16).padLeft(2, '0'),
  ].join().toUpperCase();
}

void main() {
  group('validatePlaceName', () {
    test('kosong dan spasi saja ditolak', () {
      expect(validatePlaceName(''), PlaceNameIssue.empty);
      expect(validatePlaceName('   '), PlaceNameIssue.empty);
    });

    test('1 sampai 40 karakter setelah dipangkas diterima', () {
      expect(validatePlaceName('R'), isNull);
      expect(validatePlaceName(' ${'a' * 40} '), isNull);
    });

    test('41 karakter ditolak', () {
      expect(validatePlaceName('a' * 41), PlaceNameIssue.tooLong);
    });

    test('dihitung per code point seperti char_length di database', () {
      expect(validatePlaceName('😀' * 40), isNull);
      expect(validatePlaceName('😀' * 41), PlaceNameIssue.tooLong);
    });
  });

  test('batas sama dengan kontrak database', () {
    expect(PlaceLimits.maxPerCircle, 5);
    expect(PlaceLimits.minRadiusM, 100);
    expect(PlaceLimits.maxRadiusM, 5000);
    expect(PlaceLimits.nameMaxLength, 40);
    expect(
      PlaceLimits.defaultRadiusM,
      inInclusiveRange(PlaceLimits.minRadiusM, PlaceLimits.maxRadiusM),
    );
    expect(
      (PlaceLimits.maxRadiusM - PlaceLimits.minRadiusM) %
          PlaceLimits.radiusStepM,
      0,
    );
  });

  test('formatRadius memakai meter lalu kilometer dengan koma', () {
    expect(formatRadius(100), '100 m');
    expect(formatRadius(950), '950 m');
    expect(formatRadius(1000), '1 km');
    expect(formatRadius(1500), '1,5 km');
    expect(formatRadius(5000), '5 km');
  });

  group('canManage', () {
    final mine = placeOf('p', createdBy: 'u1');
    final others = placeOf('p', createdBy: 'u2');
    final orphan = placeOf('p', createdBy: null);

    test('pembuat boleh, anggota lain tidak', () {
      expect(mine.canManage(userId: 'u1', isAdmin: false), isTrue);
      expect(others.canManage(userId: 'u1', isAdmin: false), isFalse);
    });

    test('admin boleh semua, termasuk tempat tanpa pembuat', () {
      expect(others.canManage(userId: 'u1', isAdmin: true), isTrue);
      expect(orphan.canManage(userId: 'u1', isAdmin: true), isTrue);
    });

    test('tanpa pembuat dan bukan admin: tidak boleh; tanpa user: tidak', () {
      expect(orphan.canManage(userId: 'u1', isAdmin: false), isFalse);
      expect(orphan.canManage(userId: null, isAdmin: false), isFalse);
    });
  });

  group('placeFromRow', () {
    Map<String, dynamic> row({Object? center, Object? radius = 200}) => {
      'id': 'p1',
      'circle_id': 'c1',
      'name': 'Rumah',
      'center': center ?? _ewkb(106.8456, -6.2088),
      'radius_m': radius,
      'created_by': 'u1',
    };

    test('mengurai EWKB hex', () {
      final p = placeFromRow(row())!;
      expect(p.id, 'p1');
      expect(p.circleId, 'c1');
      expect(p.name, 'Rumah');
      expect(p.radiusM, 200);
      expect(p.createdBy, 'u1');
      expect(p.center.latitude, closeTo(-6.2088, 1e-9));
      expect(p.center.longitude, closeTo(106.8456, 1e-9));
    });

    test('mengurai GeoJSON', () {
      final p = placeFromRow(
        row(
          center: {
            'type': 'Point',
            'coordinates': [106.8, -6.2],
          },
        ),
      )!;
      expect(p.center.longitude, 106.8);
    });

    test('baris tidak valid menjadi null', () {
      expect(placeFromRow(row(center: 'bukan-titik')), isNull);
      expect(placeFromRow(row(radius: null)), isNull);
      expect(placeFromRow({...row(), 'name': null}), isNull);
    });

    test('created_by null diterima', () {
      expect(placeFromRow({...row(), 'created_by': null})!.createdBy, isNull);
    });
  });

  group('mapPlaceError', () {
    PostgrestException pg(String code, [String message = 'x']) =>
        PostgrestException(message: message, code: code);

    test('kode galat database menjadi jenis galat', () {
      expect(mapPlaceError(pg('TH005')).kind, PlaceErrorKind.limitReached);
      expect(mapPlaceError(pg('P0002')).kind, PlaceErrorKind.notFound);
      expect(mapPlaceError(pg('22023')).kind, PlaceErrorKind.invalid);
      expect(mapPlaceError(pg('28000')).kind, PlaceErrorKind.notSignedIn);
      expect(mapPlaceError(pg('XX000')).kind, PlaceErrorKind.unknown);
    });

    test('42501 bergantung operasi', () {
      expect(mapPlaceError(pg('42501')).kind, PlaceErrorKind.notAllowed);
      expect(
        mapPlaceError(pg('42501'), forbidden: PlaceErrorKind.notMember).kind,
        PlaceErrorKind.notMember,
      );
    });

    test('galat jaringan', () {
      expect(
        mapPlaceError(const SocketException('x')).kind,
        PlaceErrorKind.network,
      );
      expect(mapPlaceError(Exception('lain')).kind, PlaceErrorKind.unknown);
    });

    test('PlaceError diteruskan apa adanya', () {
      const e = PlaceError(PlaceErrorKind.limitReached);
      expect(identical(mapPlaceError(e), e), isTrue);
    });

    test('pesan asli (bisa memuat data) tidak ikut di hasil', () {
      final e = mapPlaceError(pg('22023', 'titik -6.2088,106.8456'));
      expect(e.toString(), isNot(contains('6.2088')));
    });
  });

  group('PlaceStrings.error', () {
    test('semua jenis galat punya pesan Indonesia tanpa koordinat', () {
      for (final k in PlaceErrorKind.values) {
        final m = PlaceStrings.error(k);
        expect(m, isNotEmpty);
        expect(m, isNot(matches(RegExp(r'\d+\.\d{3,}'))));
      }
      expect(
        PlaceStrings.error(PlaceErrorKind.limitReached),
        contains('5 tempat'),
      );
    });
  });
}
