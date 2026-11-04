// Tes integrasi ujung ke ujung terhadap Supabase LOKAL yang sedang berjalan.
// Dilewati bila SUPABASE_URL atau SUPABASE_ANON_KEY kosong, sehingga
// `flutter test` biasa tetap hijau tanpa server. Kunci tidak pernah disimpan:
// ambil saat menjalankan, mis. di shell:
//   ENV=$(npx supabase status -o env)
//   export SUPABASE_URL=$(printf '%s\n' "$ENV" | sed -n 's/^API_URL="\(.*\)"$/\1/p')
//   export SUPABASE_ANON_KEY=$(printf '%s\n' "$ENV" | sed -n 's/^ANON_KEY="\(.*\)"$/\1/p')
//   flutter test test/integration/supabase_e2e_test.dart
// (--dart-define=SUPABASE_URL=... juga didukung).
//
// Tiap run memakai pengguna anonim baru (user_id unik), jadi bisa diulang. RLS
// tidak mengizinkan pengguna menghapus datanya, jadi baris uji dibiarkan.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/location_tracking/data/location_api.dart';
import 'package:tether/features/location_tracking/data/location_uploader.dart';
import 'package:tether/features/location_tracking/data/point_queue.dart';
import 'package:tether/features/location_tracking/data/simulated_location_source.dart';
import 'package:tether/features/location_tracking/data/tracking_controller.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';

const _urlDefine = String.fromEnvironment('SUPABASE_URL');
const _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

final String _url = _urlDefine.isNotEmpty
    ? _urlDefine
    : (Platform.environment['SUPABASE_URL'] ?? '');
final String _anonKey = _keyDefine.isNotEmpty
    ? _keyDefine
    : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');

final String? _skipReason = (_url.isEmpty || _anonKey.isEmpty)
    ? 'SUPABASE_URL atau SUPABASE_ANON_KEY kosong: jalankan Supabase lokal lalu '
          'berikan keduanya (lihat komentar di atas berkas ini)'
    : null;

/// Meneruskan ke API asli sambil mencatat titik dan jumlah baris yang masuk.
class _RecordingApi implements LocationApi {
  _RecordingApi(this._inner);

  final LocationApi _inner;
  final List<LocationPoint> sent = [];
  int inserted = 0;

  @override
  Future<int> uploadBatch(List<LocationPoint> points) async {
    final n = await _inner.uploadBatch(points);
    sent.addAll(points);
    inserted += n;
    return n;
  }
}

/// Titik uji di luar place uji, satu per detik berakhir sekitar [end].
List<LocationPoint> _points(int n, {required DateTime end}) => [
  for (var i = 0; i < n; i++)
    LocationPoint(
      lat: -6.3 + i * 0.0001,
      lng: 106.9,
      accuracyM: 5,
      speedMps: 1,
      batteryPct: 70,
      isMoving: true,
      recordedAt: end.subtract(Duration(seconds: n - 1 - i)),
    ),
];

LocationUploader _uploader(PointQueue q, LocationApi api) => LocationUploader(
  queue: q,
  api: api,
  initialBackoff: const Duration(milliseconds: 100),
  maxBackoff: const Duration(milliseconds: 500),
);

Future<InMemoryPointQueue> _queueOf(List<LocationPoint> points) async {
  final q = InMemoryPointQueue();
  for (final p in points) {
    await q.enqueue(p);
  }
  return q;
}

Future<List<Map<String, dynamic>>> _rows(
  SupabaseClient c,
  String table, [
  String columns = '*',
]) async => (await c.from(table).select(columns)).cast<Map<String, dynamic>>();

