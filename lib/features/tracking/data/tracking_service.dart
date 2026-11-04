import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../location_tracking/data/location_uploader.dart';
import '../../location_tracking/data/tracking_controller.dart';
import '../domain/permission_gateway.dart';
import '../domain/tracking_platform.dart';
import '../domain/tracking_status.dart';
import 'geolocator_location_source.dart';
import 'tracking_providers.dart';

/// Alasan layanan belum boleh berjalan, atau null bila semua syarat terpenuhi:
/// sudah masuk, ada sumber lokasi, izin diberikan (hanya untuk GPS), dan punya
/// minimal satu keanggotaan Circle. [permission] dan [hasCircle] null berarti
/// belum diketahui (menunggu).
TrackingStatus? blockingStatus({
  required bool signedIn,
  required LocationSourceKind kind,
  required AppPermissionStatus? permission,
  required bool? hasCircle,
}) {
  if (!signedIn) return TrackingStatus.idle;
  if (kind == LocationSourceKind.unavailable) return TrackingStatus.unavailable;
  if (kind == LocationSourceKind.geolocator) {
    if (permission == null) return TrackingStatus.idle;
    if (!permission.isGranted) return TrackingStatus.needsPermission;
  }
  if (hasCircle == null) return TrackingStatus.idle;
  if (!hasCircle) return TrackingStatus.needsCircle;
  return null;
}

/// Selang cek ulang keanggotaan Circle saat belum punya (atau query gagal).
const Duration circleRecheckInterval = Duration(seconds: 30);

/// Mengatur siklus hidup pengiriman lokasi: memulai [TrackingController] saat
/// syarat terpenuhi dan menghentikannya saat salah satu hilang (mis. keluar
/// akun). Server yang menegakkan jeda; klien tetap berjalan.
///
/// Provider ini baru aktif setelah dibaca pertama kali (overlay peta atau
/// halaman onboarding membacanya), lalu bertahan sampai ProviderScope ditutup.
class TrackingService extends Notifier<TrackingSnapshot> {
  TrackingController? _controller;
  int _run = 0;
  String? _lastUserId;
  Future<void> _discarding = Future.value();
  Timer? _recheck;

  @override
  TrackingSnapshot build() {
    final uid = ref.watch(currentUserIdProvider);
    final kind = ref.watch(locationSourceKindProvider);
    final permission = ref.watch(locationPermissionProvider);
    final membership = ref.watch(hasCircleMembershipProvider);
    ref.listen(sourceProblemProvider, (_, _) => _publish());
    ref.onDispose(_teardown);

    // Titik milik pengguna lama tidak boleh terkirim atas nama pengguna baru.
    if (_lastUserId != null && uid != _lastUserId) {
      _discarding = Future(_discardQueue);
    }
    _lastUserId = uid;

    final hasCircle = membership.hasValue ? membership.value : null;
    final blocked = blockingStatus(
      signedIn: uid != null,
      kind: kind,
      permission: permission,
      hasCircle: hasCircle,
    );
    if (blocked != null) {
      final waitingForCircle =
          uid != null &&
          kind != LocationSourceKind.unavailable &&
          (blocked == TrackingStatus.needsCircle || membership.hasError);
      if (waitingForCircle) {
        _recheck = Timer(
          circleRecheckInterval,
          () => ref.invalidate(hasCircleMembershipProvider),
        );
      }
      return TrackingSnapshot(status: blocked);
    }
    final run = ++_run;
    unawaited(_start(run));
    return const TrackingSnapshot();
  }

  bool _current(int run) => ref.mounted && run == _run;

  Future<void> _start(int run) async {
    try {
      final queue = await ref.read(pointQueueProvider.future);
      await _discarding;
      if (!_current(run)) return;
      ref.read(sourceProblemProvider.notifier).report(null);
      final uploader = LocationUploader(
        queue: queue,
        api: ref.read(locationApiProvider),
        log: _log,
      );
      final controller = TrackingController(
        source: ref.read(locationSourceProvider),
        queue: queue,
        uploader: uploader,
        log: _log,
      );
      _controller = controller;
      controller.addListener(_publish);
      await controller.start();
      _publish();
    } catch (e) {
      if (!_current(run)) return;
      _log('gagal memulai pelacakan (${e.runtimeType})');
      state = TrackingSnapshot(
        status: TrackingStatus.error,
        detail: describeSourceError(e),
      );
    }
  }

  void _publish() {
    final c = _controller;
    if (c == null || !ref.mounted) return;
    final s = c.state;
    final problem = ref.read(sourceProblemProvider);
    final status = problem != null
        ? TrackingStatus.error
        : (s.lastError != null && s.queued > 0)
        ? TrackingStatus.offlineWithQueue
        : s.running
        ? TrackingStatus.running
        : TrackingStatus.idle;
    state = TrackingSnapshot(
      status: status,
      queued: s.queued,
      sent: s.sent,
      skippedByServer: s.skippedByServer,
      dropped: s.dropped,
      droppedInvalid: s.droppedInvalid,
      lastError: s.lastError,
      detail: problem,
    );
  }

  Future<void> _discardQueue() async {
    try {
      final queue = await ref.read(pointQueueProvider.future);
      while (true) {
        final batch = await queue.peekBatch(maxServerBatchSize);
        if (batch.isEmpty) break;
        await queue.ack([for (final q in batch) q.id]);
      }
    } catch (e) {
      _log('gagal mengosongkan antrean (${e.runtimeType})');
    }
  }

  void _teardown() {
    _run++;
    _recheck?.cancel();
    _recheck = null;
    final c = _controller;
    _controller = null;
    if (c == null) return;
    c.removeListener(_publish);
    unawaited(c.stop().catchError((Object _) {}).whenComplete(c.dispose));
  }

  void _log(String message) => debugPrint('[tracking] $message');
}

final trackingServiceProvider =
    NotifierProvider<TrackingService, TrackingSnapshot>(TrackingService.new);
