import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

const _base = TextStyle(
  fontFamily: AppTextStyles.fontDisplay,
  fontSize: 16,
  height: 24 / 16,
  color: AppColors.textPrimary,
  decoration: TextDecoration.none,
);

/// Tema Cupertino. Brightness sengaja tidak diisi: mengikuti sistem
/// (terang, gelap, kontras tinggi). Tidak ada saklar tema di dalam aplikasi.
/// Font bawaan semua widget Cupertino = Plus Jakarta Sans.
const CupertinoThemeData appTheme = CupertinoThemeData(
  primaryColor: AppColors.tint,
  primaryContrastingColor: AppColors.onTint,
  scaffoldBackgroundColor: AppColors.background,
  barBackgroundColor: AppColors.glassFill,
  textTheme: CupertinoTextThemeData(
    primaryColor: AppColors.tint,
    textStyle: _base,
    actionTextStyle: TextStyle(
      fontFamily: AppTextStyles.fontDisplay,
      fontSize: 16,
      color: AppColors.tint,
      decoration: TextDecoration.none,
    ),
    tabLabelTextStyle: TextStyle(
      fontFamily: AppTextStyles.fontLabel,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      decoration: TextDecoration.none,
    ),
    navTitleTextStyle: TextStyle(
      fontFamily: AppTextStyles.fontDisplay,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      decoration: TextDecoration.none,
    ),
    navLargeTitleTextStyle: TextStyle(
      fontFamily: AppTextStyles.fontDisplay,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      decoration: TextDecoration.none,
    ),
    navActionTextStyle: TextStyle(
      fontFamily: AppTextStyles.fontDisplay,
      fontSize: 16,
      color: AppColors.tint,
      decoration: TextDecoration.none,
    ),
  ),
);
