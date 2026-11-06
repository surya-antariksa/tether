import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Membuka dialog kaca di tengah layar dengan latar digelapkan.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showCupertinoDialog<T>(
  context: context,
  barrierColor: const Color(0xB3000000),
  builder: builder,
);

/// Kartu dialog kaca (docs/10): kotak ikon, judul, pesan, catatan kecil, isi
/// tambahan, dan tombol aksi. Gelap = kaca obsidian berpendar; terang = kartu
/// putih bersih.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    required this.actions,
    this.icon,
    this.accent = AppColors.danger,
    this.message,
    this.note,
    this.child,
  });

  final IconData? icon;

  /// Warna kotak ikon dan titik catatan.
  final CupertinoDynamicColor accent;
  final String title;
  final String? message;

  /// Pil kecil di bawah pesan (mis. "Sesi di perangkat ini dinonaktifkan").
  final String? note;
  final Widget? child;
  final List<GlassDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final solid = MediaQuery.highContrastOf(context);
    final accentColor = accent.resolveFrom(context);
    final large = MediaQuery.textScalerOf(context).scale(16) > 16 * 1.4;
    const radius = BorderRadius.all(Radius.circular(32));
    Widget card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.glassFill
                  .resolveFrom(context)
                  .withValues(alpha: solid ? 1 : 0.94)
            : AppColors.background.resolveFrom(context),
        borderRadius: radius,
        border: Border.all(color: AppColors.glassBorder.resolveFrom(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null)
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: dark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: dark ? 0.35 : 0.22),
                    ),
                    boxShadow: dark
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: -4,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, size: 26, color: accentColor),
                ),
              ),
            ),
          if (icon != null) const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title2(context),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.callout(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.resolveFrom(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.separator.resolveFrom(context),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warning.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        note!,
                        style: AppTextStyles.caption1(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 16), child!],
          const SizedBox(height: 24),
          if (large)
            for (final a in actions.reversed) ...[
              a,
              if (a != actions.first) const SizedBox(height: 10),
            ]
          else
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
        ],
      ),
    );
    if (dark && !solid) {
      card = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: card,
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 342),
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            label: title,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Color(dark ? 0xCC000000 : 0x33000000),
                    blurRadius: 48,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol aksi dialog kaca. [destructive] = merah; [onPressed] null =
/// nonaktif (dipudarkan).
class GlassDialogAction extends StatelessWidget {
  const GlassDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final danger = AppColors.danger.resolveFrom(context);
    final dark = AppColors.isDark(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: destructive
                  ? Color.alphaBlend(
                      danger.withValues(alpha: dark ? 0.2 : 0.1),
                      AppColors.background.resolveFrom(context),
                    )
                  : AppColors.surfaceHigh.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: destructive
                    ? danger.withValues(alpha: 0.4)
                    : AppColors.separator.resolveFrom(context),
              ),
              boxShadow: destructive && dark
                  ? [
                      BoxShadow(
                        color: danger.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMd(
                context,
                color: destructive ? AppColors.danger : AppColors.textPrimary,
              ).copyWith(fontWeight: destructive ? FontWeight.w700 : null),
            ),
          ),
        ),
      ),
    );
  }
}
