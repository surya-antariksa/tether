import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/data/location_uploader.dart';
import 'package:tether/features/location_tracking/data/point_queue.dart';
import 'package:tether/features/location_tracking/data/simulated_location_source.dart';
import 'package:tether/features/location_tracking/data/tracking_controller.dart';

import 'fakes.dart';

/// Pola koordinat titik uji di teks apa pun (-6.2 atau 106.8).
bool _hasCoordinates(String s) => s.contains('-6.2') || s.contains('106.8');

Future<InMemoryPointQueue> _filled(int n, {int capacity = 5000}) async {
  final q = InMemoryPointQueue(capacity: capacity);
  for (var i = 0; i < n; i++) {
    await q.enqueue(pointAt(i));
  }
  return q;
}

void main() {
  late FakeLocationApi api;
  final uploaders = <LocationUploader>[];

  LocationUploader make(
    PointQueue q, {
    int batchSize = 50,
    List<String>? logs,
    double Function()? jitter,
  }) {
    final u = LocationUploader(
      queue: q,
      api: api,
      batchSize: batchSize,
      jitter: jitter ?? () => 0,
      log: logs?.add,
    );
    uploaders.add(u);
    return u;
  }

  setUp(() => api = FakeLocationApi());
  tearDown(() {
    for (final u in uploaders) {
      u.dispose();
    }
    uploaders.clear();
  });

  test(
    'sukses mengosongkan antrean per batch dan mengirim berurutan',
    () async {
      final q = await _filled(120);
      final u = make(q, batchSize: 50);
      expect(await u.flush(), isTrue);
      expect(await q.length(), 0);
      expect(api.calls, 3);
      expect(api.received.length, 120);
      expect(api.received.map((p) => p.recordedAt).toList(), [
        for (var i = 0; i < 120; i++) pointAt(i).recordedAt,
      ]);
      expect(u.sentCount, 120);
      expect(u.lastError, isNull);
      expect(u.currentBackoff, Duration.zero);
    },
  );

  test(
    'sentCount memakai jumlah baris yang masuk, sisanya dilewati server',
    () async {
      final q = await _filled(10);
      api.insertedFor = (pts) => pts.length - 2; // 2 duplikat per batch
      final u = make(q, batchSize: 5);
      expect(await u.flush(), isTrue);
      expect(await q.length(), 0); // yang dilewati server tetap di-ack
      expect(u.sentCount, 6);
      expect(u.skippedByServer, 4);
      expect(api.calls, 2);
    },
  );

  test('skippedByServer dihitung per potongan sukses saat bisect', () async {
    final q = await _filled(8);
    api.invalid.add(pointAt(5).recordedAt);
    api.insertedFor = (pts) => pts.length > 1 ? pts.length - 1 : pts.length;
    final u = make(q, batchSize: 8);
    expect(await u.flush(), isTrue);
    expect(u.droppedInvalid, 1);
    // 7 titik diterima dalam potongan sukses [0..3], [4], [6..7]: 3 + 0 + 1.
    expect(u.sentCount + u.skippedByServer, 7);
    expect(u.skippedByServer, 2);
    expect(u.sentCount, 5);
  });

  test('ukuran batch dibatasi 500 sesuai server', () async {
    final q = await _filled(600);
    final u = make(q, batchSize: 10000);
    await u.flush();
    expect(u.batchSize, 500);
    expect(api.calls, 2);
  });

  test(
    'gagal menyisakan antrean dan menaikkan backoff (dengan batas)',
    () async {
      final q = await _filled(3);
      api.failing = true;
      final u = make(q);
      final backoffs = <Duration>[];
      for (var i = 0; i < 9; i++) {
        expect(await u.flush(), isFalse);
        backoffs.add(u.currentBackoff);
      }
      expect(await q.length(), 3);
      expect(u.sentCount, 0);
      expect(backoffs.map((d) => d.inSeconds).toList(), [
        5,
        10,
        20,
        40,
        80,
        160,
        300,
        300,
        300,
      ]);
      expect(u.consecutiveFailures, 9);
      expect(u.lastError, isNotNull);
    },
  );

  test('jitter menambah paling banyak 20 persen', () async {
    final q = await _filled(1);
    api.failing = true;
    final u = make(q, jitter: () => 0.999);
    await u.flush();
    expect(u.currentBackoff.inMilliseconds, closeTo(6000, 10));
  });

  test(
    'pulih setelah gagal berurutan: semua terkirim berurutan tanpa hilang',
    () {
      fakeAsync((async) {
        final q = InMemoryPointQueue();
        for (var i = 0; i < 10; i++) {
          q.enqueue(pointAt(i));
        }
        async.flushMicrotasks();
        api.failOnCalls.addAll({1, 2, 3});
        final u = make(q, batchSize: 4);
        final seen = <int>[];
        u.onChanged = () => seen.add(u.currentBackoff.inSeconds);

        u.requestFlush();
        async.flushMicrotasks();
        expect(u.consecutiveFailures, 1);
        expect(u.currentBackoff, const Duration(seconds: 5));

        // Sebelum jeda habis tidak ada percobaan baru.
        async.elapse(const Duration(seconds: 4));
        expect(api.calls, 1);
        async.elapse(const Duration(seconds: 1));
        expect(u.consecutiveFailures, 2);
        expect(u.currentBackoff, const Duration(seconds: 10));

        async.elapse(const Duration(seconds: 10));
        expect(u.consecutiveFailures, 3);
        expect(u.currentBackoff, const Duration(seconds: 20));

        async.elapse(const Duration(seconds: 20));
        // Percobaan ke-4 berhasil, semua batch menyusul.
        expect(u.consecutiveFailures, 0);
        expect(u.currentBackoff, Duration.zero);
        expect(u.lastError, isNull);
        expect(u.sentCount, 10);
        expect(api.received.map((p) => p.recordedAt).toList(), [
          for (var i = 0; i < 10; i++) pointAt(i).recordedAt,
        ]);
        var left = -1;
        q.length().then((v) => left = v);
        async.flushMicrotasks();
        expect(left, 0);
      });
    },
  );

  test('kegagalan sebagian tidak meng-ack titik yang tidak terkirim', () async {
    final q = await _filled(5);
    api.failOnCalls.add(2);
    final u = make(q, batchSize: 2);
    expect(await u.flush(), isFalse);
    expect(u.sentCount, 2);
    expect(api.received.length, 2);
    final rest = await q.peekBatch(10);
    expect(rest.map((e) => e.point.recordedAt), [
      for (var i = 2; i < 5; i++) pointAt(i).recordedAt,
    ]);
  });

  test('satu flush pada satu waktu', () async {
    final q = await _filled(5);
    final u = make(q, batchSize: 2);
    api.gate = Completer<void>();
    final f1 = u.flush();
    final f2 = u.flush();
    u.requestFlush();
    expect(identical(f1, f2), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(u.isFlushing, isTrue);
    expect(api.calls, 1);
    api.gate!.complete();
    expect(await f1, isTrue);
    expect(await f2, isTrue);
    expect(api.maxConcurrent, 1);
    expect(api.received.length, 5); // tanpa kirim ganda
    expect(u.isFlushing, isFalse);
  });

  test('tidak ada koordinat di pesan error maupun log', () async {
    final q = await _filled(3);
    api.failing = true; // fake melempar Exception yang memuat koordinat
    final logs = <String>[];
    final u = make(q, logs: logs);
    await u.flush();
    await u.flush();
    expect(u.lastError, isNotNull);
    expect(_hasCoordinates(u.lastError!), isFalse);
    expect(logs, isNotEmpty);
    expect(logs.any(_hasCoordinates), isFalse);
    expect(_hasCoordinates(pointAt(0).toString()), isFalse);
  });

  group(
    'batch beracun (server menolak seluruh batch dengan data tidak valid)',
    () {
      final logs = <String>[];
      setUp(logs.clear);

      test('batch sehat: satu panggilan, tidak ada yang dibuang', () async {
        final q = await _filled(10);
        final u = make(q, batchSize: 10);
        expect(await u.flush(), isTrue);
        expect(api.calls, 1);
        expect(u.droppedInvalid, 0);
        expect(u.sentCount, 10);
      });

      test(
        'satu titik buruk di tengah batch 10: 9 terkirim, 1 dibuang',
        () async {
          final q = await _filled(10);
          api.invalid.add(pointAt(4).recordedAt);
          final u = make(q, batchSize: 10, logs: logs);
          expect(await u.flush(), isTrue);
          expect(await q.length(), 0);
          expect(u.droppedInvalid, 1);
          expect(u.sentCount, 9);
          expect(u.lastError, isNull);
          expect(u.consecutiveFailures, 0);
          expect(u.currentBackoff, Duration.zero);
          expect(api.received.length, 9);
          expect(
            api.received.map((p) => p.recordedAt),
            isNot(contains(pointAt(4).recordedAt)),
          );
          // Bukan satu panggilan per titik: batas bisect ~ 2*ceil(log2 n) + 1.
          expect(api.calls, lessThanOrEqualTo(9));
          expect(logs.any(_hasCoordinates), isFalse);
        },
      );

      test('dua titik buruk: keduanya dibuang, sisanya terkirim', () async {
        final q = await _filled(10);
        api.invalid
          ..add(pointAt(2).recordedAt)
          ..add(pointAt(7).recordedAt);
        final u = make(q, batchSize: 10);
        expect(await u.flush(), isTrue);
        expect(await q.length(), 0);
        expect(u.droppedInvalid, 2);
        expect(u.sentCount, 8);
        expect(api.received.length, 8);
      });

      test('batch tunggal yang buruk dibuang tanpa backoff', () async {
        final q = await _filled(1);
        api.invalid.add(pointAt(0).recordedAt);
        final u = make(q);
        expect(await u.flush(), isTrue);
        expect(await q.length(), 0);
        expect(u.droppedInvalid, 1);
        expect(u.sentCount, 0);
        expect(api.calls, 1);
        expect(u.currentBackoff, Duration.zero);
      });

      test(
        'batch 10 semua ditolak: tidak ada yang dibuang, backoff naik',
        () async {
          final q = await _filled(10);
          for (var i = 0; i < 10; i++) {
            api.invalid.add(pointAt(i).recordedAt);
          }
          final logs = <String>[];
          final u = make(q, batchSize: 10, logs: logs);
          final backoffs = <Duration>[];
          for (var i = 0; i < 3; i++) {
            expect(await u.flush(), isFalse);
            backoffs.add(u.currentBackoff);
          }
          expect(await q.length(), 10);
          expect(u.droppedInvalid, 0);
          expect(u.sentCount, 0);
          expect(u.consecutiveFailures, 3);
          expect(backoffs.map((d) => d.inSeconds).toList(), [5, 10, 20]);
          expect(u.lastError, 'Server menolak seluruh batch, titik ditahan');
          expect(_hasCoordinates(u.lastError!), isFalse);
          expect(logs.any(_hasCoordinates), isFalse);

          // Server pulih: semua terkirim, tidak ada yang dibuang.
          api.invalid.clear();
          expect(await u.flush(), isTrue);
          expect(await q.length(), 0);
          expect(u.sentCount, 10);
          expect(u.droppedInvalid, 0);
          expect(u.lastError, isNull);
          expect(u.consecutiveFailures, 0);
          expect(u.currentBackoff, Duration.zero);
          expect(api.received.length, 10);
        },
      );

      test('batch 3 semua ditolak ikut ditahan, bukan dibuang', () async {
        final q = await _filled(3);
        for (var i = 0; i < 3; i++) {
          api.invalid.add(pointAt(i).recordedAt);
        }
        final u = make(q, batchSize: 3);
        expect(await u.flush(), isFalse);
        expect(await q.length(), 3);
        expect(u.droppedInvalid, 0);
      });

      test('batch 2 semua buruk: dibuang, antrean kosong', () async {
        final q = await _filled(2);
        for (var i = 0; i < 2; i++) {
          api.invalid.add(pointAt(i).recordedAt);
        }
        final u = make(q, batchSize: 2);
        expect(await u.flush(), isTrue);
        expect(await q.length(), 0);
        expect(u.droppedInvalid, 2);
        expect(u.sentCount, 0);
        expect(u.lastError, isNull);
        expect(u.currentBackoff, Duration.zero);
      });

      test(
        'batch 4 dengan 3 buruk dan 1 sehat: yang sehat terkirim, 3 dibuang',
        () async {
          final q = await _filled(4);
          for (final i in [0, 1, 3]) {
            api.invalid.add(pointAt(i).recordedAt);
          }
          final u = make(q, batchSize: 4);
          expect(await u.flush(), isTrue);
          expect(await q.length(), 0);
          expect(u.droppedInvalid, 3);
          expect(u.sentCount, 1);
        },
      );

      test(
        'titik buruk di batch kedua tidak menyentuh batch pertama',
        () async {
          final q = await _filled(10);
          api.invalid.add(pointAt(8).recordedAt);
          final u = make(q, batchSize: 5);
          expect(await u.flush(), isTrue);
          expect(u.droppedInvalid, 1);
          expect(u.sentCount, 9);
        },
      );

      test(
        'kesalahan jaringan tidak memicu bisect dan tidak membuang apa pun',
        () async {
          final q = await _filled(10);
          api.failing = true;
          final u = make(q, batchSize: 10);
          expect(await u.flush(), isFalse);
          expect(api.calls, 1);
          expect(await q.length(), 10);
          expect(u.droppedInvalid, 0);
          expect(u.consecutiveFailures, 1);
          expect(u.currentBackoff, greaterThan(Duration.zero));
        },
      );

      test(
        'jaringan putus di tengah bisect: tidak ada yang hilang, lanjut saat pulih',
        () async {
          final q = await _filled(10);
          api.invalid.add(pointAt(4).recordedAt);
          api.failOnCalls.add(4); // putus di tengah isolasi
          final u = make(q, batchSize: 10);
          expect(await u.flush(), isFalse);
          expect(u.consecutiveFailures, 1);
          final sentBefore = u.sentCount;
          final queuedBefore = await q.length();
          expect(sentBefore + queuedBefore + u.droppedInvalid, 10);

          expect(await u.flush(), isTrue);
          expect(await q.length(), 0);
          expect(u.droppedInvalid, 1);
          expect(u.sentCount, 9);
          expect(u.lastError, isNull);
          expect(api.received.map((p) => p.recordedAt).toSet().length, 9);
        },
      );

      test('TrackingController menampilkan droppedInvalid di state', () {
        fakeAsync((async) {
          final base = DateTime.utc(2026, 1, 1);
          final queue = InMemoryPointQueue();
          final source = SimulatedLocationSource(
            now: () => base.add(async.elapsed),
          );
          api.invalid.add(base.add(const Duration(seconds: 6)));
          final controller = TrackingController(
            source: source,
            queue: queue,
            uploader: LocationUploader(queue: queue, api: api, jitter: () => 0),
            log: logs.add,
          );
          final total = source.plannedPointCount;
          controller.start();
          async.elapse(Duration(seconds: total * 3 + 60));
          final s = controller.state;
          expect(s.droppedInvalid, 1);
          expect(s.sent, total - 1);
          expect(s.queued, 0);
          expect(s.lastError, isNull);
          expect(logs.any(_hasCoordinates), isFalse);
          controller.dispose();
        });
      });
    },
  );

  group('TrackingController (ujung ke ujung dengan rute simulasi)', () {
    test('putus di tengah rute lalu nyala: semua titik terkirim berurutan', () {
      fakeAsync((async) {
        final base = DateTime.utc(2026, 1, 1);
        final logs = <String>[];
        final queue = InMemoryPointQueue();
        final source = SimulatedLocationSource(
          now: () => base.add(async.elapsed),
        );
        final uploader = LocationUploader(
          queue: queue,
          api: api,
          jitter: () => 0,
          log: logs.add,
        );
        final controller = TrackingController(
          source: source,
          queue: queue,
          uploader: uploader,
          log: logs.add,
        );
        final total = source.plannedPointCount;

        controller.start();
        async.elapse(const Duration(seconds: 30));
        expect(controller.state.sent, greaterThan(0));

        api.failing = true; // jaringan putus
        async.elapse(const Duration(seconds: 60));
        expect(controller.state.queued, greaterThan(0));
        expect(controller.state.lastError, isNotNull);
        final sentBefore = controller.state.sent;

        api.failing = false; // nyala lagi
        async.elapse(Duration(seconds: total * 3 + 400));
        final s = controller.state;
        expect(s.queued, 0);
        expect(s.sent, total);
        expect(s.sent, greaterThan(sentBefore));
        expect(s.lastError, isNull);
        expect(s.dropped, 0);

        // Server menerima semua titik rute, urut waktu, tanpa duplikat.
        final times = api.received.map((p) => p.recordedAt).toList();
        expect(times.length, total);
        expect(times.toSet().length, total);
        expect([...times]..sort(), times);
        expect(logs.any(_hasCoordinates), isFalse);

        controller.dispose();
      });
    });

    test(
      'onCompleted disambung ke controller.stop: titik terakhir tetap masuk',
      () {
        fakeAsync((async) {
          final base = DateTime.utc(2026, 1, 1);
          final queue = InMemoryPointQueue();
          late final TrackingController controller;
          final source = SimulatedLocationSource(
            now: () => base.add(async.elapsed),
            onCompleted: () => unawaited(controller.stop()),
          );
          controller = TrackingController(
            source: source,
            queue: queue,
            uploader: LocationUploader(queue: queue, api: api, jitter: () => 0),
            log: (_) {},
          );
          final total = source.plannedPointCount;

          controller.start();
          async.elapse(Duration(seconds: total * 3 + 60));

          final s = controller.state;
          expect(s.queued, 0);
          expect(s.sent, total);
          final times = api.received.map((p) => p.recordedAt).toList();
          expect(times.length, total);
          expect(times.toSet().length, total);
          controller.dispose();
        });
      },
    );

    test('antrean penuh membuang tertua dan mencatat hitungannya', () {
      fakeAsync((async) {
        final base = DateTime.utc(2026, 1, 1);
        final logs = <String>[];
        final queue = InMemoryPointQueue(capacity: 5);
        api.failing = true;
        final source = SimulatedLocationSource(
          now: () => base.add(async.elapsed),
        );
        final controller = TrackingController(
          source: source,
          queue: queue,
          uploader: LocationUploader(queue: queue, api: api, jitter: () => 0),
          log: logs.add,
        );
        controller.start();
        async.elapse(const Duration(seconds: 60));
        expect(controller.state.queued, 5);
        expect(controller.state.dropped, greaterThan(0));
        expect(logs.any((l) => l.contains('dibuang')), isTrue);
        expect(logs.any(_hasCoordinates), isFalse);
        controller.dispose();
      });
    });
  });
}
