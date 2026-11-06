import 'dart:math' as math;

import '../../location_tracking/domain/geo.dart';
import 'history_point.dart';

/// Ringkasan satu rangkaian titik (urut waktu naik). Semua dihitung dari
/// data yang tercatat; tidak ada nilai karangan. Kecepatan memakai angka GPS
/// bila ada, kalau tidak dihitung dari jarak dan selang waktu antar titik.
class RouteStats {
  const RouteStats({
    required this.count,
    required this.distanceM,
    required this.duration,
    required this.movingDuration,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.start,
    required this.end,
  });

  final int count;
  final double distanceM;
  final Duration duration;

  /// Jumlah selang waktu antar titik yang berstatus bergerak.
  final Duration movingDuration;

  /// Rata-rata kecepatan saat bergerak (km/jam); 0 bila tidak ada gerak.
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final DateTime? start;
  final DateTime? end;

  static const empty = RouteStats(
    count: 0,
    distanceM: 0,
    duration: Duration.zero,
    movingDuration: Duration.zero,
    avgSpeedKmh: 0,
    maxSpeedKmh: 0,
    start: null,
    end: null,
  );

  /// Selang antar titik yang lebih dari ini dianggap jeda (bukan gerak
  /// berkesinambungan) dan tidak dihitung ke jarak atau durasi bergerak.
  static const maxGap = Duration(minutes: 10);

  /// [points] harus urut waktu NAIK.
  static RouteStats of(List<HistoryPoint> points) {
    if (points.isEmpty) return empty;
    var dist = 0.0;
    var moving = Duration.zero;
    var maxKmh = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final dt = b.recordedAt.difference(a.recordedAt);
      if (dt <= Duration.zero || dt > maxGap) continue;
      final seg = haversineMeters(
        a.point.latitude,
        a.point.longitude,
        b.point.latitude,
        b.point.longitude,
      );
      final isMoving = b.isMoving || a.isMoving;
      if (isMoving) {
        dist += seg;
        moving += dt;
      }
      final kmh = b.speedKmh ?? (seg / dt.inMilliseconds * 1000 * 3.6);
      // Lonjakan GPS tak masuk akal (di atas 250 km/jam) diabaikan.
      if (isMoving && kmh <= 250) maxKmh = math.max(maxKmh, kmh);
    }
    final avg = moving.inSeconds > 0 ? dist / moving.inSeconds * 3.6 : 0.0;
    return RouteStats(
      count: points.length,
      distanceM: dist,
      duration: points.last.recordedAt.difference(points.first.recordedAt),
      movingDuration: moving,
      avgSpeedKmh: avg,
      maxSpeedKmh: maxKmh,
      start: points.first.recordedAt,
      end: points.last.recordedAt,
    );
  }
}

/// Kelompokkan titik (urutan bebas) per hari kalender, hari terbaru dulu;
/// di dalam hari urut waktu naik.
List<(DateTime, List<HistoryPoint>)> groupByDay(List<HistoryPoint> points) {
  final map = <DateTime, List<HistoryPoint>>{};
  for (final p in points) {
    final d = DateTime(p.recordedAt.year, p.recordedAt.month, p.recordedAt.day);
    map.putIfAbsent(d, () => []).add(p);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      (d, map[d]!..sort((a, b) => a.recordedAt.compareTo(b.recordedAt))),
  ];
}
