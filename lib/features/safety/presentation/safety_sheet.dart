import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../map/presentation/glass.dart';
import '../data/safety_providers.dart';
import '../domain/safety_repository.dart';
import 'safety_strings.dart';
import 'sos_flow_dialog.dart';
import 'sos_hold_button.dart';

/// Tombol kaca untuk peta yang membuka [showSafetySheet]. Area sentuh 44 pt.
/// Memasangnya juga membangunkan layanan SOS sehingga SOS tertunda dari sesi
/// lalu dikirim ulang.
class SafetyActionsButton extends ConsumerWidget {
  const SafetyActionsButton({super.key, this.circleId});

  /// Circle untuk check-in; bila null memakai Circle terpilih.
  final String? circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sosServiceProvider);
    return GlassIconButton(
      icon: CupertinoIcons.shield_fill,
      label: SafetyStrings.entryLabel,
      onPressed: () => showSafetySheet(context, circleId: circleId),
    );
  }
}

/// Lembar Keselamatan: check-in dan SOS.
Future<void> showSafetySheet(BuildContext context, {String? circleId}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => SafetySheet(circleId: circleId),
  );
}

class SafetySheet extends ConsumerWidget {
  const SafetySheet({super.key, this.circleId});

  final String? circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCircleIdProvider);
    final id = circleId ?? selected;
    final checkin = ref.watch(checkinControllerProvider);
    final sending = checkin is CheckinSending;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final String? status = switch (checkin) {
      CheckinDone(:final kind) => SafetyStrings.checkinDone(kind),
      CheckinFailed(:final error) => SafetyStrings.checkinError(error),
      CheckinSending() => SafetyStrings.checkinSending,
      CheckinIdle() when id == null => SafetyStrings.noCircleSelected,
      CheckinIdle() => null,
    };

    void send(CheckinKind kind) =>
        ref.read(checkinControllerProvider.notifier).send(kind, circleId: id);

    return CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    SafetyStrings.sheetTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline(context),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    SafetyStrings.checkinHeader,
                    style: AppTextStyles.subhead(
                      context,
                      emphasized: true,
                      color: secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SafetyStrings.checkinHint,
                  style: AppTextStyles.footnote(context, color: secondary),
                ),
                const SizedBox(height: 8),
                _CheckinButton(
                  kind: CheckinKind.arrived,
                  filled: true,
                  onPressed: id == null || sending
                      ? null
                      : () => send(CheckinKind.arrived),
                ),
                const SizedBox(height: 8),
                _CheckinButton(
                  kind: CheckinKind.safe,
                  filled: false,
                  onPressed: id == null || sending
                      ? null
                      : () => send(CheckinKind.safe),
                ),
                if (status != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      status,
                      key: const ValueKey('checkin-status'),
                      style: AppTextStyles.footnote(
                        context,
                        color: checkin is CheckinFailed
                            ? CupertinoColors.systemRed.resolveFrom(context)
                            : secondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    SafetyStrings.sosHeader,
                    style: AppTextStyles.subhead(
                      context,
                      emphasized: true,
                      color: secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SafetyStrings.sosExplain,
                  style: AppTextStyles.footnote(context, color: secondary),
                ),
                const SizedBox(height: 8),
                SosHoldButton(onActivated: () => startSosFlow(context, ref)),
                if (accessible)
                  CupertinoButton(
                    minimumSize: const Size(44, 44),
                    onPressed: () => startSosFlow(context, ref),
                    child: const Text(SafetyStrings.startWithoutHold),
                  ),
                const SizedBox(height: 8),
                Text(
                  SafetyStrings.sosDisclaimer,
                  key: const ValueKey('sos-disclaimer'),
                  style: AppTextStyles.footnote(context, color: secondary),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  minimumSize: const Size(44, 44),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(SafetyStrings.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckinButton extends StatelessWidget {
  const _CheckinButton({
    required this.kind,
    required this.filled,
    required this.onPressed,
  });

  final CheckinKind kind;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Text(SafetyStrings.label(kind), textAlign: TextAlign.center);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: SafetyStrings.label(kind),
      excludeSemantics: true,
      onTap: onPressed,
      child: filled
          ? CupertinoButton.filled(
              minimumSize: const Size(44, 44),
              onPressed: onPressed,
              child: label,
            )
          : CupertinoButton.tinted(
              minimumSize: const Size(44, 44),
              onPressed: onPressed,
              child: label,
            ),
    );
  }
}
