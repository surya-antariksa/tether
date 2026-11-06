import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/app_colors.dart';

/// Permukaan kaca untuk kontrol melayang di atas peta (docs/10): blur, isi
/// berkabut, tepi tipis. Gelap = kaca obsidian; terang = putih bersih tanpa
/// bayangan berat. Memakai warna solid bila kontras tinggi diminta sistem.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.blur = 16,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.highContrastOf(context);
    final dark = AppColors.isDark(context);
    final fill = AppColors.glassFill.resolveFrom(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(
          color: AppColors.glassBorder.resolveFrom(context),
          width: 1,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Color(dark ? 0x59000000 : 0x14000000),
            blurRadius: dark ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: solid
          ? ClipRRect(borderRadius: borderRadius, child: surface)
          : ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
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

  /// Label pembaca layar.
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
                ? AppColors.textPrimary.resolveFrom(context)
                : AppColors.textTertiary.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
