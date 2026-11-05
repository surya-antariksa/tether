import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selected_circle.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../activity/data/activity_providers.dart';
import '../../activity/domain/notification_gateway.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/safety_error.dart';
import '../domain/safety_repository.dart';
import '../domain/sos_location.dart';
import '../domain/sos_models.dart';
import '../domain/sos_queue_store.dart';
import '../presentation/safety_strings.dart';
import 'file_sos_queue_store.dart';
import '../../tracking/domain/tracking_platform.dart';
import 'geolocator_sos_location.dart';
import 'simulated_sos_location.dart';
import 'sos_service.dart';
import 'supabase_safety_repository.dart';

/// Override di tes dengan repository palsu.
final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SupabaseSafetyRepository(ref.watch(supabaseClientProvider)),
);

/// Override di tes: tes tidak boleh memanggil plugin lokasi nyata.
final sosLocationProvider = Provider<SosLocationProvider>(
  (ref) => _useSimulatedLocation
      ? const SimulatedSosLocation()
      : const GeolocatorSosLocation(),
);

/// Simulasi hanya dengan flag SIMULATE_LOCATION, atau build debug di desktop
/// (geolocator tidak mendukung lokasi di Linux).
bool get _useSimulatedLocation =>
    simulateLocationFlag ||
    (kDebugMode &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows));

/// Umpan balik haptic. Override di tes (plugin platform tidak ada di tes).
abstract class SosHaptics {
  /// Tiap detik selama menahan.
  void holdTick();

  /// Tahan selesai, hitung mundur mulai.
  void holdComplete();

  /// Tiap detik hitung mundur.
  void countdownTick();
}

class PlatformSosHaptics implements SosHaptics {
  const PlatformSosHaptics();

  @override
  void holdTick() => _run(HapticFeedback.selectionClick);

  @override
  void holdComplete() => _run(HapticFeedback.heavyImpact);

  @override
  void countdownTick() => _run(HapticFeedback.lightImpact);

  static void _run(Future<void> Function() f) {
    try {
      unawaited(f().catchError((Object _) {}));
    } catch (_) {}
  }
}

final sosHapticsProvider = Provider<SosHaptics>(
  (ref) => const PlatformSosHaptics(),
);

/// Antrean persisten, dibuka sekali. Bila berkas gagal ditentukan, memori
/// (SOS yang tertunda hilang bila aplikasi ditutup; sangat jarang).
final sosQueueStoreProvider = FutureProvider<SosQueueStore>((ref) async {
  try {
    return await FileSosQueueStore.openDefault();
  } catch (_) {
    debugPrint('[safety] antrean SOS berkas gagal dibuka, memakai memori');
    return InMemorySosQueueStore();
  }
}, retry: (_, _) => null);

/// Layanan SOS. Saat dibuat dan setiap kali pengguna masuk, SOS tertunda
/// dikirim ulang; baca provider ini sedini mungkin (mis. saat tab Peta tampil)
/// agar antrean sisa sesi lalu terkirim.
final sosServiceProvider = FutureProvider<SosService>((ref) async {
  final store = await ref.watch(sosQueueStoreProvider.future);
  final service = SosService(
    repository: ref.watch(safetyRepositoryProvider),
    store: store,
    location: ref.watch(sosLocationProvider),
    currentUserId: () => ref.read(currentUserIdProvider),
  );
  ref.onDispose(service.dispose);
  ref.listen(currentUserIdProvider, (_, id) {
    if (id != null) unawaited(service.flush());
  });
  unawaited(service.flush());
  return service;
}, retry: (_, _) => null);

// ---------------------------------------------------------------- check-in

sealed class CheckinState {
  const CheckinState();
}

final class CheckinIdle extends CheckinState {
  const CheckinIdle();
}

final class CheckinSending extends CheckinState {
  const CheckinSending(this.kind);

  final CheckinKind kind;
}

final class CheckinDone extends CheckinState {
  const CheckinDone(this.kind);

  final CheckinKind kind;
}

final class CheckinFailed extends CheckinState {
  const CheckinFailed(this.error);

  final SafetyErrorKind error;
}

class CheckinController extends Notifier<CheckinState> {
  int _epoch = 0;

