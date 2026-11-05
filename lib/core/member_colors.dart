import 'dart:ui';

import 'contrast.dart';

/// Palet penanda anggota (profiles.color), disimpan sebagai '#RRGGBB'.
/// Urutan tetap: teal, biru, oranye, pink, ungu, hijau, amber, slate.
abstract final class MemberColors {
  static const List<String> hexes = [
    '#0F766E',
    '#2563EB',
    '#EA580C',
    '#DB2777',
    '#7C3AED',
    '#15803D',
    '#B45309',
    '#475569',
  ];

  static const String defaultHex = '#0F766E';

  static final RegExp _pattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static bool isValid(String hex) => _pattern.hasMatch(hex);

  /// Hex tidak valid jatuh ke warna bawaan.
  static Color toColor(String hex) {
    final value = int.parse(
      (isValid(hex) ? hex : defaultHex).substring(1),
      radix: 16,
    );
    return Color(0xFF000000 | value);
  }

  /// Warna teks (putih atau hitam) dengan kontras terbaik di atas [hex].
  static Color onColor(String hex) {
    final bg = toColor(hex);
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    return contrastRatio(white, bg) >= contrastRatio(black, bg) ? white : black;
  }
}
