import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/map/data/supabase_map_repository.dart';
import 'package:tether/features/map/domain/map_repository.dart';

import 'map_domain_test.dart' show ewkbHex;

/// Satu permintaan yang diterima server uji.
class Req {
  Req(this.method, this.uri, this.body);

  final String method;
  final Uri uri;
  final Object? body;

  String get path => uri.path;
}

typedef Reply = ({int status, Object? body});

Reply ok(Object? body) => (status: 200, body: body);
Reply err(int status, String code) => (
  status: status,
  body: {'code': code, 'message': 'x', 'details': null, 'hint': null},
);

/// Server HTTP lokal (loopback) sebagai pengganti PostgREST: tidak ada
/// akses jaringan keluar.
class FakePostgrest {
  FakePostgrest._(this._server);

  final HttpServer _server;
  final requests = <Req>[];

  /// Jawaban per path (mis. '/rest/v1/circle_members').
  final routes = <String, Reply Function(Req)>{};

  static Future<FakePostgrest> start() async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final f = FakePostgrest._(s);
    s.listen(f._handle);
    return f;
  }

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> _handle(HttpRequest r) async {
    final raw = await utf8.decoder.bind(r).join();
    final req = Req(r.method, r.uri, raw.isEmpty ? null : jsonDecode(raw));
    requests.add(req);
    final handler = routes[r.uri.path];
    final reply = handler == null ? err(404, 'PGRST205') : handler(req);
    r.response.statusCode = reply.status;
    r.response.headers.contentType = ContentType.json;
    if (reply.status != 204) r.response.write(jsonEncode(reply.body));
    await r.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

String _b64(Object o) =>
    base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

/// JWT tak bertanda tangan dengan exp jauh di depan (cukup untuk sesi lokal).
String fakeJwt(String uid) =>
    '${_b64({'alg': 'none'})}.${_b64({'sub': uid, 'exp': 4102444800})}.sig';

Future<SupabaseClient> clientFor(FakePostgrest server, {String? uid}) async {
  final client = SupabaseClient(
    server.url.toString(),
    'anon-key-uji',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  if (uid != null) {
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': fakeJwt(uid),
        'refresh_token': 'r',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': uid,
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }
  return client;
}

Future<void> expectFailure(
  Future<Object?> Function() call,
  MapFailureKind kind,
) async {
  try {
    await call();
  } on MapFailure catch (e) {
    expect(e.kind, kind);
    return;
  }
  fail('MapFailure($kind) tidak dilempar');
}

void main() {
  group('locationFromRow', () {
    test('baris lengkap (REST) dengan EWKB', () {
      final loc = SupabaseMapRepository.locationFromRow({
        'last_point': ewkbHex(lon: 106.8, lat: -6.2),
        'last_seen_at': '2026-11-05T12:00:00+00:00',
        'battery_pct': 80,
        'is_moving': true,
      })!;
      expect(loc.point, const LatLng(-6.2, 106.8));
      expect(loc.lastSeenAt, DateTime.utc(2026, 11, 5, 12));
      expect(loc.batteryPct, 80);
      expect(loc.isMoving, isTrue);
    });

    test('payload Realtime: GeoJSON dan angka desimal untuk baterai', () {
      final loc = SupabaseMapRepository.locationFromRow({
        'last_point': {
          'type': 'Point',
          'coordinates': [106.8, -6.2],
        },
        'last_seen_at': '2026-11-05T12:00:00Z',
        'battery_pct': 55.0,
      })!;
      expect(loc.point, const LatLng(-6.2, 106.8));
      expect(loc.batteryPct, 55);
      expect(loc.isMoving, isNull);
    });

    test('baterai dan is_moving boleh kosong', () {
      final loc = SupabaseMapRepository.locationFromRow({
        'last_point': ewkbHex(lon: 1, lat: 2),
        'last_seen_at': '2026-11-05T12:00:00Z',
        'battery_pct': null,
        'is_moving': null,
      })!;
      expect(loc.batteryPct, isNull);
      expect(loc.isMoving, isNull);
    });

    test('titik atau waktu hilang/rusak = null', () {
      final p = ewkbHex(lon: 1, lat: 2);
      const t = '2026-11-05T12:00:00Z';
      expect(
        SupabaseMapRepository.locationFromRow({
          'last_point': null,
          'last_seen_at': t,
        }),
        isNull,
      );
      expect(
        SupabaseMapRepository.locationFromRow({
          'last_point': 'rusak',
          'last_seen_at': t,
        }),
        isNull,
      );
      expect(
        SupabaseMapRepository.locationFromRow({
          'last_point': p,
          'last_seen_at': null,
        }),
        isNull,
      );
      expect(
        SupabaseMapRepository.locationFromRow({
          'last_point': p,
          'last_seen_at': 'kemarin',
        }),
        isNull,
      );
      expect(
        SupabaseMapRepository.locationFromRow({
          'last_point': p,
          'last_seen_at': 12345,
        }),
        isNull,
      );
      expect(SupabaseMapRepository.locationFromRow({}), isNull);
    });
  });

  group('lewat server HTTP lokal', () {
    late FakePostgrest server;
    late SupabaseClient client;
    late SupabaseMapRepository repo;

    setUp(() async {
      server = await FakePostgrest.start();
      client = await clientFor(server, uid: 'u1');
      repo = SupabaseMapRepository(client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close();
    });

    test('fetchCircles: urutan, filter pengguna, nama Circle', () async {
      server.routes['/rest/v1/circle_members'] = (_) => ok([
        {
          'circle_id': 'c1',
          'joined_at': '2026-01-01T00:00:00Z',
          'circles': {'name': 'Keluarga'},
        },
        {
          'circle_id': 'c2',
          'joined_at': '2026-02-01T00:00:00Z',
          'circles': null,
        },
      ]);

      final circles = await repo.fetchCircles();

      expect(
        [for (final c in circles) (c.id, c.name)],
        [('c1', 'Keluarga'), ('c2', '')],
      );
      final q = server.requests.single.uri.queryParameters;
      expect(q['user_id'], 'eq.u1');
      expect(q['order'], startsWith('joined_at.asc'));
      expect(q['select'], contains('circles(name)'));
    });

    test(
      'fetchCircles tanpa sesi = unauthenticated, tanpa permintaan',
      () async {
        final anonClient = await clientFor(server);
        addTearDown(anonClient.dispose);
        final anon = SupabaseMapRepository(anonClient);
        await expectFailure(anon.fetchCircles, MapFailureKind.unauthenticated);
        expect(server.requests, isEmpty);
      },
    );

    test('fetchMembers: gabung profil, jeda, dan lokasi', () async {
      server.routes['/rest/v1/circle_members'] = (_) => ok([
        {
          'user_id': 'u1',
          'sharing_enabled': true,
          'paused_until': null,
          'profiles': {'display_name': 'Rina', 'color': '#2563EB'},
        },
        {
          'user_id': 'u2',
          'sharing_enabled': false,
          'paused_until': 'infinity',
          'profiles': {'display_name': 'Raka', 'color': '#EA580C'},
        },
        {
          'user_id': 'u3',
          'sharing_enabled': true,
          'paused_until': '2026-11-05T12:30:00+00:00',
          'profiles': {'display_name': 'Sari', 'color': '#DB2777'},
        },
      ]);
      server.routes['/rest/v1/member_status'] = (_) => ok([
        {
          'user_id': 'u1',
          'last_point': ewkbHex(lon: 106.8, lat: -6.2),
          'last_seen_at': '2026-11-05T11:59:00+00:00',
          'battery_pct': 90,
          'is_moving': false,
        },
      ]);

      final members = await repo.fetchMembers('c1');

      expect(members.map((m) => m.userId), ['u1', 'u2', 'u3']);
      final rina = members[0];
      expect(rina.displayName, 'Rina');
      expect(rina.colorHex, '#2563EB');
      expect(rina.location!.point, const LatLng(-6.2, 106.8));
      expect(rina.location!.batteryPct, 90);
      expect(rina.location!.isMoving, isFalse);
      final raka = members[1];
      expect(raka.sharingEnabled, isFalse);
      expect(raka.pause.indefinite, isTrue);
      expect(raka.location, isNull);
      expect(members[2].pause.until, DateTime.utc(2026, 11, 5, 12, 30));

      final circleReq = server.requests.first.uri.queryParameters;
      expect(circleReq['circle_id'], 'eq.c1');
      final statusReq = server.requests.last.uri.queryParameters;
      expect(statusReq['user_id'], startsWith('in.('));
      for (final id in ['u1', 'u2', 'u3']) {
        expect(statusReq['user_id'], contains(id));
      }
    });

    test(
      'fetchMembers: warna tidak valid jatuh ke bawaan, profil kosong',
      () async {
        server.routes['/rest/v1/circle_members'] = (_) => ok([
          {
            'user_id': 'u1',
            'sharing_enabled': null,
            'paused_until': null,
            'profiles': {'display_name': 'Rina', 'color': 'merah'},
          },
          {
            'user_id': 'u2',
            'sharing_enabled': true,
            'paused_until': null,
            'profiles': null,
          },
        ]);
        server.routes['/rest/v1/member_status'] = (_) => ok([]);

        final members = await repo.fetchMembers('c1');

        expect(members[0].colorHex, '#0F766E');
        expect(members[0].sharingEnabled, isTrue); // null = bawaan aktif
        expect(members[1].displayName, '');
        expect(members[1].colorHex, '#0F766E');
      },
    );

    test('fetchMembers: baris status tanpa titik valid diabaikan', () async {
      server.routes['/rest/v1/circle_members'] = (_) => ok([
        {
          'user_id': 'u1',
          'sharing_enabled': true,
          'paused_until': null,
          'profiles': {'display_name': 'Rina', 'color': '#2563EB'},
        },
      ]);
      server.routes['/rest/v1/member_status'] = (_) => ok([
        {'user_id': 'u1', 'last_point': null, 'last_seen_at': null},
      ]);

      final members = await repo.fetchMembers('c1');

      expect(members.single.location, isNull);
    });

    test('fetchMembers tanpa anggota tidak menanyakan member_status', () async {
      server.routes['/rest/v1/circle_members'] = (_) => ok([]);

      expect(await repo.fetchMembers('c1'), isEmpty);
      expect(server.requests.map((r) => r.path), ['/rest/v1/circle_members']);
    });

    test(
      'pauseSharing mengirim RPC dengan menit (null = tanpa batas)',
      () async {
        server.routes['/rest/v1/rpc/pause_sharing'] = (_) =>
            (status: 204, body: null);

        await repo.pauseSharing('c1', minutes: 15);
        await repo.pauseSharing('c1');

        final rpc = server.requests.where((r) => r.method == 'POST').toList();
        expect(rpc[0].body, {'p_circle_id': 'c1', 'p_minutes': 15});
        expect(rpc[1].body, {'p_circle_id': 'c1', 'p_minutes': null});
      },
    );

    test('resumeSharing mengirim RPC resume_sharing', () async {
      server.routes['/rest/v1/rpc/resume_sharing'] = (_) =>
          (status: 204, body: null);

      await repo.resumeSharing('c1');

      expect(server.requests.single.body, {'p_circle_id': 'c1'});
    });

    test('kode galat Postgres dipetakan ke MapFailureKind', () async {
      const expected = {
        '28000': MapFailureKind.unauthenticated,
        '42501': MapFailureKind.notMember,
        '22023': MapFailureKind.invalid,
        'XX000': MapFailureKind.unknown,
      };
      for (final e in expected.entries) {
        server.routes['/rest/v1/rpc/pause_sharing'] = (_) => err(400, e.key);
        server.routes['/rest/v1/rpc/resume_sharing'] = (_) => err(400, e.key);
        server.routes['/rest/v1/circle_members'] = (_) => err(400, e.key);
        await expectFailure(() => repo.pauseSharing('c1', minutes: 5), e.value);
        await expectFailure(() => repo.resumeSharing('c1'), e.value);
        await expectFailure(() => repo.fetchMembers('c1'), e.value);
        await expectFailure(repo.fetchCircles, e.value);
      }
    });

    // Hanya RPC (POST): klien postgrest mengulang GET dengan jeda beberapa
    // detik saat koneksi gagal, sehingga fetch* terlalu lambat untuk diuji.
    test('server tidak terjangkau = network', () async {
      await server.close(); // port ditutup: koneksi ditolak
      await expectFailure(
        () => repo.pauseSharing('c1', minutes: 1),
        MapFailureKind.network,
      );
      await expectFailure(
        () => repo.resumeSharing('c1'),
        MapFailureKind.network,
      );
    });
  });

  test('MapFailure.toString tidak membawa detail teknis', () {
    expect(
      const MapFailure(MapFailureKind.network).toString(),
      'MapFailure(MapFailureKind.network)',
    );
  });
}