  /// Status check-in milik satu Circle dan satu tampilan lembar: kembali ke
  /// awal saat Circle terpilih berubah (build ulang) atau lembar ditutup
  /// (autoDispose), agar status basi tidak terbawa.
  @override
  CheckinState build() {
    ref.watch(selectedCircleIdProvider);
    _epoch++;
    return const CheckinIdle();
  }

  /// Check-in ke [circleId], atau Circle terpilih bila null. Tanpa Circle:
  /// galat notMember (tidak ada yang dikirim).
  Future<void> send(CheckinKind kind, {String? circleId}) async {
    if (state is CheckinSending) return;
    final id = circleId ?? ref.read(selectedCircleIdProvider);
    if (id == null) {
      state = const CheckinFailed(SafetyErrorKind.notMember);
      return;
    }
    state = CheckinSending(kind);
    final epoch = _epoch;
    try {
      await ref.read(safetyRepositoryProvider).checkin(id, kind);
      if (ref.mounted && epoch == _epoch) state = CheckinDone(kind);
    } catch (e) {
      if (!ref.mounted || epoch != _epoch) return;
      state = CheckinFailed(
        e is SafetyError ? e.kind : SafetyErrorKind.unknown,
      );
    }
  }

  void reset() => state = const CheckinIdle();
}

final checkinControllerProvider =
    NotifierProvider.autoDispose<CheckinController, CheckinState>(
      CheckinController.new,
    );

// --------------------------------------------------------------------- SOS

enum SosPhase { idle, countdown, sending, sent, queued, failed }

/// Penyebab gagal khusus SOS di luar [SafetyErrorKind].
enum SosFailure { noLocation, error }

class SosState {
  const SosState({
    this.phase = SosPhase.idle,
    this.secondsLeft = 0,
    this.circles = 0,
    this.failure,
    this.error,
  });

  final SosPhase phase;
  final int secondsLeft;

  /// Jumlah Circle yang diberi tahu (fase sent).
  final int circles;
  final SosFailure? failure;
  final SafetyErrorKind? error;

  bool get isBusy => phase == SosPhase.countdown || phase == SosPhase.sending;
}

/// Alur SOS setelah ditahan: hitung mundur 5 detik (bisa dibatalkan), ambil
/// posisi, kirim. Lokasi mulai diambil saat hitung mundur dimulai.
class SosController extends Notifier<SosState> {
  static const countdownSeconds = 5;

  /// Batas pengaman fase "mengirim": layanan sudah punya batas waktu sendiri
  /// (lokasi dan trigger_sos); ini jaring terakhir agar dialog tidak macet.
  static const sendingDeadline = Duration(seconds: 45);

  Timer? _timer;
  Timer? _deadline;
  Future<SosFix?>? _fix;
  StreamSubscription<SosDelivery>? _sub;
  SosService? _subService;
  int _generation = 0;

  /// SOS antre yang hasil akhirnya ditunggu: clientId ke generasi alur.
  final _awaiting = <String, int>{};

