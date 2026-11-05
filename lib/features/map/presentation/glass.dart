import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// Permukaan gaya kaca ringan untuk kontrol melayang di atas peta (lapisan
/// fungsional, docs/08 bagian 2): blur + tint tipis, garis tipis dan bayangan
/// untuk kontras. Memakai warna solid bila kontras tinggi diminta sistem.
/// Bukan Liquid Glass asli.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.highContrastOf(context);
    final base = CupertinoColors.systemBackground.resolveFrom(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? base : base.withValues(alpha: 0.72),
        borderRadius: borderRadius,
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: solid
          ? ClipRRect(borderRadius: borderRadius, child: surface)
          : ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: surface,
              ),
            ),
    );
  }
}

/// Tombol ikon bulat di atas [GlassSurface], area sentuh 44x44 pt. Nonaktif
/// bila [onPressed] null (tetap terlihat, dipudarkan).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// Label VoiceOver.
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(22),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onPressed,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? CupertinoColors.label.resolveFrom(context)
                : CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
