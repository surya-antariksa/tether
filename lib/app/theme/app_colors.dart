import 'package:flutter/cupertino.dart';

/// Token warna dari docs/08 bagian 3.2. Latar, teks, dan pemisah memakai
/// warna dinamis bawaan Cupertino; hanya merek dan status yang berhex.
/// Urutan varian: terang, gelap, terang kontras tinggi, gelap kontras tinggi.
abstract final class AppColors {
  // Merek (teal).
  static const tint = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'tint',
    color: Color(0xFF0F766E),
    darkColor: Color(0xFF2DD4BF),
    highContrastColor: Color(0xFF0B5C55),
    darkHighContrastColor: Color(0xFF5EEAD4),
  );

  // Teks/ikon di atas latar tint: putih di terang, hitam di gelap
  // (putih di atas #2DD4BF hanya 1,9:1).
  static const onTint = _onFilled;

  static const success = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'success',
    color: Color(0xFF15803D),
    darkColor: Color(0xFF30D158),
    highContrastColor: Color(0xFF166534),
    darkHighContrastColor: Color(0xFF4ADE80),
  );
  static const onSuccess = _onFilled;

  static const warning = CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'warning',
    color: Color(0xFFB45309),
    darkColor: Color(0xFFFBBF24),
    highContrastColor: Color(0xFF92400E),
    darkHighContrastColor: Color(0xFFFCD34D),
  );
  static const onWarning = _onFilled;

  static const danger = CupertinoColors.systemRed;

  // Latar, teks, pemisah: bawaan sistem.
  static const background = CupertinoColors.systemBackground;
  static const groupedBackground = CupertinoColors.systemGroupedBackground;
  static const groupedItemBackground =
      CupertinoColors.secondarySystemGroupedBackground;
  static const textPrimary = CupertinoColors.label;
  static const textSecondary = CupertinoColors.secondaryLabel;
  static const separator = CupertinoColors.separator;

  static const _onFilled = CupertinoDynamicColor.withBrightnessAndContrast(
    color: CupertinoColors.white,
    darkColor: CupertinoColors.black,
    highContrastColor: CupertinoColors.white,
    darkHighContrastColor: CupertinoColors.black,
  );
}
