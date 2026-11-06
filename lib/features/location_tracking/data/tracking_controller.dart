import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/location_point.dart';
import '../domain/location_source.dart';
import 'location_uploader.dart';
import 'point_queue.dart';

/// Potret status pelacakan untuk UI. Tidak memuat koordinat.
class TrackingState {
  const TrackingState({
    this.running = false,
    this.queued = 0,
    this.sent = 0,
    this.skippedByServer = 0,
    this.dropped = 0,
    this.droppedInvalid = 0,
    this.lastError,
    this.backoff = Duration.zero,
  });

  final bool running;
  final int queued;
  final int sent;

  /// Titik terkirim yang dilewati server (duplikat atau lebih tua dari 30 hari).
  final int skippedByServer;

  /// Titik tertua yang dibuang karena antrean penuh.
  final int dropped;

  /// Titik yang dibuang karena server menolaknya sebagai tidak valid.
  final int droppedInvalid;
  final String? lastError;
  final Duration backoff;
}

/// Menyambungkan LocationSource -> PointQueue -> LocationUploader.
class TrackingController extends ChangeNotifier {
  TrackingController({
    required this._source,
    required this._queue,
    required this._uploader,
    void Function(String message)? log,
  }) : _log = log ?? debugPrint {
    _uploader.onChanged = _refresh;
  }

  final LocationSource _source;
  final PointQueue _queue;
  final LocationUploader _uploader;
  final void Function(String message) _log;

  StreamSubscription<LocationPoint>? _sub;
  TrackingState _state = const TrackingState();
  int _loggedDropped = 0;
  bool _disposed = false;

  TrackingState get state => _state;

  Future<void> start() async {
    if (_sub != null) return;
    _sub = _source.points.listen(_onPoint);
    await _source.start();
    await _refresh();
    // Sisa antrean dari sesi lalu (SQLite persisten) ikut dikirim.
    _uploader.requestFlush();
  }

  /// Berhenti mengumpulkan titik. Antrean yang tersisa tetap dicoba kirim.
  Future<void> stop() async {
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
    await _source.stop();
    await _refresh();
  }

  Future<void> _onPoint(LocationPoint point) async {
    try {
      await _queue.enqueue(point);
    } catch (e) {
      _log('gagal mengantre titik (${e.runtimeType})');
    }
    final dropped = _queue.droppedCount;
    if (dropped > _loggedDropped) {
      _log(
        'antrean penuh: ${dropped - _loggedDropped} titik tertua dibuang '
        '(total $dropped)',
      );
      _loggedDropped = dropped;
    }
    await _refresh();
    _uploader.requestFlush();
  }

  Future<void> _refresh() async {
    final queued = await _queue.length();
    if (_disposed) return;
    _state = TrackingState(
      running: _sub != null,
      queued: queued,
      sent: _uploader.sentCount,
      skippedByServer: _uploader.skippedByServer,
      dropped: _queue.droppedCount,
      droppedInvalid: _uploader.droppedInvalid,
      lastError: _uploader.lastError,
      backoff: _uploader.currentBackoff,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    _uploader.onChanged = null;
    _uploader.dispose();
    super.dispose();
  }
}
