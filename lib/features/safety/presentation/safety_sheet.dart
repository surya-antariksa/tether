import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
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
      icon: Symbols.shield,
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
    final secondary = AppColors.textSecondary.resolveFrom(context);

    final String? status = switch (checkin) {
      CheckinDone(:final kind) => SafetyStrings.checkinDone(kind),
      CheckinFailed(:final error) => SafetyStrings.checkinError(error),
      CheckinSending() => SafetyStrings.checkinSending,
      CheckinIdle() when id == null => SafetyStrings.noCircleSelected,
      CheckinIdle() => null,
    };

    void send(CheckinKind kind) =>
        ref.read(checkinControllerProvider.notifier).send(kind, circleId: id);

    return _SheetSurface(
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
                    style: AppTextStyles.title2(context),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    SafetyStrings.checkinHeader.toUpperCase(),
                    style: AppTextStyles.labelMd(
                      context,
                      color: secondary,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SafetyStrings.checkinHint,
                  style: AppTextStyles.footnote(context, color: secondary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoDynamicColor.resolve(
                      AppColors.groupedItemBackground,
                      context,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      _CheckinButton(
                        kind: CheckinKind.arrived,
                        filled: true,
                        onPressed: id == null || sending
                            ? null
                            : () => send(CheckinKind.arrived),
                      ),
                      const SizedBox(height: 10),
                      _CheckinButton(
                        kind: CheckinKind.safe,
                        filled: false,
                        onPressed: id == null || sending
                            ? null
                            : () => send(CheckinKind.safe),
                      ),
                    ],
                  ),
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
                            ? AppColors.danger.resolveFrom(context)
                            : secondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    SafetyStrings.sosHeader.toUpperCase(),
                    style: AppTextStyles.labelMd(
                      context,
                      color: AppColors.danger,
                    ).copyWith(letterSpacing: 0.8),
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
    final icon = kind == CheckinKind.arrived
        ? Symbols.check_circle
        : Symbols.shield;
    final tint = AppColors.tint.resolveFrom(context);
    final fg = filled ? AppColors.onTint.resolveFrom(context) : tint;
    final label = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, fill: 1, color: fg),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            SafetyStrings.label(kind),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context, emphasized: true, color: fg),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: SafetyStrings.label(kind),
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: filled ? tint : tint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: filled
                  ? null
                  : Border.all(color: tint.withValues(alpha: 0.35)),
            ),
            child: label,
          ),
        ),
      ),
    );
  }
}

/// Latar lembar: kaca obsidian di gelap, putih bersih di terang; sudut atas 28.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(28));
    final dark = AppColors.isDark(context);
    final solid = MediaQuery.highContrastOf(context);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? AppColors.glassFill
                  .resolveFrom(context)
                  .withValues(alpha: solid ? 1 : 0.94)
            : AppColors.background.resolveFrom(context),
        borderRadius: radius,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder.resolveFrom(context)),
        ),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: radius,
      child: dark && !solid
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: body,
            )
          : body,
    );
  }
}
