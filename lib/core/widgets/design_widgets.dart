import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Lencana bulat kecil dengan titik berwarna ("Realtime", "Aktif",
/// "Terkoneksi"). Latar surfaceHigh, garis tipis, tanpa warna mencolok.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, this.dotColor});

  final String text;

  /// Titik di kiri teks; null = tanpa titik.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final dot = dotColor == null
        ? null
        : CupertinoDynamicColor.resolve(dotColor!, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.separator.resolveFrom(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                boxShadow: AppColors.isDark(context)
                    ? [
                        BoxShadow(
                          color: dot.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(text, style: AppTextStyles.caption2(context, emphasized: true)),
        ],
      ),
    );
  }
}

/// Pill pemilih Circle: ikon grup, nama, panah bila bisa ganti.
class CirclePill extends StatelessWidget {
  const CirclePill({
    super.key,
    required this.name,
    required this.canSwitch,
    required this.onTap,
    required this.semanticLabel,
  });

  final String name;
  final bool canSwitch;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: canSwitch,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 180),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  Icon(
                    Symbols.groups,
                    fill: 1,
                    size: 16,
                    color: AppColors.tint.resolveFrom(context),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMd(context),
                    ),
                  ),
                  if (canSwitch) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Symbols.expand_more,
                      size: 16,
                      color: AppColors.textSecondary.resolveFrom(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol pill utama: gradasi cyan di gelap dengan cahaya tipis, isi rata
/// teal di terang. Tinggi 40 (kecil) atau 48 (penuh lebar).
class TintPillButton extends StatelessWidget {
  const TintPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final tint = AppColors.tint.resolveFrom(context);
    final end = AppColors.tintEnd.resolveFrom(context);
    final on = AppColors.onTint.resolveFrom(context);
    final enabled = onPressed != null && !busy;
    final height = expand ? 48.0 : 40.0;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          CupertinoActivityIndicator(color: on)
        else if (icon != null)
          Icon(icon, fill: 1, size: 16, color: on),
        if (busy || icon != null) const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMd(context, color: on),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onPressed : null,
          child: Container(
            height: height,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: dark
                  ? LinearGradient(colors: [tint, end])
                  : LinearGradient(colors: [tint, tint]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: dark
                  ? [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Pill filter/segmen. Aktif = isi tint; pasif = surfaceHigh.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final tint = AppColors.tint.resolveFrom(context);
    final fg = selected
        ? AppColors.onTint.resolveFrom(context)
        : AppColors.textSecondary.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? tint
                    : AppColors.surfaceHigh.resolveFrom(context),
                borderRadius: BorderRadius.circular(999),
                border: selected
                    ? null
                    : Border.all(
                        color: AppColors.separator.resolveFrom(context),
                      ),
                boxShadow: selected && dark
                    ? [
                        BoxShadow(
                          color: tint.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTextStyles.caption1(
                      context,
                      emphasized: selected,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotak ikon 44x44 radius 12 dengan latar warna aksen lembut dan border tipis.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize = 24,
    this.filled = true,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = CupertinoDynamicColor.resolve(color, context);
    final dark = AppColors.isDark(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.withValues(alpha: dark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: dark ? 0.3 : 0.18)),
          boxShadow: dark
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.24),
                    blurRadius: 20,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, fill: filled ? 1 : 0, size: iconSize, color: c),
      ),
    );
  }
}

/// Judul bagian kecil huruf kapital ("HARI INI", "ANGGOTA").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              container: true,
              child: Text(
                text.toUpperCase(),
                style: AppTextStyles.caption2(
                  context,
                  color: AppColors.textTertiary,
                ).copyWith(letterSpacing: 0.7),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Latar halaman: warna dasar + dua lingkaran cahaya samar di gelap. Terang =
/// polos tanpa hiasan.
class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({super.key, required this.child, this.color});

  final Widget child;
  final CupertinoDynamicColor? color;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final base = (color ?? AppColors.groupedBackground).resolveFrom(context);
    if (!dark) return ColoredBox(color: base, child: child);
    final tint = AppColors.tint.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        gradient: RadialGradient(
          center: const Alignment(0, -1.1),
          radius: 1.0,
          colors: [tint.withValues(alpha: 0.08), tint.withValues(alpha: 0)],
        ),
      ),
      child: child,
    );
  }
}
