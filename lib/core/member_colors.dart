import 'dart:ui';

import 'contrast.dart';

/// Opsi warna penanda visual berlabel untuk pemilih warna di profil.
class MarkerColorChip {
  const MarkerColorChip({required this.hex, required this.name});
  final String hex;
  final String name;
}

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

  /// Palet neon / cyan obsidian modern untuk UI pemilih warna HUD.
  static const List<MarkerColorChip> palette = [
    MarkerColorChip(hex: '#00F2FE', name: 'Teal Cyan'),
    MarkerColorChip(hex: '#4CD7F6', name: 'Electric Blue'),
    MarkerColorChip(hex: '#4EDEA3', name: 'Neon Green'),
    MarkerColorChip(hex: '#FF8D5C', name: 'Neon Orange'),
    MarkerColorChip(hex: '#F43F5E', name: 'Vivid Magenta'),
    MarkerColorChip(hex: '#A855F7', name: 'Violet Purple'),
    MarkerColorChip(hex: '#FBBF24', name: 'Amber Gold'),
    MarkerColorChip(hex: '#64748B', name: 'Slate Blue'),
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
