import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/data/drift_point_queue.dart';
import 'package:tether/features/location_tracking/data/location_database.dart';
import 'package:tether/features/location_tracking/data/point_queue.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';

import 'fakes.dart';

/// Suite kontrak yang sama untuk semua implementasi PointQueue.
void pointQueueContract(
  String name,
  PointQueue Function(int capacity) create, {
  Future<void> Function()? cleanUp,
}) {
  group('PointQueue kontrak: $name', () {
    if (cleanUp != null) tearDown(cleanUp);

    test('kosong di awal', () async {
      final q = create(100);
      expect(await q.length(), 0);
      expect(await q.peekBatch(10), isEmpty);
      expect(q.droppedCount, 0);
    });

    test('enqueue menambah length, peekBatch tidak menghapus', () async {
      final q = create(100);
      for (var i = 0; i < 3; i++) {
        await q.enqueue(pointAt(i));
      }
      expect(await q.length(), 3);
      expect((await q.peekBatch(10)).length, 3);
      expect(await q.length(), 3);
    });

    test('peekBatch urut recordedAt naik walau masuk acak', () async {
      final q = create(100);
      for (final i in [3, 0, 4, 1, 2]) {
        await q.enqueue(pointAt(i));
      }
      final batch = await q.peekBatch(10);
      expect(batch.map((e) => e.point.recordedAt).toList(), [
        for (var i = 0; i < 5; i++) pointAt(i).recordedAt,
      ]);
    });

    test('peekBatch menghormati batas max', () async {
      final q = create(100);
      for (var i = 0; i < 5; i++) {
        await q.enqueue(pointAt(i));
      }
      final batch = await q.peekBatch(2);
      expect(batch.map((e) => e.point.recordedAt), [
        pointAt(0).recordedAt,
        pointAt(1).recordedAt,
      ]);
    });

    test('id unik', () async {
      final q = create(100);
      for (var i = 0; i < 5; i++) {
        await q.enqueue(pointAt(i));
      }
      final ids = (await q.peekBatch(10)).map((e) => e.id).toSet();
      expect(ids.length, 5);
    });

    test('ack hanya menghapus id yang diberikan', () async {
      final q = create(100);
      for (var i = 0; i < 4; i++) {
        await q.enqueue(pointAt(i));
      }
      final batch = await q.peekBatch(4);
      await q.ack([batch[0].id, batch[2].id]);
      final rest = await q.peekBatch(10);
      expect(rest.map((e) => e.id), [batch[1].id, batch[3].id]);
      expect(await q.length(), 2);
    });

    test('ack id tidak dikenal atau kosong diabaikan', () async {
      final q = create(100);
      await q.enqueue(pointAt(0));
      await q.ack([]);
      await q.ack([999999]);
      expect(await q.length(), 1);
    });

    test('field bertahan utuh (UTC, mikrodetik, nullable)', () async {
      final q = create(100);
      final full = LocationPoint(
        lat: -6.2001,
        lng: 106.8168,
        accuracyM: 4.5,
        speedMps: 1.25,
        batteryPct: 42,
        isMoving: true,
        recordedAt: DateTime.utc(2026, 5, 6, 7, 8, 9, 123, 456),
      );
      final sparse = LocationPoint(
        lat: 1,
        lng: 2,
        isMoving: false,
        recordedAt: DateTime.utc(2026, 5, 6, 7, 8, 10),
      );
      await q.enqueue(full);
      await q.enqueue(sparse);
      final got = await q.peekBatch(2);
      expect(got[0].point.toJson(), full.toJson());
      expect(got[0].point.recordedAt.isUtc, isTrue);
      expect(got[0].point.recordedAt, full.recordedAt);
      expect(got[1].point.toJson(), sparse.toJson());
    });

    test('penuh: membuang yang tertua dan menghitung', () async {
      final q = create(3);
      for (var i = 0; i < 5; i++) {
        await q.enqueue(pointAt(i));
      }
      expect(await q.length(), 3);
      expect(q.droppedCount, 2);
      final batch = await q.peekBatch(10);
      expect(batch.map((e) => e.point.recordedAt), [
        for (var i = 2; i < 5; i++) pointAt(i).recordedAt,
      ]);
    });

    test('penuh: yang tertua menurut recordedAt, bukan urutan masuk', () async {
      final q = create(2);
      await q.enqueue(pointAt(5));
      await q.enqueue(pointAt(6));
      await q.enqueue(pointAt(1)); // paling lama, langsung terbuang
      expect(q.droppedCount, 1);
      expect((await q.peekBatch(10)).map((e) => e.point.recordedAt), [
        pointAt(5).recordedAt,
        pointAt(6).recordedAt,
      ]);
    });
  });
}

void main() {
  pointQueueContract(
    'InMemoryPointQueue',
    (c) => InMemoryPointQueue(capacity: c),
  );

  final dbs = <LocationDatabase>[];
  pointQueueContract(
    'DriftPointQueue (SQLite memori)',
    (c) {
      final db = LocationDatabase.inMemory();
      dbs.add(db);
      return DriftPointQueue(db, capacity: c);
    },
    cleanUp: () async {
      for (final db in dbs) {
        await db.close();
      }
      dbs.clear();
    },
  );
}
