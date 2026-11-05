import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/safety_providers.dart';
import '../domain/safety_error.dart';
import 'safety_strings.dart';

/// Memulai hitung mundur SOS lalu menampilkan dialognya. Diabaikan bila alur
/// SOS sedang berjalan. Nol efek kirim sebelum hitungan selesai: Batalkan
/// cukup satu ketukan.
void startSosFlow(BuildContext context, WidgetRef ref) {
  final controller = ref.read(sosControllerProvider.notifier);
  if (ref.read(sosControllerProvider).phase != SosPhase.idle) return;
  controller.beginCountdown();
  final reduce = MediaQuery.disableAnimationsOf(context);
  Navigator.of(context, rootNavigator: true).push<void>(
    CupertinoDialogRoute<void>(
      context: context,
      builder: (_) => const SosFlowDialog(),
      // Reduce Motion: muncul tanpa animasi.
      transitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 250),
      transitionBuilder: reduce ? (_, _, _, child) => child : null,
    ),
  );
}

/// Dialog satu alur: hitung mundur, mengirim, lalu hasil. Dibangun dari
/// [sosControllerProvider]; tertutup lewat Batalkan atau Selesai.
class SosFlowDialog extends ConsumerWidget {
  const SosFlowDialog({super.key});

  void _close(BuildContext context, WidgetRef ref) {
    final c = ref.read(sosControllerProvider.notifier);
    final phase = ref.read(sosControllerProvider).phase;
    if (phase == SosPhase.countdown) {
      c.cancel();
    } else {
      c.dismiss();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sosControllerProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);

    final Widget title;
    final Widget content;
    List<Widget> actions = const [];
    switch (s.phase) {
      case SosPhase.idle:
      case SosPhase.countdown:
        title = Semantics(
          liveRegion: true,
          label: SafetyStrings.countdownAnnouncement(s.secondsLeft),
          excludeSemantics: true,
          child: Text(SafetyStrings.countdownTitle(s.secondsLeft)),
        );
        content = Column(
          children: [
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CupertinoColors.systemRed
                      .resolveFrom(context)
                      .withValues(alpha: 0.1),
                  border: Border.all(
                    color: CupertinoColors.systemRed.resolveFrom(context),
                    width: 3.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${s.secondsLeft}',
                    key: const ValueKey('sos-countdown-number'),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(SafetyStrings.countdownBody),
          ],
        );
        actions = [
          CupertinoDialogAction(
            isDestructiveAction: true,
            isDefaultAction: true,
            onPressed: () => _close(context, ref),
            child: const Text(SafetyStrings.cancel),
          ),
        ];
      case SosPhase.sending:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.sending),
        );
        content = Column(
          children: [
            const SizedBox(height: 12),
            if (!reduce) ...[
              const CupertinoActivityIndicator(),
              const SizedBox(height: 12),
            ],
            const Text(SafetyStrings.sendingBody),
          ],
        );
      case SosPhase.sent:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.sentTitle),
        );
        content = Text(SafetyStrings.sentBody(s.circles));
        actions = [_doneAction(context, ref)];
      case SosPhase.queued:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.queuedTitle),
        );
        content = const Text(SafetyStrings.queuedBody);
        actions = [_doneAction(context, ref)];
      case SosPhase.failed:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.failedTitle),
        );
        content = Column(
          children: [
            const SizedBox(height: 8),
            Text(
              s.failure == SosFailure.noLocation
                  ? SafetyStrings.noLocation
                  : SafetyStrings.sosError(s.error ?? SafetyErrorKind.unknown),
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: TextStyle(color: muted),
              child: const Text(SafetyStrings.emergencyHint),
            ),
          ],
        );
        actions = [_doneAction(context, ref)];
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Tombol kembali Android: membatalkan saat hitung mundur, menutup
        // hasil; saat mengirim tidak melakukan apa-apa.
        if (didPop ||
            ref.read(sosControllerProvider).phase == SosPhase.sending) {
          return;
        }
        _close(context, ref);
      },
      child: CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }

  Widget _doneAction(BuildContext context, WidgetRef ref) =>
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: () => _close(context, ref),
        child: const Text(SafetyStrings.done),
      );
}