  @override
  SosState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _deadline?.cancel();
      _sub?.cancel();
    });
    return const SosState();
  }

  /// Mulai hitung mundur. Diabaikan bila alur sedang berjalan.
  void beginCountdown() {
    if (state.phase != SosPhase.idle) return;
    final gen = ++_generation;
    ref.read(sosHapticsProvider).holdComplete();
    state = const SosState(
      phase: SosPhase.countdown,
      secondsLeft: countdownSeconds,
    );
    _fix = ref
        .read(sosServiceProvider.future)
        .then((s) => s.acquireFix())
        .catchError((Object _) => null);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(gen));
  }

  void _tick(int gen) {
    if (gen != _generation || state.phase != SosPhase.countdown) return;
    final left = state.secondsLeft - 1;
    if (left > 0) {
      ref.read(sosHapticsProvider).countdownTick();
      state = SosState(phase: SosPhase.countdown, secondsLeft: left);
      return;
    }
    _timer?.cancel();
    unawaited(_commit(gen));
  }

  /// Batalkan selama hitung mundur. Tidak ada yang terkirim.
  void cancel() {
    if (state.phase != SosPhase.countdown) return;
    _generation++;
    _timer?.cancel();
    _fix = null;
    state = const SosState();
  }

  /// Tutup hasil akhir (terkirim, antre, gagal) kembali ke awal. SOS yang
  /// masih antre tetap dipantau: bila akhirnya ditolak permanen, pengguna
  /// diberi tahu lewat notifikasi lokal.
  void dismiss() {
    if (state.isBusy) return;
    state = const SosState();
  }

  /// Fase "mengirim" melewati batas pengaman: hentikan penantian dialog dengan
  /// hasil gagal yang jujur (belum tentu terkirim, jangan mengaku tersimpan).
  void _sendingTimedOut(int gen) {
    if (gen != _generation || state.phase != SosPhase.sending || !ref.mounted) {
      return;
    }
    _generation++; // hasil terlambat dari alur ini tidak menimpa tampilan
    state = const SosState(
      phase: SosPhase.failed,
      failure: SosFailure.error,
      error: SafetyErrorKind.network,
    );
  }

  Future<void> _commit(int gen) async {
    state = const SosState(phase: SosPhase.sending);
    _deadline?.cancel();
    _deadline = Timer(sendingDeadline, () => _sendingTimedOut(gen));
    final SosService service;
    try {
      service = await ref.read(sosServiceProvider.future);
    } catch (_) {
      _deadline?.cancel();
      if (gen == _generation && ref.mounted) {
        state = const SosState(
          phase: SosPhase.failed,
          failure: SosFailure.error,
          error: SafetyErrorKind.unknown,
        );
      }
      return;
    }
    final fix = await _fix;
    _fix = null;
    if (gen != _generation || !ref.mounted) return;
    if (fix == null) {
      _deadline?.cancel();
      state = const SosState(
        phase: SosPhase.failed,
        failure: SosFailure.noLocation,
      );
      return;
    }
    final outcome = await service.send(fix);
    _deadline?.cancel();
    if (!ref.mounted) return;
    if (gen != _generation) {
      // Dialog sudah menyerah menunggu (batas pengaman): hasil yang tetap
      // penting bagi pengguna disampaikan di luar dialog.
      if (outcome is SosQueued) {
        _watchLateResult(service, gen, outcome.clientId);
      } else if (outcome is SosRejected) {
        _notifyRejected(generateUuidV4(), outcome.kind);
      }
      return;
    }
    state = switch (outcome) {
      SosSent(:final circles) => SosState(
        phase: SosPhase.sent,
        circles: circles,
      ),
      SosQueued() => const SosState(phase: SosPhase.queued),
      SosRejected(:final kind) => SosState(
        phase: SosPhase.failed,
        failure: SosFailure.error,
        error: kind,
      ),
    };
    if (outcome is SosQueued) _watchLateResult(service, gen, outcome.clientId);
  }

  /// SOS yang antre bisa selesai belakangan (terkirim atau ditolak). Selama
  /// dialog masih menampilkannya, perbarui tampilan; bila sudah ditutup, hasil
  /// ditolak permanen (TH007, TH008, kedaluwarsa, ...) disampaikan lewat
  /// notifikasi lokal supaya pengguna tahu SOS-nya tidak sampai.
  void _watchLateResult(SosService service, int gen, String clientId) {
    _awaiting[clientId] = gen;
    if (_subService == service && _sub != null) return;
    _sub?.cancel();
    _subService = service;
    _sub = service.deliveries.listen((d) {
      final g = _awaiting.remove(d.clientId);
      if (g == null || !ref.mounted) return;
      final showing = g == _generation && state.phase == SosPhase.queued;
      switch (d.outcome) {
        case SosSent(:final circles):
          if (showing) state = SosState(phase: SosPhase.sent, circles: circles);
        case SosRejected(:final kind):
          if (showing) {
            state = SosState(
              phase: SosPhase.failed,
              failure: SosFailure.error,
              error: kind,
            );
          } else {
            _notifyRejected(d.clientId, kind);
          }
        case SosQueued():
          break;
      }
    });
  }

  void _notifyRejected(String clientId, SafetyErrorKind kind) {
    final gateway = ref.read(notificationGatewayProvider);
    unawaited(() async {
      try {
        await gateway.initialize();
        await gateway.show(
          LocalNotification(
            id: clientId.hashCode & 0x7fffffff,
            title: SafetyStrings.sosRejectedNotificationTitle,
            body:
                '${SafetyStrings.sosError(kind)} '
                '${SafetyStrings.emergencyHint}',
            urgency: NotificationUrgency.high,
          ),
        );
      } catch (_) {}
    }());
  }
}

final sosControllerProvider = NotifierProvider<SosController, SosState>(
  SosController.new,
);
