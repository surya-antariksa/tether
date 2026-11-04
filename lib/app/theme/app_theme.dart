import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// Tema Cupertino. Brightness sengaja tidak diisi: mengikuti sistem
/// (terang, gelap, kontras tinggi). Tidak ada saklar tema di dalam aplikasi.
const CupertinoThemeData appTheme = CupertinoThemeData(
  primaryColor: AppColors.tint,
  primaryContrastingColor: AppColors.onTint,
  scaffoldBackgroundColor: AppColors.background,
);
