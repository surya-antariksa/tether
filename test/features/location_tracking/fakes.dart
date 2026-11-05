import 'dart:async';

import 'package:tether/features/location_tracking/data/location_api.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';

/// Titik uji dengan koordinat khas agar mudah dicari di log.
LocationPoint pointAt(int i, {DateTime? at}) => LocationPoint(
  lat: -6.2000 - i * 0.0001,
  lng: 106.8167 + i * 0.0001,
  accuracyM: 5,
  speedMps: 2,
  batteryPct: 80,
  isMoving: true,
  recordedAt: at ?? DateTime.utc(2026, 1, 1, 0, 0, i),
);

class FakeLocationApi implements LocationApi {
  /// Semua titik yang diterima server, berurutan (termasuk kiriman ulang).
  final List<LocationPoint> received = [];
  int calls = 0;
  int concurrent = 0;
  int maxConcurrent = 0;

  /// Bila true, setiap panggilan gagal.
  bool failing = false;

  /// Nomor panggilan (mulai 1) yang harus gagal.
  final Set<int> failOnCalls = {};

  /// Titik (menurut recordedAt) yang ditolak server: satu saja di batch
  /// menggagalkan seluruh batch dengan [InvalidBatchException].
  final Set<DateTime> invalid = {};

  /// Bila diisi, menentukan jumlah baris yang "masuk" (nilai kembalian) untuk
  /// batch yang diterima; bawaan: sebesar batch.
  int Function(List<LocationPoint> points)? insertedFor;

  /// Bila diisi, panggilan menunggu completer ini.
  Completer<void>? gate;

  @override
  Future<int> uploadBatch(List<LocationPoint> points) async {
    final call = ++calls;
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    try {
      await gate?.future;
      if (failing || failOnCalls.contains(call)) {
        throw Exception('gagal di ${points.first.lat},${points.first.lng}');
      }
      if (points.any((p) => invalid.contains(p.recordedAt))) {
        throw const InvalidBatchException('batch ditolak server (uji)');
      }
      received.addAll(points);
      return insertedFor?.call(points) ?? points.length;
    } finally {
      concurrent--;
    }
  }
}
