import 'package:flutter/cupertino.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/member_colors.dart';
import '../../../core/widgets/member_avatar.dart';
import '../domain/presence.dart';
import 'map_strings.dart';

/// Ukuran kotak marker; pusat kotak = titik koordinat.
const double kMarkerBox = 96;

/// Marker anggota: lingkaran berwarna dengan inisial, label nama, ikon
/// bergerak/diam. Diri sendiri: cincin ganda warna tint dan label "Kamu".
/// Basi: dipudarkan (teks "terakhir terlihat" ada di panel dan Semantics).
class MemberMarker extends StatelessWidget {
  const MemberMarker({
    super.key,
    required this.name,
    required this.colorHex,
    required this.presence,
    required this.isSelf,
    required this.isMoving,
    required this.semanticLabel,
    required this.onTap,
  });

  final String name;
  final String colorHex;
  final PresenceState presence;
  final bool isSelf;
  final bool? isMoving;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stale = presence == PresenceState.stale;
    const avatar = 36.0;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: stale ? 0.5 : 1,
        child: SizedBox(
          width: kMarkerBox,
          height: kMarkerBox,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Area sentuh 44x44 pt walau gambar lebih kecil.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSelf ? 2 : 0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CupertinoColors.white,
                            border: Border.all(
                              color: isSelf
                                  ? AppColors.tint.resolveFrom(context)
                                  : CupertinoColors.white,
                              width: isSelf ? 3 : 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: MemberAvatar(
                            name: name,
                            colorHex: colorHex,
                            size: avatar,
                          ),
                        ),
                        if (isMoving != null)
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: _MotionBadge(moving: isMoving!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: kMarkerBox / 2 + 24,
                child: _NameLabel(
                  text: isSelf ? MapStrings.you : name,
                  colorHex: colorHex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotionBadge extends StatelessWidget {
  const _MotionBadge({required this.moving});

  final bool moving;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: CupertinoColors.white,
      ),
      child: Icon(
        moving
            ? CupertinoIcons.arrow_up_right_circle_fill
            : CupertinoIcons.stop_circle,
        size: 18,
        color: const Color(0xFF3A3A3C),
      ),
    );
  }
}

class _NameLabel extends StatelessWidget {
  const _NameLabel({required this.text, required this.colorHex});

  final String text;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: kMarkerBox),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: MemberColors.toColor(colorHex),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Label di peta tidak ikut skala teks sistem: ruang terbatas, dan nama
        // lengkap ada di panel anggota.
        textScaler: TextScaler.noScaling,
        style: AppTextStyles.caption1(
          context,
          emphasized: true,
          color: MemberColors.onColor(colorHex),
        ),
      ),
    );
  }
}
