import 'package:flutter/cupertino.dart';

import '../member_colors.dart';

/// Avatar inisial berwarna (warna penanda anggota). Selalu ada inisial,
/// jadi warna bukan satu-satunya penanda.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.colorHex,
    this.size = 40,
    this.semanticLabel,
  });

  final String name;
  final String colorHex;
  final double size;
  final String? semanticLabel;

  /// Huruf pertama dari maksimal dua kata pertama, huruf besar.
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: semanticLabel != null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MemberColors.toColor(colorHex),
        ),
        child: Text(
          initials(name),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: MemberColors.onColor(colorHex),
          ),
        ),
      ),
    );
  }
}
