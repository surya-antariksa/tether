import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// Gaya teks desain (docs/10 bagian 1). Plus Jakarta Sans untuk judul dan
/// isi, Inter untuk label dan caption. Nama metode dipertahankan dari versi
/// sebelumnya agar pemanggil tidak berubah; pemetaannya:
///
/// largeTitle/title1 = headline-xl 28/34, title2 = headline-lg 22/28,
/// title3/headline = headline-md 18/24, body = body-lg 16/24,
/// callout/subhead = body-md 14/20, footnote = body-sm 12/16,
/// caption1 = label-sm 11/14, caption2 = caption 10/12.
/// Skala mengikuti pengaturan sistem lewat TextScaler (tidak di-clamp).
abstract final class AppTextStyles {
  static const fontDisplay = 'PlusJakartaSans';
  static const fontLabel = 'Inter';

  /// headline-xl. [emphasized] = ExtraBold (judul tab Circle/Profil).
  static TextStyle largeTitle(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) => _style(
    c,
    28,
    34,
    emphasized ? FontWeight.w800 : FontWeight.w700,
    color,
    spacing: -0.02,
  );

  static TextStyle title1(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) => _style(
    c,
    28,
    34,
    emphasized ? FontWeight.w800 : FontWeight.w700,
    color,
    spacing: -0.02,
  );

  /// headline-lg.
  static TextStyle title2(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) => _style(
    c,
    22,
    28,
    emphasized ? FontWeight.w800 : FontWeight.w700,
    color,
    spacing: -0.015,
  );

  /// headline-md.
  static TextStyle title3(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) => _style(
    c,
    18,
    24,
    emphasized ? FontWeight.w700 : FontWeight.w600,
    color,
    spacing: -0.01,
  );

  static TextStyle headline(BuildContext c, {Color? color}) =>
      _style(c, 18, 24, FontWeight.w600, color, spacing: -0.01);

  /// body-lg.
  static TextStyle body(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 16, 24, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  /// body-md.
  static TextStyle callout(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 14, 20, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle subhead(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 14, 20, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  /// body-sm.
  static TextStyle footnote(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 12, 16, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  /// label-sm (Inter 11/14, jarak huruf 0,04em).
  static TextStyle caption1(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) => _style(
    c,
    11,
    14,
    emphasized ? FontWeight.w600 : FontWeight.w500,
    color,
    family: fontLabel,
    spacing: 0.04,
  );

  /// caption (Inter 10/12).
  static TextStyle caption2(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) => _style(
    c,
    10,
    12,
    emphasized ? FontWeight.w700 : FontWeight.w500,
    color,
    family: fontLabel,
  );

  /// label-md (Inter 13/16 SemiBold, jarak huruf 0,02em).
  static TextStyle labelMd(BuildContext c, {Color? color}) => _style(
    c,
    13,
    16,
    FontWeight.w600,
    color,
    family: fontLabel,
    spacing: 0.02,
  );

  static TextStyle _style(
    BuildContext context,
    double size,
    double leading,
    FontWeight weight,
    Color? color, {
    String family = fontDisplay,
    double spacing = 0,
  }) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    return base.copyWith(
      fontFamily: family,
      fontSize: size,
      height: leading / size,
      fontWeight: weight,
      letterSpacing: spacing * size,
      color: CupertinoDynamicColor.resolve(
        color ?? AppColors.textPrimary,
        context,
      ),
    );
  }
}
