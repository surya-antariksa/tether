import 'package:flutter/cupertino.dart';

/// Gaya teks iOS (docs/08 bagian 4.2), ukuran/leading pada ukuran Large.
/// Skala mengikuti pengaturan sistem lewat TextScaler (tidak di-clamp).
/// Warna bawaan: label dinamis.
abstract final class AppTextStyles {
  static TextStyle largeTitle(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 34, 41, emphasized ? FontWeight.w700 : FontWeight.w400, color);

  static TextStyle title1(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 28, 34, emphasized ? FontWeight.w700 : FontWeight.w400, color);

  static TextStyle title2(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 22, 28, emphasized ? FontWeight.w700 : FontWeight.w400, color);

  static TextStyle title3(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 20, 25, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle headline(BuildContext c, {Color? color}) =>
      _style(c, 17, 22, FontWeight.w600, color);

  static TextStyle body(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 17, 22, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle callout(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 16, 21, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle subhead(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 15, 20, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle footnote(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 13, 18, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle caption1(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 12, 16, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle caption2(
    BuildContext c, {
    bool emphasized = false,
    Color? color,
  }) =>
      _style(c, 11, 13, emphasized ? FontWeight.w600 : FontWeight.w400, color);

  static TextStyle _style(
    BuildContext context,
    double size,
    double leading,
    FontWeight weight,
    Color? color,
  ) {
    final base = CupertinoTheme.of(context).textTheme.textStyle;
    return base.copyWith(
      fontSize: size,
      height: leading / size,
      fontWeight: weight,
      letterSpacing: 0,
      color: CupertinoDynamicColor.resolve(
        color ?? CupertinoColors.label,
        context,
      ),
    );
  }
}