void main() {
  group('Supabase lokal ujung ke ujung', skip: _skipReason, () {
    final clients = <SupabaseClient>[];

    Future<SupabaseClient> newUser() async {
      final c = SupabaseClient(_url, _anonKey);
      clients.add(c);
      final res = await c.auth.signInAnonymously();
      expect(res.user, isNotNull);
      return c;
    }

    tearDownAll(() async {
      for (final c in clients) {
        await c.dispose();
      }
    });

    group('rute simulasi, geofence, idempotensi', () {
      late SupabaseClient client;
      late String placeId;
      late List<LocationPoint> route;
      late _RecordingApi api;

      setUpAll(() async {
        client = await newUser();
        final places = await _rows(client, 'places', 'id,name');
        placeId = places.singleWhere((p) => p['name'] == 'Titik Uji')['id'];
      });

      test(
        '1. rute bawaan terkirim lewat TrackingController dan Uploader',
        () async {
          final done = Completer<void>();
          var tick = 0;
          late DateTime t0;
          final source = SimulatedLocationSource(
            ticker: (_) =>
                Stream<void>.periodic(const Duration(milliseconds: 2)),
            now: () => t0.add(const Duration(seconds: 3) * tick++),
            onCompleted: () => done.complete(),
          );
          final total = source.plannedPointCount;
          // Titik terakhir sekitar 8 detik lalu: tidak di masa depan, jauh dari 48 jam.
          t0 = DateTime.now().toUtc().subtract(
            Duration(seconds: 3 * (total - 1) + 8),
          );
          api = _RecordingApi(SupabaseLocationApi(client));
          final queue = InMemoryPointQueue();
          final logs = <String>[];
          final uploader = _uploader(queue, api);
          final controller = TrackingController(
            source: source,
            queue: queue,
            uploader: uploader,
            log: logs.add,
          );
          addTearDown(controller.dispose);

          await controller.start();
          await done.future.timeout(const Duration(seconds: 30));
          await controller.stop();
          var flushed = false;
          for (var i = 0; i < 20 && !flushed; i++) {
            flushed = await uploader.flush();
          }
          expect(
            flushed,
            isTrue,
            reason: 'antrean harus kosong; ${uploader.lastError}',
          );
          expect(await queue.length(), 0);
          expect(uploader.sentCount, total);
          expect(uploader.droppedInvalid, 0);
          expect(uploader.lastError, isNull);
          expect(api.sent.length, total);
          expect(
            api.inserted,
            total,
          ); // RPC mengembalikan jumlah baris yang masuk
          route = List.of(api.sent);
          expect(
            route.last.recordedAt.isBefore(DateTime.now().toUtc()),
            isTrue,
          );
        },
      );

      test(
        '2. jumlah baris location_points sama dengan jumlah titik',
        () async {
          final rows = await _rows(client, 'location_points', 'id,recorded_at');
          expect(rows.length, route.length);
        },
      );

      test(
        '3. member_status terisi dan last_seen_at = titik terakhir',
        () async {
          final rows = await _rows(
            client,
            'member_status',
            'last_seen_at,battery_pct,is_moving,current_place_id',
          );
          expect(rows.length, 1);
          final seen = DateTime.parse(rows.single['last_seen_at'] as String);
          final latest = route
              .map((p) => p.recordedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          expect(seen.isAtSameMomentAs(latest), isTrue);
          expect(rows.single['battery_pct'], 80);
          expect(rows.single['current_place_id'], isNull); // sudah keluar
        },
      );

      test(
        '4. tepat satu arrive lalu satu leave untuk place uji, berurutan',
        () async {
          final rows = await _rows(client, 'events', 'type,place_id,payload');
          // created_at sama dalam satu transaksi, jadi urutkan menurut recorded_at
          // di payload (waktu titik pemicu).
          rows.sort(
            (a, b) => DateTime.parse(
              a['payload']['recorded_at'] as String,
            ).compareTo(DateTime.parse(b['payload']['recorded_at'] as String)),
          );
          expect(rows.map((r) => r['type']).toList(), ['arrive', 'leave']);
          expect(rows.every((r) => r['place_id'] == placeId), isTrue);
          // Payload tidak boleh memuat koordinat.
          expect(
            rows.every((r) => !(r['payload'] as Map).containsKey('lat')),
            isTrue,
          );
        },
      );

      test(
        '5. kirim ulang batch yang sama idempoten dan tanpa error',
        () async {
          final direct = SupabaseLocationApi(client);
          expect(await direct.uploadBatch(route), 0); // semua duplikat

          // Lewat Uploader juga: ack sukses, tidak ada error.
          final queue = await _queueOf(route);
          final uploader = _uploader(queue, direct);
          addTearDown(uploader.dispose);
          expect(await uploader.flush(), isTrue);
          expect(uploader.lastError, isNull);
          expect(uploader.droppedInvalid, 0);
          expect(await queue.length(), 0);

          expect(
            (await _rows(client, 'location_points', 'id')).length,
            route.length,
          );
          expect((await _rows(client, 'events', 'id')).length, 2);
        },
      );
    });

    group('nilai null', () {
      test('6. accuracyM/speedMps/batteryPct null diterima server', () async {
        final c = await newUser();
        final end = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
        final pts = [
          for (var i = 0; i < 3; i++)
            LocationPoint(
              lat: -6.3,
              lng: 106.9,
              isMoving: false,
              recordedAt: end.subtract(Duration(seconds: 3 - i)),
            ),
          // Satu titik lengkap di batch yang sama.
          _points(1, end: end).single,
        ];
        expect(pts.first.toJson()['accuracy_m'], isNull);
        expect(await SupabaseLocationApi(c).uploadBatch(pts), 4);
        final rows = await _rows(
          c,
          'location_points',
          'accuracy_m,speed_mps,battery_pct,is_moving',
        );
        expect(rows.length, 4);
        expect(rows.where((r) => r['accuracy_m'] == null).length, 3);
        expect(rows.where((r) => r['speed_mps'] == null).length, 3);
        expect(rows.where((r) => r['battery_pct'] == null).length, 3);
        expect(rows.where((r) => r['is_moving'] == false).length, 3);
      });
    });

    group('titik buruk (batch beracun)', () {
      // Satu pengguna untuk semua tes di grup ini (batas sign-in anonim lokal).
      // Tiap tes memakai rentang waktu sendiri agar tidak bentrok di
      // unique (user_id, recorded_at), dan memeriksa selisih jumlah baris.
      late SupabaseClient c;
      setUpAll(() async => c = await newUser());
      Future<int> rowCount() async =>
          (await _rows(c, 'location_points', 'id')).length;

      test(
        'API: 22023 menjadi InvalidBatchException; tanpa login bukan itu',
        () async {
          final bad = LocationPoint(
            lat: 123,
            lng: 106.9,
            isMoving: false,
            recordedAt: DateTime.now().toUtc(),
          );
          await expectLater(
            SupabaseLocationApi(c).uploadBatch([bad]),
            throwsA(isA<InvalidBatchException>()),
          );

          final anon = SupabaseClient(_url, _anonKey);
          clients.add(anon);
          await expectLater(
            SupabaseLocationApi(
              anon,
            ).uploadBatch(_points(1, end: DateTime.now())),
            throwsA(
              allOf(
                isA<LocationApiException>(),
                isNot(isA<InvalidBatchException>()),
              ),
            ),
          );
        },
      );

      test('7. satu titik buruk di batch 10: 9 masuk, 1 dibuang', () async {
        final before = await rowCount();
        final end = DateTime.now().toUtc().subtract(
          const Duration(minutes: 10),
        );
        final good = _points(10, end: end);
        final pts = [
          for (var i = 0; i < 10; i++)
            i == 4
                ? LocationPoint(
                    lat: 123,
                    lng: good[i].lng,
                    isMoving: true,
                    recordedAt: good[i].recordedAt,
                  )
                : good[i],
        ];
        final queue = await _queueOf(pts);
        final uploader = _uploader(queue, SupabaseLocationApi(c));
        addTearDown(uploader.dispose);
        expect(await uploader.flush(), isTrue);
        expect(uploader.droppedInvalid, 1);
        expect(uploader.sentCount, 9);
        expect(uploader.lastError, isNull);
        expect(await queue.length(), 0);
        final rows = await _rows(c, 'location_points', 'recorded_at');
        final stored = rows
            .map((r) => DateTime.parse(r['recorded_at'] as String))
            .toSet();
        expect(rows.length - before, 9);
        expect(stored.contains(good[4].recordedAt), isFalse);
      });

      test(
        '7b. dua jenis data buruk sekaligus: keduanya dibuang, sehat masuk',
        () async {
          final before = await rowCount();
          final end = DateTime.now().toUtc().subtract(
            const Duration(minutes: 20),
          );
          final good = _points(6, end: end);
          final pts = [
            good[0],
            good[1],
            LocationPoint(
              lat: good[2].lat,
              lng: 200, // lng di luar rentang
              isMoving: true,
              recordedAt: good[2].recordedAt,
            ),
            good[3],
            LocationPoint(
              lat: good[4].lat,
              lng: good[4].lng,
              batteryPct: 101, // baterai di luar 0..100
              isMoving: true,
              recordedAt: good[4].recordedAt,
            ),
            good[5],
          ];
          final queue = await _queueOf(pts);
          final uploader = _uploader(queue, SupabaseLocationApi(c));
          addTearDown(uploader.dispose);
          expect(await uploader.flush(), isTrue);
          expect(uploader.droppedInvalid, 2);
          expect(uploader.sentCount, 4);
          expect(await queue.length(), 0);
          expect(await rowCount() - before, 4);
        },
      );

      test('8. titik di masa depan (jam maju): batch ditahan, tidak ada yang '
          'dibuang atau tersimpan sebagian', () async {
        final before = await rowCount();
        final end = DateTime.now().toUtc().subtract(
          const Duration(minutes: 30),
        );
        final pts = [
          ..._points(5, end: end),
          LocationPoint(
            lat: -6.3,
            lng: 106.9,
            isMoving: true,
            recordedAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
        ];
        final api = SupabaseLocationApi(c);
        await expectLater(
          api.uploadBatch(pts),
          throwsA(
            allOf(
              isA<LocationApiException>(),
              isNot(isA<InvalidBatchException>()),
            ),
          ),
        );
        final queue = await _queueOf(pts);
        final uploader = _uploader(queue, api);
        addTearDown(uploader.dispose);
        expect(await uploader.flush(), isFalse);
        expect(uploader.droppedInvalid, 0);
        expect(uploader.sentCount, 0);
        expect(uploader.lastError, contains('jam perangkat'));
        expect(await queue.length(), 6);
        expect(await rowCount() - before, 0);
      });
    });
  });
}
