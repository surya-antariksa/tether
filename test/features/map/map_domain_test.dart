import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tether/features/map/domain/geography.dart';
import 'package:tether/features/map/domain/map_member.dart';
import 'package:tether/features/map/domain/paused_until.dart';
import 'package:tether/features/map/domain/presence.dart';
import 'package:tether/features/map/presentation/relative_time.dart';

/// EWKB hex Point: [order] 1 = little endian, 0 = big endian. [type] mentah
/// (bisa berisi flag SRID/Z/M), [extra] float64 tambahan setelah lon dan lat.
String ewkbHex({
  required double lon,
  required double lat,
  int order = 1,
  int type = 0x20000001,
  int? srid = 4326,
  List<double> extra = const [],
}) {
  final endian = order == 1 ? Endian.little : Endian.big;
  final b = BytesBuilder();
  b.addByte(order);
  final t = ByteData(4)..setUint32(0, type, endian);
  b.add(t.buffer.asUint8List());
  if (type & 0x20000000 != 0) {
    final s = ByteData(4)..setUint32(0, srid ?? 0, endian);
    b.add(s.buffer.asUint8List());
  }
  for (final v in [lon, lat, ...extra]) {
    final d = ByteData(8)..setFloat64(0, v, endian);
    b.add(d.buffer.asUint8List());
  }
  return [
    for (final byte in b.toBytes()) byte.toRadixString(16).padLeft(2, '0'),
  ].join().toUpperCase();
}

final t0 = DateTime.utc(2026, 11, 5, 12);

MapMember member({
  bool sharing = true,
  PausedUntil pause = PausedUntil.none,
  MemberLocation? location,
}) => MapMember(
  userId: 'u1',
  displayName: 'Rina',
  colorHex: '#0F766E',
  sharingEnabled: sharing,
  pause: pause,
  location: location,
);

MemberLocation seen(DateTime at) =>
    MemberLocation(point: const LatLng(-6.2, 106.8), lastSeenAt: at);

