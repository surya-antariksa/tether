import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
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

/// Dialog satu alur: hitung mundur darurat dengan Obsidian glass HUD,
/// mengirim, lalu hasil.
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
    final muted = AppColors.textSecondary.resolveFrom(context);

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alert Badge Pill
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 2, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .resolveFrom(context)
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppColors.danger
                        .resolveFrom(context)
                        .withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.warning,
                        size: 11,
                        color: AppColors.danger.resolveFrom(context),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PROTOKOL DARURAT DIAKTIFKAN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Circular Radial Countdown Timer
            Center(
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer siren aura glow
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFFF334B,
                          ).withValues(alpha: 0.08),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.20),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      // Radial progress ring
                      CustomPaint(
                        size: const Size(86, 86),
                        painter: _CountdownRingPainter(
                          progress: s.secondsLeft / 5.0,
                          color: AppColors.danger.resolveFrom(context),
                          trackColor: const Color(0x33261014),
                        ),
                      ),
                      // Inside Center HUD
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${s.secondsLeft}',
                            key: const ValueKey('sos-countdown-number'),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              color: CupertinoColors.white,
                              shadows: [
                                Shadow(
                                  color: AppColors.danger
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.80),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'DETIK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppColors.danger.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Body text
            const Text(
              SafetyStrings.countdownBody,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // Recipient Preview Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.systemGrey4.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniAvatar(label: 'G', color: Color(0xFF0F766E)),
                      _MiniAvatar(label: 'R', color: Color(0xFF7C3AED)),
                      _MiniAvatar(
                        icon: Symbols.call,
                        color: AppColors.danger.resolveFrom(context),
                      ),
                    ],
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Penerima: Circle & 112',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Jalur siaga tinggi',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.success.resolveFrom(context),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Symbols.sensors,
                    size: 14,
                    color: AppColors.tint.resolveFrom(context),
                  ),
                ],
              ),
            ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            if (!reduce) ...[
              const CupertinoActivityIndicator(radius: 14),
              const SizedBox(height: 14),
            ],
            const Text(SafetyStrings.sendingBody, textAlign: TextAlign.center),
          ],
        );

      case SosPhase.sent:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.sentTitle),
        );
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.check_circle,
              size: 38,
              color: AppColors.success.resolveFrom(context),
            ),
            const SizedBox(height: 10),
            Text(
              SafetyStrings.sentBody(s.circles),
              textAlign: TextAlign.center,
            ),
          ],
        );
        actions = [_doneAction(context, ref)];

      case SosPhase.queued:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.queuedTitle),
        );
        content = const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.schedule, size: 38, color: Color(0xFFFBBF24)),
            SizedBox(height: 10),
            Text(SafetyStrings.queuedBody, textAlign: TextAlign.center),
          ],
        );
        actions = [_doneAction(context, ref)];

      case SosPhase.failed:
        title = Semantics(
          liveRegion: true,
          child: const Text(SafetyStrings.failedTitle),
        );
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.error,
              size: 38,
              color: AppColors.danger.resolveFrom(context),
            ),
            const SizedBox(height: 8),
            Text(
              s.failure == SosFailure.noLocation
                  ? SafetyStrings.noLocation
                  : SafetyStrings.sosError(s.error ?? SafetyErrorKind.unknown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: TextStyle(color: muted),
              child: const Text(
                SafetyStrings.emergencyHint,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
        actions = [_doneAction(context, ref)];
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
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

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({this.label, this.icon, required this.color});

  final String? label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: CupertinoColors.white, width: 1.2),
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, size: 10, color: CupertinoColors.white)
            : Text(
                label ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
      ),
    );
  }
}
