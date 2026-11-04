import '../domain/location_point.dart';

/// Batas bawaan antrean. Bila penuh, titik TERTUA dibuang.
const int defaultQueueCapacity = 5000;

class QueuedPoint {
  const QueuedPoint(this.id, this.point);

  final int id;
  final LocationPoint point;
}

/// Antrean titik yang menunggu diunggah. Urutan peekBatch menurut
/// recordedAt naik (seri diputus oleh id).
abstract class PointQueue {
  Future<void> enqueue(LocationPoint point);
  Future<List<QueuedPoint>> peekBatch(int max);

  /// Hapus titik yang sudah terkirim. Id yang tidak ada diabaikan.
  Future<void> ack(List<int> ids);
  Future<int> length();

  /// Total titik tertua yang dibuang karena antrean penuh sejak dibuat.
  int get droppedCount;
}

class InMemoryPointQueue implements PointQueue {
  InMemoryPointQueue({this.capacity = defaultQueueCapacity});

  final int capacity;
  final List<QueuedPoint> _items = [];
  int _nextId = 1;
  int _dropped = 0;

  @override
  int get droppedCount => _dropped;

  @override
  Future<void> enqueue(LocationPoint point) async {
    _items.add(QueuedPoint(_nextId++, point));
    _items.sort(_byTime);
    final overflow = _items.length - capacity;
    if (overflow > 0) {
      _items.removeRange(0, overflow);
      _dropped += overflow;
    }
  }

  @override
  Future<List<QueuedPoint>> peekBatch(int max) async =>
      _items.take(max).toList();

  @override
  Future<void> ack(List<int> ids) async {
    final set = ids.toSet();
    _items.removeWhere((q) => set.contains(q.id));
  }

  @override
  Future<int> length() async => _items.length;

  static int _byTime(QueuedPoint a, QueuedPoint b) {
    final c = a.point.recordedAt.compareTo(b.point.recordedAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }
}
