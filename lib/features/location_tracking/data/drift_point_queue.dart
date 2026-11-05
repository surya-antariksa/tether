import 'package:drift/drift.dart';

import '../domain/location_point.dart';
import 'location_database.dart';
import 'point_queue.dart';

/// Antrean berbasis SQLite (drift).
class DriftPointQueue implements PointQueue {
  DriftPointQueue(this._db, {this.capacity = defaultQueueCapacity});

  final LocationDatabase _db;
  final int capacity;
  int _dropped = 0;

  @override
  int get droppedCount => _dropped;

  @override
  Future<void> enqueue(LocationPoint point) async {
    await _db.transaction(() async {
      await _db
          .into(_db.queuedPoints)
          .insert(
            QueuedPointsCompanion.insert(
              lat: point.lat,
              lng: point.lng,
              accuracyM: Value(point.accuracyM),
              speedMps: Value(point.speedMps),
              batteryPct: Value(point.batteryPct),
              isMoving: point.isMoving,
              recordedAtUs: point.recordedAt.microsecondsSinceEpoch,
            ),
          );
      final count = await length();
      final overflow = count - capacity;
      if (overflow > 0) {
        final oldest = _db.selectOnly(_db.queuedPoints)
          ..addColumns([_db.queuedPoints.id])
          ..orderBy(_order)
          ..limit(overflow);
        final ids = await oldest.map((r) => r.read(_db.queuedPoints.id)!).get();
        await (_db.delete(_db.queuedPoints)..where((t) => t.id.isIn(ids))).go();
        _dropped += ids.length;
      }
    });
  }

  @override
  Future<List<QueuedPoint>> peekBatch(int max) async {
    final rows =
        await (_db.select(_db.queuedPoints)
              ..orderBy([
                (t) => OrderingTerm.asc(t.recordedAtUs),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(max))
            .get();
    return rows
        .map(
          (r) => QueuedPoint(
            r.id,
            LocationPoint(
              lat: r.lat,
              lng: r.lng,
              accuracyM: r.accuracyM,
              speedMps: r.speedMps,
              batteryPct: r.batteryPct,
              isMoving: r.isMoving,
              recordedAt: DateTime.fromMicrosecondsSinceEpoch(
                r.recordedAtUs,
                isUtc: true,
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Future<void> ack(List<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.queuedPoints)..where((t) => t.id.isIn(ids))).go();
  }

  @override
  Future<int> length() async {
    final count = _db.queuedPoints.id.count();
    final row = await (_db.selectOnly(
      _db.queuedPoints,
    )..addColumns([count])).getSingle();
    return row.read(count)!;
  }

  List<OrderingTerm> get _order => [
    OrderingTerm.asc(_db.queuedPoints.recordedAtUs),
    OrderingTerm.asc(_db.queuedPoints.id),
  ];
}
