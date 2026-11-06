import 'package:flutter/cupertino.dart';

/// Token warna desain "dark cyan glass" (docs/10, patokan di
/// docs/design/ui). Mode gelap = palet mockup apa adanya. Mode terang =
/// turunan yang bersih: latar putih/abu muda, satu aksen teal tua, tanpa
/// cahaya (glow) dan tanpa gradasi warna-warni.
/// Urutan varian: terang, gelap, terang kontras tinggi, gelap kontras tinggi.
abstract final class AppColors {
  // Aksen merek. Gelap: cyan #00F2FE. Terang: teal tua #00696F (6,4:1 di putih).
  static const tint = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'tint',
    color: Color(0xFF00696F),
    darkColor: Color(0xFF00F2FE),
    highContrastColor: Color(0xFF004F53),
    darkHighContrastColor: Color(0xFF6FF6FF),
  );

  // Teks/ikon di atas isi tint. Gelap: #00373A (on-primary mockup).
  static const onTint = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'onTint',
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF00373A),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF002022),
  );

  // Ujung kedua gradasi tombol utama (surface-tint). Terang: sama dengan tint
  // supaya tombol rata (tanpa gradasi).
  static const tintEnd = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'tintEnd',
    color: Color(0xFF00696F),
    darkColor: Color(0xFF00DCE6),
    highContrastColor: Color(0xFF004F53),
    darkHighContrastColor: Color(0xFF00DCE6),
  );

  // Hijau aman (secondary mockup #4EDEA3 di gelap).
  static const success = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'success',
    color: Color(0xFF047857),
    darkColor: Color(0xFF4EDEA3),
    highContrastColor: Color(0xFF065F46),
    darkHighContrastColor: Color(0xFF6FFBBE),
  );
  static const onSuccess = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'onSuccess',
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF003824),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF002113),
  );

  static const warning = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'warning',
    color: Color(0xFFB45309),
    darkColor: Color(0xFFFBBF24),
    highContrastColor: Color(0xFF92400E),
    darkHighContrastColor: Color(0xFFFCD34D),
  );
  static const onWarning = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'onWarning',
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF000000),
  );

  // Destruktif. Gelap: #F87171 (DESIGN.md). Terang: merah tegas tapi tenang.
  static const danger = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'danger',
    color: Color(0xFFC62828),
    darkColor: Color(0xFFF87171),
    highContrastColor: Color(0xFF9B1C1C),
    darkHighContrastColor: Color(0xFFFCA5A5),
  );

  // Latar. Gelap: surface #0F131C, grouped = surface-container-lowest
  // #0A0E16, kartu = surface-container #1C2028.
  static const background = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'background',
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF0F131C),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF0F131C),
  );
  static const groupedBackground =
      CupertinoDynamicColor.withBrightnessAndContrast(
        debugLabel: 'groupedBackground',
        color: Color(0xFFF4F6F8),
        darkColor: Color(0xFF0A0E16),
        highContrastColor: Color(0xFFF4F6F8),
        darkHighContrastColor: Color(0xFF0A0E16),
      );
  static const groupedItemBackground =
      CupertinoDynamicColor.withBrightnessAndContrast(
        debugLabel: 'groupedItemBackground',
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF1C2028),
        highContrastColor: Color(0xFFFFFFFF),
        darkHighContrastColor: Color(0xFF1C2028),
      );

  // Permukaan tinggi: chip, badge, pill filter pasif (surface-container-high).
  static const surfaceHigh = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'surfaceHigh',
    color: Color(0xFFEEF1F4),
    darkColor: Color(0xFF262A33),
    highContrastColor: Color(0xFFE2E7EC),
    darkHighContrastColor: Color(0xFF31353E),
  );

  // Teks.
  static const textPrimary = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'textPrimary',
    color: Color(0xFF0F172A),
    darkColor: Color(0xFFDFE2EE),
    highContrastColor: Color(0xFF000000),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );
  static const textSecondary = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'textSecondary',
    color: Color(0xFF475569),
    darkColor: Color(0xFFB9CACB),
    highContrastColor: Color(0xFF334155),
    darkHighContrastColor: Color(0xFFD5E3E4),
  );
  // Teks tersier: waktu, ikon pasif (outline mockup #849495).
  static const textTertiary = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'textTertiary',
    color: Color(0xFF64748B),
    darkColor: Color(0xFF849495),
    highContrastColor: Color(0xFF475569),
    darkHighContrastColor: Color(0xFFB9CACB),
  );

  // Garis (outline-variant #3A494B di gelap).
  static const separator = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'separator',
    color: Color(0xFFE2E8F0),
    darkColor: Color(0xFF3A494B),
    highContrastColor: Color(0xFFCBD5E1),
    darkHighContrastColor: Color(0xFF849495),
  );

  // Kaca melayang di atas peta (HUD, sheet, tab bar).
  static const glassFill = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'glassFill',
    color: Color(0xE6FFFFFF),
    darkColor: Color(0xCC0A0E16),
    highContrastColor: Color(0xFFFFFFFF),
    darkHighContrastColor: Color(0xFF0A0E16),
  );
  // Tepi kaca: putih 10% di gelap, hitam 8% di terang.
  static const glassBorder = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'glassBorder',
    color: Color(0x14000000),
    darkColor: Color(0x1AFFFFFF),
    highContrastColor: Color(0x66000000),
    darkHighContrastColor: Color(0x66FFFFFF),
  );

  /// Gelap? Dipakai untuk efek yang hanya ada di gelap (cahaya, gradasi).
  static bool isDark(BuildContext context) =>
      CupertinoTheme.maybeBrightnessOf(context) == Brightness.dark;
}
