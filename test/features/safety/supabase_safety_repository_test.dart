import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/safety/data/supabase_safety_repository.dart';
import 'package:tether/features/safety/domain/safety_error.dart';
import 'package:tether/features/safety/domain/safety_repository.dart';

/// Server HTTP loopback sebagai pengganti PostgREST (tanpa jaringan keluar).
class _Server {
  _Server._(this.http);

  final HttpServer http;
  final requests = <({String path, Object? body})>[];
  ({int status, Object? body}) Function(String path) reply = (_) =>
      (status: 200, body: null);

  static Future<_Server> start() async {
    final s = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s.http.listen((r) async {
      final raw = await utf8.decoder.bind(r).join();
      s.requests.add((
        path: r.uri.path,
        body: raw.isEmpty ? null : jsonDecode(raw),
      ));
      final res = s.reply(r.uri.path);
      r.response.statusCode = res.status;
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(res.body));
      await r.response.close();
    });
    return s;
  }

  SupabaseClient client() => SupabaseClient(
    'http://127.0.0.1:${http.port}',
    'anon-key-uji',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Future<void> close() => http.close(force: true);
}

({int status, Object? body}) pgError(int status, String code) => (
  status: status,
  body: {'code': code, 'message': 'pesan rahasia 106.8456', 'details': null},
);

void main() {
  late _Server server;
  late SupabaseSafetyRepository repo;

  setUp(() async {
    server = await _Server.start();
    repo = SupabaseSafetyRepository(server.client());
  });
  tearDown(() => server.close());

  Future<SafetyErrorKind> kindOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on SafetyError catch (e) {
      expect(e.toString(), isNot(contains('106.8456')));
      return e.kind;
    }
    fail('SafetyError tidak dilempar');
  }

  test('checkin memanggil RPC checkin dengan p_circle_id dan p_kind', () async {
    server.reply = (_) => (status: 200, body: 'event-id');
    await repo.checkin('c1', CheckinKind.arrived);
    await repo.checkin('c1', CheckinKind.safe);
    expect(server.requests.map((r) => r.path), [
      '/rest/v1/rpc/checkin',
      '/rest/v1/rpc/checkin',
    ]);
    expect(server.requests[0].body, {'p_circle_id': 'c1', 'p_kind': 'arrived'});
    expect((server.requests[1].body as Map)['p_kind'], 'safe');
  });

  test(
    'triggerSos mengirim semua parameter dan mengembalikan jumlah Circle',
    () async {
      server.reply = (_) => (status: 200, body: 3);
      final n = await repo.triggerSos(
        lat: -6.2,
        lng: 106.8,
        accuracyM: 9.5,
        clientId: 'cid',
        triggeredAt: DateTime.utc(2026, 11, 5, 10, 0, 1),
      );
      expect(n, 3);
      expect(server.requests.single.path, '/rest/v1/rpc/trigger_sos');
      expect(server.requests.single.body, {
        'p_lat': -6.2,
        'p_lng': 106.8,
        'p_accuracy_m': 9.5,
        'p_client_id': 'cid',
        'p_triggered_at': '2026-11-05T10:00:01.000Z',
      });
    },
  );

  test('kode galat dipetakan: TH006/TH007/TH008/42501/28000/22023', () async {
    final expected = {
      'TH006': SafetyErrorKind.rateLimited,
      'TH007': SafetyErrorKind.rateLimited,
      'TH008': SafetyErrorKind.noCircle,
      '42501': SafetyErrorKind.notMember,
      '28000': SafetyErrorKind.notSignedIn,
      '22023': SafetyErrorKind.invalidArgument,
      'XX000': SafetyErrorKind.unknown,
    };
    for (final e in expected.entries) {
      server.reply = (_) => pgError(400, e.key);
      expect(
        await kindOf(() => repo.checkin('c1', CheckinKind.safe)),
        e.value,
        reason: e.key,
      );
      expect(
        await kindOf(
          () => repo.triggerSos(
            lat: 1,
            lng: 2,
            clientId: 'x',
            triggeredAt: DateTime.utc(2026),
          ),
        ),
        e.value,
        reason: e.key,
      );
    }
  });

  test('server tak terjangkau dipetakan ke network', () async {
    await server.close();
    expect(
      await kindOf(() => repo.checkin('c1', CheckinKind.safe)),
      SafetyErrorKind.network,
    );
  });

  test('mapSafetyError: Timeout dan SocketException = network', () {
    expect(mapSafetyError(TimeoutException('x')).kind, SafetyErrorKind.network);
    expect(
      mapSafetyError(const SocketException('x')).kind,
      SafetyErrorKind.network,
    );
    expect(mapSafetyError(StateError('x')).kind, SafetyErrorKind.unknown);
  });
}