void main() {
  group('parseGeographyPoint', () {
    test('EWKB little endian dengan SRID (bentuk PostgREST)', () {
      // lon 1.0, lat 2.0, ditulis tangan agar tidak bergantung pada helper.
      final p = parseGeographyPoint(
        '0101000020E6100000000000000000F03F0000000000000040',
      );
      expect(p, const LatLng(2, 1));
    });

    test('EWKB hasil helper: koordinat nyata, huruf kecil, spasi tepi', () {
      final hex = ewkbHex(lon: 106.8456, lat: -6.2088);
      expect(parseGeographyPoint(hex), const LatLng(-6.2088, 106.8456));
      expect(parseGeographyPoint(hex.toLowerCase()), isNotNull);
      expect(parseGeographyPoint('  $hex \n'), const LatLng(-6.2088, 106.8456));
    });

    test('EWKB big endian', () {
      final hex = ewkbHex(lon: 10.5, lat: -20.25, order: 0);
      expect(parseGeographyPoint(hex), const LatLng(-20.25, 10.5));
    });

    test('WKB polos tanpa SRID', () {
      final hex = ewkbHex(lon: 3, lat: 4, type: 1);
      expect(parseGeographyPoint(hex), const LatLng(4, 3));
    });

    test('Point dengan dimensi Z dan M membaca lon lat dengan benar', () {
      final z = ewkbHex(lon: 5, lat: 6, type: 0xA0000001, extra: [100]);
      expect(parseGeographyPoint(z), const LatLng(6, 5));
      final zm = ewkbHex(lon: 7, lat: 8, type: 0xE0000001, extra: [1, 2]);
      expect(parseGeographyPoint(zm), const LatLng(8, 7));
    });

    test('Z yang dinyatakan tetapi byte kurang ditolak', () {
      final short = ewkbHex(lon: 5, lat: 6, type: 0xA0000001);
      expect(parseGeographyPoint(short), isNull);
    });

    test('bukan Point (LineString) ditolak', () {
      expect(
        parseGeographyPoint(ewkbHex(lon: 1, lat: 2, type: 0x20000002)),
        isNull,
      );
    });

    test('byte order tidak dikenal, hex rusak, terlalu pendek, ganjil', () {
      final ok = ewkbHex(lon: 1, lat: 2);
      expect(parseGeographyPoint('02${ok.substring(2)}'), isNull);
      expect(parseGeographyPoint('ZZ${ok.substring(2)}'), isNull);
      expect(parseGeographyPoint(ok.substring(0, 30)), isNull);
      expect(parseGeographyPoint('${ok}0'), isNull);
      expect(parseGeographyPoint(''), isNull);
    });

    test('di luar rentang atau tidak hingga ditolak', () {
      expect(parseGeographyPoint(ewkbHex(lon: 181, lat: 0)), isNull);
      expect(parseGeographyPoint(ewkbHex(lon: -181, lat: 0)), isNull);
      expect(parseGeographyPoint(ewkbHex(lon: 0, lat: 90.1)), isNull);
      expect(parseGeographyPoint(ewkbHex(lon: 0, lat: -90.1)), isNull);
      expect(parseGeographyPoint(ewkbHex(lon: double.nan, lat: 0)), isNull);
      expect(
        parseGeographyPoint(ewkbHex(lon: 0, lat: double.infinity)),
        isNull,
      );
    });

    test('batas rentang masih sah', () {
      expect(parseGeographyPoint(ewkbHex(lon: 180, lat: 90)), isNotNull);
      expect(parseGeographyPoint(ewkbHex(lon: -180, lat: -90)), isNotNull);
    });

    test(
      'GeoJSON: urutan [lon, lat], int diterima, dimensi ketiga diabaikan',
      () {
        expect(
          parseGeographyPoint({
            'type': 'Point',
            'coordinates': [106.8, -6.2],
          }),
          const LatLng(-6.2, 106.8),
        );
        expect(
          parseGeographyPoint({
            'type': 'Point',
            'coordinates': [1, 2, 30],
          }),
          const LatLng(2, 1),
        );
      },
    );

    test('GeoJSON tidak sah ditolak', () {
      expect(parseGeographyPoint({'type': 'LineString'}), isNull);
      expect(parseGeographyPoint({'type': 'Point'}), isNull);
      expect(
        parseGeographyPoint({
          'type': 'Point',
          'coordinates': [1],
        }),
        isNull,
      );
      expect(
        parseGeographyPoint({
          'type': 'Point',
          'coordinates': ['1', '2'],
        }),
        isNull,
      );
      expect(
        parseGeographyPoint({
          'type': 'Point',
          'coordinates': [200, 0],
        }),
        isNull,
      );
    });

    test('null dan tipe lain mengembalikan null', () {
      expect(parseGeographyPoint(null), isNull);
      expect(parseGeographyPoint(42), isNull);
      expect(parseGeographyPoint(<int>[1, 2]), isNull);
    });
  });

  group('PausedUntil', () {
    final now = DateTime.utc(2026, 11, 5, 12);

    test('parse: null dan non-string = tidak dijeda', () {
      expect(PausedUntil.parse(null).activeAt(now), isFalse);
      expect(PausedUntil.parse(7).activeAt(now), isFalse);
      expect(PausedUntil.parse(null).indefinite, isFalse);
    });

    test('parse infinity (huruf besar, spasi, plus) = tanpa batas', () {
      for (final s in ['infinity', 'Infinity', ' INFINITY ', '+infinity']) {
        final p = PausedUntil.parse(s);
        expect(p.indefinite, isTrue, reason: s);
        expect(p.until, isNull, reason: s);
        expect(p.activeAt(now), isTrue, reason: s);
      }
    });

    test('parse -infinity dan teks rusak = tidak dijeda', () {
      for (final s in ['-infinity', 'bukan tanggal', '']) {
        final p = PausedUntil.parse(s);
        expect(p.indefinite, isFalse, reason: s);
        expect(p.until, isNull, reason: s);
        expect(p.activeAt(now), isFalse, reason: s);
      }
    });

    test('parse timestamp PostgREST', () {
      final p = PausedUntil.parse('2026-11-05T12:30:00+00:00');
      expect(p.until, DateTime.utc(2026, 11, 5, 12, 30));
      expect(p.indefinite, isFalse);
    });

    test(
      'activeAt: berlaku sebelum batas, tidak tepat di batas atau sesudah',
      () {
        final p = PausedUntil.at(DateTime.utc(2026, 11, 5, 12, 30));
        expect(p.activeAt(DateTime.utc(2026, 11, 5, 12, 29, 59)), isTrue);
        expect(p.activeAt(DateTime.utc(2026, 11, 5, 12, 30)), isFalse);
        expect(p.activeAt(DateTime.utc(2026, 11, 5, 13)), isFalse);
      },
    );

    test('none tidak pernah aktif, indefinitely selalu aktif', () {
      expect(PausedUntil.none.activeAt(DateTime.utc(3000)), isFalse);
      expect(PausedUntil.indefinitely.activeAt(DateTime.utc(3000)), isTrue);
    });
  });

  group('MapMember', () {
    test('isPausedAt: berbagi dimatikan = dijeda walau tanpa jeda', () {
      expect(member(sharing: false).isPausedAt(t0), isTrue);
    });

    test('isPausedAt: jeda berjalan, kedaluwarsa, tanpa batas', () {
      final future = PausedUntil.at(t0.add(const Duration(minutes: 5)));
      final past = PausedUntil.at(t0.subtract(const Duration(minutes: 5)));
      expect(member(pause: future).isPausedAt(t0), isTrue);
      expect(member(pause: past).isPausedAt(t0), isFalse);
      expect(member(pause: PausedUntil.indefinitely).isPausedAt(t0), isTrue);
      expect(member().isPausedAt(t0), isFalse);
    });

    test('jeda yang kedaluwarsa karena waktu maju', () {
      final m = member(pause: PausedUntil.at(t0.add(const Duration(hours: 1))));
      expect(m.isPausedAt(t0), isTrue);
      expect(
        m.isPausedAt(t0.add(const Duration(hours: 1, seconds: 1))),
        isFalse,
      );
    });

    test('copyWith mengganti yang diberikan dan mempertahankan sisanya', () {
      final loc = seen(t0);
      final m = member(
        location: loc,
      ).copyWith(pause: PausedUntil.indefinitely, sharingEnabled: false);
      expect(m.pause.indefinite, isTrue);
      expect(m.sharingEnabled, isFalse);
      expect(m.location, same(loc));
      expect(m.userId, 'u1');
      expect(m.displayName, 'Rina');
      expect(m.colorHex, '#0F766E');
      final loc2 = seen(t0.add(const Duration(minutes: 1)));
      expect(
        member(location: loc).copyWith(location: loc2).location,
        same(loc2),
      );
    });

    test('bawaan: berbagi aktif, tidak dijeda, tanpa lokasi', () {
      final m = member();
      expect(m.sharingEnabled, isTrue);
      expect(m.pause, same(PausedUntil.none));
      expect(m.location, isNull);
    });
  });

  group('presenceOf', () {
    test('aktif bila lokasi baru', () {
      final m = member(location: seen(t0.subtract(const Duration(minutes: 1))));
      expect(presenceOf(m, t0), PresenceState.active);
    });

    test('tepat di ambang 30 menit masih aktif, lewat sedikit basi', () {
      final atEdge = member(location: seen(t0.subtract(staleThreshold)));
      expect(presenceOf(atEdge, t0), PresenceState.active);
      final over = member(
        location: seen(
          t0.subtract(staleThreshold + const Duration(seconds: 1)),
        ),
      );
      expect(presenceOf(over, t0), PresenceState.stale);
    });

    test('staleAfter kustom', () {
      final m = member(location: seen(t0.subtract(const Duration(minutes: 5))));
      expect(
        presenceOf(m, t0, staleAfter: const Duration(minutes: 2)),
        PresenceState.stale,
      );
    });

    test('tanpa lokasi = noLocation', () {
      expect(presenceOf(member(), t0), PresenceState.noLocation);
    });

    test('dijeda mengalahkan semua (lokasi segar, tanpa lokasi, basi)', () {
      final paused = PausedUntil.indefinitely;
      expect(
        presenceOf(member(pause: paused, location: seen(t0)), t0),
        PresenceState.paused,
      );
      expect(presenceOf(member(pause: paused), t0), PresenceState.paused);
      expect(
        presenceOf(
          member(sharing: false, location: seen(DateTime.utc(2020))),
          t0,
        ),
        PresenceState.paused,
      );
    });

    test('jeda kedaluwarsa kembali ke aktif atau basi', () {
      final past = PausedUntil.at(t0.subtract(const Duration(minutes: 1)));
      expect(
        presenceOf(member(pause: past, location: seen(t0)), t0),
        PresenceState.active,
      );
      expect(
        presenceOf(member(pause: past, location: seen(DateTime.utc(2020))), t0),
        PresenceState.stale,
      );
    });

    test('lokasi bertanda waktu di masa depan dianggap aktif', () {
      final m = member(location: seen(t0.add(const Duration(minutes: 10))));
      expect(presenceOf(m, t0), PresenceState.active);
    });

    test('hasMarker hanya untuk aktif dan basi', () {
      expect(hasMarker(PresenceState.active), isTrue);
      expect(hasMarker(PresenceState.stale), isTrue);
      expect(hasMarker(PresenceState.paused), isFalse);
      expect(hasMarker(PresenceState.noLocation), isFalse);
    });
  });

  group('formatRelativeTime', () {
    String f(Duration ago) => formatRelativeTime(t0.subtract(ago), t0);

    test('kurang dari semenit dan masa depan = baru saja', () {
      expect(f(Duration.zero), 'baru saja');
      expect(f(const Duration(seconds: 59)), 'baru saja');
      expect(f(const Duration(seconds: -30)), 'baru saja');
      expect(f(const Duration(hours: -2)), 'baru saja');
    });

    test('menit', () {
      expect(f(const Duration(minutes: 1)), '1 mnt lalu');
      expect(f(const Duration(minutes: 2, seconds: 59)), '2 mnt lalu');
      expect(f(const Duration(minutes: 59, seconds: 59)), '59 mnt lalu');
    });

    test('jam', () {
      expect(f(const Duration(hours: 1)), '1 jam lalu');
      expect(f(const Duration(hours: 3, minutes: 40)), '3 jam lalu');
      expect(f(const Duration(hours: 23, minutes: 59)), '23 jam lalu');
    });

    test('hari', () {
      expect(f(const Duration(days: 1)), '1 hari lalu');
      expect(f(const Duration(days: 2, hours: 5)), '2 hari lalu');
      expect(f(const Duration(days: 40)), '40 hari lalu');
    });
  });

  group('formatClock', () {
    test('HH.mm dengan nol di depan, jam lokal', () {
      expect(formatClock(DateTime(2026, 11, 5, 14, 30)), '14.30');
      expect(formatClock(DateTime(2026, 11, 5, 7, 5)), '07.05');
      expect(formatClock(DateTime(2026, 11, 5, 0, 0)), '00.00');
    });

    test('waktu UTC dikonversi ke lokal', () {
      final utc = DateTime.utc(2026, 11, 5, 12, 30);
      final local = utc.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(formatClock(utc), '${two(local.hour)}.${two(local.minute)}');
    });
  });
}
