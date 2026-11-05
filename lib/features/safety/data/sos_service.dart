import 'dart:async';
import 'dart:math';

import '../domain/safety_error.dart';
import '../domain/safety_repository.dart';
import '../domain/sos_location.dart';
import '../domain/sos_models.dart';
import '../domain/sos_queue_store.dart';

/// Jeda coba ulang: 2, 4, 8, 16, 32 detik, lalu tetap 60 detik. [failures]
/// dihitung dari 1.
Duration defaultSosBackoff(int failures) {
  final seconds = 2 * pow(2, max(0, failures - 1)).toInt();
  return Duration(seconds: min(seconds, 60));
}

/// Mengambil posisi, memicu SOS, dan menjaga antrean offline.
///
/// Urutan: SOS dicatat di [SosQueueStore] LEBIH DULU (dengan clientId dan
/// triggeredAt dari saat dipicu), baru dikirim. Gagal sementara (jaringan,
/// sesi, galat tak dikenal) membiarkannya di antrean dan dicoba ulang dengan
/// backoff sampai berhasil atau lewat [maxAge]. Gagal permanen (batas laju,
/// tanpa Circle, bukan anggota, argumen ditolak) dibuang. Mengulang aman karena
/// trigger_sos idempoten menurut clientId. Koordinat tidak pernah dicatat ke
/// log atau pesan galat. Bila penyimpanan antrean gagal, SOS tetap dicoba
/// kirim; bila itu gagal sementara juga, hasilnya [SosRejected] dengan
/// [SafetyErrorKind.notSaved] (tidak ada yang bisa diulang otomatis), bukan
/// [SosQueued].
class SosService {
  SosService({
    required this.repository,
    required this.store,
    required this.location,
    required this.currentUserId,
    DateTime Function()? now,
    String Function()? newId,
    Duration Function(int failures)? backoff,
    this.maxAge = const Duration(days: 1),
    this.locationTimeout = const Duration(seconds: 10),
    this.triggerTimeout = const Duration(seconds: 15),
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? generateUuidV4,
       _backoff = backoff ?? defaultSosBackoff;

  final SafetyRepository repository;
  final SosQueueStore store;
  final SosLocationProvider location;
  final String? Function() currentUserId;

  /// Usia maksimum SOS di antrean. Sama dengan batas jepit triggered_at di
  /// server (1 hari); lebih tua dari itu tidak ada gunanya dikirim.
  final Duration maxAge;
  final Duration locationTimeout;

  /// Batas satu panggilan trigger_sos; lewat dari ini dianggap galat sementara
  /// (antre dan coba ulang), agar panggilan menggantung tidak menahan antrean
  /// serial maupun dialog.
  final Duration triggerTimeout;

  final DateTime Function() _now;
  final String Function() _newId;
  final Duration Function(int) _backoff;

  final _deliveries = StreamController<SosDelivery>.broadcast();
  Future<void> _tail = Future.value();
  Timer? _timer;
  int _failures = 0;
  bool _disposed = false;

  /// Hasil akhir tiap SOS (terkirim atau ditolak), termasuk dari coba ulang.
  Stream<SosDelivery> get deliveries => _deliveries.stream;

  /// Posisi saat ini (dengan batas waktu), bila gagal posisi terakhir yang
  /// diketahui. Null bila tidak ada sama sekali: jangan mengirim koordinat
  /// palsu.
  Future<SosFix?> acquireFix() async {
    SosFix? fix;
    try {
      fix = await location.current().timeout(
        locationTimeout,
        onTimeout: () => null,
      );
    } catch (_) {}
    if (fix != null && fix.isValid) return fix;
    try {
      fix = await location.lastKnown().timeout(
        locationTimeout,
        onTimeout: () => null,
      );
    } catch (_) {
      fix = null;
    }
    return fix != null && fix.isValid ? fix : null;
  }

  /// Memicu SOS sekarang: clientId dan triggeredAt dibuat di sini.
  Future<SosOutcome> send(SosFix fix) async {
    final uid = currentUserId();
    if (uid == null) return const SosRejected(SafetyErrorKind.notSignedIn);
    if (!fix.isValid) return const SosRejected(SafetyErrorKind.invalidArgument);
    final sos = PendingSos(
      clientId: _newId(),
      userId: uid,
      triggeredAt: _now().toUtc(),
      fix: fix,
    );
    var stored = true;
    try {
      await store.add(sos);
    } catch (_) {
      // Penyimpanan gagal: tetap coba kirim sekarang, tetapi jangan pernah
      // melaporkan "tersimpan" (lihat _attempt).
      stored = false;
    }
    return _locked(() => _attempt(sos, stored: stored));
  }

  /// Mengirim ulang semua SOS tertunda milik pengguna saat ini, urut dari
  /// yang tertua. Berhenti pada kegagalan sementara pertama (jadwal ulang
  /// dengan backoff).
  Future<void> flush() => _locked(() async {
    final uid = currentUserId();
    if (uid == null || _disposed) return;
    List<PendingSos> items;
    try {
      items = await store.load();
    } catch (_) {
      return;
    }
    for (final sos in items) {
      if (sos.userId != uid) continue; // bukan milik akun ini; jangan kirim
      final outcome = await _attempt(sos);
      if (outcome is SosQueued) break;
    }
  });

  Future<T> _locked<T>(Future<T> Function() op) {
    final r = _tail.then((_) => op());
    _tail = r.then((_) {}, onError: (Object _) {});
    return r;
  }

  Future<SosOutcome> _attempt(PendingSos sos, {bool stored = true}) async {
    if (_now().difference(sos.triggeredAt) > maxAge) {
      await _discard(sos);
      return _finish(sos, const SosRejected(SafetyErrorKind.expired));
    }
    try {
      final circles = await repository
          .triggerSos(
            lat: sos.fix.lat,
            lng: sos.fix.lng,
            accuracyM: sos.fix.accuracyM,
            clientId: sos.clientId,
            triggeredAt: sos.triggeredAt,
          )
          .timeout(triggerTimeout);
      _failures = 0;
      await _discard(sos);
      return _finish(sos, SosSent(circles));
    } catch (e) {
      final err = e is SafetyError
          ? e
          : const SafetyError(SafetyErrorKind.unknown);
      if (err.isTransient && !stored) {
        // Tidak terkirim dan tidak tersimpan: tidak ada yang bisa diulang.
        return _finish(sos, const SosRejected(SafetyErrorKind.notSaved));
      }
      if (err.isTransient) {
        _failures++;
        _scheduleRetry();
        return SosQueued(sos.clientId);
      }
      await _discard(sos);
      return _finish(sos, SosRejected(err.kind));
    }
  }

  SosOutcome _finish(PendingSos sos, SosOutcome outcome) {
    if (!_disposed) _deliveries.add(SosDelivery(sos.clientId, outcome));
    return outcome;
  }

  Future<void> _discard(PendingSos sos) async {
    try {
      await store.remove(sos.clientId);
    } catch (_) {}
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(_backoff(_failures), () => unawaited(flush()));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _deliveries.close();
  }
}
