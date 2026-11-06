import 'dart:async';
import 'dart:math';

import 'location_api.dart';
import 'point_queue.dart';

/// Ukuran batch maksimal yang diterima server.
const int maxServerBatchSize = 500;

/// Batch seukuran ini atau lebih yang ditolak seluruhnya dianggap kegagalan
/// sistemik (mis. jam perangkat), bukan semua titiknya buruk.
const int _minBatchForSystemicCheck = 3;

/// Mengosongkan [PointQueue] ke [LocationApi] per batch. Batch yang gagal
/// tetap di antrean dan dicoba lagi dengan backoff eksponensial. Batch yang
/// ditolak server karena datanya tidak valid ([InvalidBatchException]) dibelah
/// dua berulang sampai titik buruknya ketemu, lalu hanya titik itu dibuang. Bila
/// batch berukuran >= 3 ditolak seluruhnya, tidak ada yang dibuang (backoff).
class LocationUploader {
  LocationUploader({
    required this._queue,
    required this._api,
    int batchSize = 50,
    this.initialBackoff = const Duration(seconds: 5),
    this.maxBackoff = const Duration(minutes: 5),
    double Function()? jitter,
    void Function(String message)? log,
    this.onChanged,
  }) : batchSize = batchSize.clamp(1, maxServerBatchSize),
       _jitter = jitter ?? Random().nextDouble,
       _log = log ?? ((_) {});

  final PointQueue _queue;
  final LocationApi _api;
  final int batchSize;
  final Duration initialBackoff;
  final Duration maxBackoff;

  /// Mengembalikan nilai [0, 1). Menambah hingga 20% pada jeda backoff.
  final double Function() _jitter;
  final void Function(String message) _log;

  /// Dipanggil setiap status (terkirim, error, backoff) berubah.
  void Function()? onChanged;

  Future<bool>? _inFlight;
  Timer? _retryTimer;
  bool _disposed = false;

  int _sentCount = 0;
  int _skippedByServer = 0;
  int _droppedInvalid = 0;
  int _consecutiveFailures = 0;
  Duration _backoff = Duration.zero;
  String? _lastError;

  /// Titik yang benar-benar masuk di server (nilai kembalian uploadBatch).
  int get sentCount => _sentCount;

  /// Titik terkirim yang dilewati server (duplikat atau lebih tua dari 30 hari).
  int get skippedByServer => _skippedByServer;

  /// Titik yang dibuang karena server menolaknya sebagai tidak valid.
  int get droppedInvalid => _droppedInvalid;
  int get consecutiveFailures => _consecutiveFailures;

  /// Jeda sebelum percobaan berikutnya (nol bila tidak sedang gagal).
  Duration get currentBackoff => _backoff;

  /// Pesan error terakhir (tanpa koordinat), null bila terakhir sukses.
  String? get lastError => _lastError;
  bool get isFlushing => _inFlight != null;

  /// Minta flush kecuali sedang menunggu backoff atau sedang berjalan.
  void requestFlush() {
    if (_disposed || _retryTimer != null || _inFlight != null) return;
    unawaited(flush());
  }

  /// Kirim batch sampai antrean kosong atau ada kegagalan. Mengembalikan true
  /// bila antrean kosong. Bila sudah berjalan, memakai flush yang sama.
  Future<bool> flush() => _inFlight ??= _drain().whenComplete(() {
    _inFlight = null;
  });

  Future<bool> _drain() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    while (true) {
      final List<QueuedPoint> batch;
      try {
        batch = await _queue.peekBatch(batchSize);
        if (batch.isEmpty) return true;
        await _sendIsolatingInvalid(batch);
      } catch (e) {
        _onFailure(e);
        return false;
      }
      _consecutiveFailures = 0;
      _backoff = Duration.zero;
      _lastError = null;
      _notify();
    }
  }

  /// Kirim [batch]. Bila ditolak sebagai tidak valid, belah dua dan kirim tiap
  /// separuh (rekursif). Hasil dikumpulkan dulu, baru diputuskan: bila ada titik
  /// yang diterima, titik terkirim dan titik yang terbukti buruk di-ack. Bila
  /// batch berukuran >= 3 ditolak seluruhnya, itu kegagalan sistemik (bukan
  /// titik buruk), jadi tidak ada yang di-ack dan dibuang; error dilempar agar
  /// ditangani sebagai kegagalan sementara dengan backoff. Kesalahan lain naik
  /// ke pemanggil tanpa meng-ack apa pun (kiriman ulang aman, server idempoten).
  Future<void> _sendIsolatingInvalid(List<QueuedPoint> batch) async {
    final result = _BisectResult();
    await _bisect(batch, result);
    if (batch.length >= _minBatchForSystemicCheck && result.accepted == 0) {
      throw const LocationApiException(
        'Server menolak seluruh batch, titik ditahan',
      );
    }
    // Bila ack gagal, titik terkirim ulang nanti (server idempoten).
    await _queue.ack([...result.sentIds, ...result.badIds]);
    _sentCount += result.inserted;
    _skippedByServer += max(0, result.accepted - result.inserted);
    if (result.badIds.isNotEmpty) {
      _droppedInvalid += result.badIds.length;
      _log(
        '${result.badIds.length} titik tidak valid dibuang '
        '(total $_droppedInvalid)',
      );
    }
    _notify();
  }

  Future<void> _bisect(List<QueuedPoint> batch, _BisectResult result) async {
    try {
      final inserted = await _api.uploadBatch(
        batch.map((q) => q.point).toList(),
      );
      result.sentIds.addAll(batch.map((q) => q.id));
      result.accepted += batch.length;
      result.inserted += inserted;
    } on InvalidBatchException {
      if (batch.length == 1) {
        result.badIds.add(batch.single.id);
      } else {
        final mid = batch.length ~/ 2;
        await _bisect(batch.sublist(0, mid), result);
        await _bisect(batch.sublist(mid), result);
      }
    }
  }

  void _onFailure(Object e) {
    _consecutiveFailures++;
    // Hanya jenis kesalahan atau pesan LocationApiException (aman), tidak
    // pernah toString() eksepsi lain yang bisa memuat data titik.
    _lastError = e is LocationApiException
        ? e.message
        : 'unggah gagal (${e.runtimeType})';
    // Eksponen dibatasi agar tidak meluap.
    final factor = pow(2, min(_consecutiveFailures - 1, 20)).toDouble();
    final base = initialBackoff * factor;
    final jittered = base * (1 + 0.2 * _jitter());
    _backoff = jittered > maxBackoff ? maxBackoff : jittered;
    _log(
      'unggah gagal ($_consecutiveFailures berturut-turut): $_lastError, '
      'coba lagi dalam ${_backoff.inSeconds} detik',
    );
    if (!_disposed) {
      _retryTimer = Timer(_backoff, () {
        _retryTimer = null;
        unawaited(flush());
      });
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) onChanged?.call();
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Hasil bisect satu batch, dikumpulkan sebelum ada yang di-ack.
class _BisectResult {
  final sentIds = <int>[];
  final badIds = <int>[];

  /// Jumlah titik yang diterima server (termasuk yang dilewati).
  int accepted = 0;

  /// Jumlah baris yang benar-benar masuk menurut server.
  int inserted = 0;
}
