import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';

/// Kartu kaca untuk daftar dan kartu isi (docs/10: `.glass-card`).
/// Gelap: isi berkabut + blur tipis + tepi putih 8%. Terang: kartu putih
/// polos dengan garis tipis, tanpa blur dan tanpa cahaya.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.glow,
    this.accentLeft,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Cahaya tepi (hanya tampil di mode gelap).
  final Color? glow;

  /// Garis aksen di sisi kiri (kartu "milik Anda").
  final Color? accentLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final solid = MediaQuery.highContrastOf(context);
    final r = BorderRadius.circular(radius);
    final fill = dark
        ? AppColors.groupedItemBackground
              .resolveFrom(context)
              .withValues(alpha: solid ? 1 : 0.72)
        : AppColors.groupedItemBackground.resolveFrom(context);
    final border = dark
        ? const Color(0x14FFFFFF)
        : AppColors.separator.resolveFrom(context);
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: r,
        border: Border.all(color: border),
      ),
      child: child,
    );
    if (accentLeft != null) {
      body = ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            body,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: accentLeft),
            ),
          ],
        ),
      );
    }
    if (dark && !solid) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: body,
        ),
      );
    }
    if (dark && glow != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: glow!.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: -6,
            ),
          ],
        ),
        child: body,
      );
    }
    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}
