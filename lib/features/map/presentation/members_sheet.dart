import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/member_avatar.dart';
import '../domain/map_member.dart';
import '../domain/paused_until.dart';
import '../domain/presence.dart';
import '../domain/vehicle_type.dart';
import 'map_strings.dart';
import 'relative_time.dart';

/// Posisi panel anggota (fraksi tinggi): ringkas, sedang, penuh.
const double kSheetCompact = 0.16;
const double kSheetMedium = 0.45;
const double kSheetFull = 0.9;

/// Panel anggota nonmodal di atas peta (kaca obsidian di gelap, putih bersih
/// di terang). Peta di belakangnya tetap bisa digerakkan karena area di atas
/// panel tidak menangkap sentuhan.
class MembersSheet extends StatelessWidget {
  const MembersSheet({
    super.key,
    required this.controller,
    required this.circleName,
    required this.members,
    required this.selfId,
    required this.now,
    required this.busy,
    required this.onMemberTap,
    required this.onPause,
    required this.onResume,
  });

  final DraggableScrollableController controller;
  final String circleName;
  final List<MapMember> members;
  final String? selfId;
  final DateTime now;

  /// True selagi permintaan jeda/lanjutkan berjalan.
  final bool busy;
  final ValueChanged<MapMember> onMemberTap;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final self = members.where((m) => m.userId == selfId).firstOrNull;
    final selfPaused = self?.isPausedAt(now) ?? false;
    // Diri sendiri di atas, sisanya menurut nama.
    final sorted = [
      ...members.where((m) => m.userId == selfId),
      ...(members.where((m) => m.userId != selfId).toList()..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      )),
    ];
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: kSheetMedium,
      minChildSize: kSheetCompact,
      maxChildSize: kSheetFull,
      snap: true,
      snapSizes: const [kSheetCompact, kSheetMedium, kSheetFull],
      builder: (context, scrollController) {
        return Semantics(
          container: true,
          label: MapStrings.sheetLabel,
          child: _SheetSurface(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                const _Grabber(),
                _Header(
                  title: MapStrings.sheetTitle(circleName, members.length),
                  selfPaused: selfPaused,
                  canPause: self != null,
                  selfPause: self?.pause,
                  busy: busy,
                  onPause: onPause,
                  onResume: onResume,
                ),
                if (sorted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      MapStrings.noMembers,
                      style: AppTextStyles.body(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                for (final m in sorted)
                  MemberRow(
                    member: m,
                    isSelf: m.userId == selfId,
                    now: now,
                    onTap: () => onMemberTap(m),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Latar panel: kaca berkabut (blur) dengan sudut atas 28 dan tepi atas tipis.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(28));
    final dark = AppColors.isDark(context);
    final solid = MediaQuery.highContrastOf(context);
    final fill = AppColors.glassFill.resolveFrom(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? fill.withValues(alpha: solid ? 1 : 0.9)
            : AppColors.background.resolveFrom(context),
        borderRadius: radius,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder.resolveFrom(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(dark ? 0xB3000000 : 0x1A000000),
            blurRadius: dark ? 40 : 24,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: child,
    );
    if (!dark || solid) return surface;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: surface,
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.selfPaused,
    required this.canPause,
    required this.selfPause,
    required this.busy,
    required this.onPause,
    required this.onResume,
  });

  final String title;
  final bool selfPaused;
  final bool canPause;
  final PausedUntil? selfPause;
  final bool busy;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: AppTextStyles.title3(context)),
                ),
              ),
              if (canPause)
                busy
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: CupertinoActivityIndicator(),
                      )
                    : CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(44, 44),
                        onPressed: selfPaused ? onResume : onPause,
                        child: Text(
                          selfPaused ? MapStrings.resume : MapStrings.pause,
                          style: AppTextStyles.labelMd(
                            context,
                            color: AppColors.tint,
                          ),
                        ),
                      ),
            ],
          ),
          if (selfPaused) _SelfPausedNote(pause: selfPause),
        ],
      ),
    );
  }
}

class _SelfPausedNote extends StatelessWidget {
  const _SelfPausedNote({required this.pause});

  final PausedUntil? pause;

  @override
  Widget build(BuildContext context) {
    final until = pause?.until;
    final detail = pause == null || pause!.indefinite || until == null
        ? MapStrings.selfPausedIndefinite
        : MapStrings.selfPausedUntil(formatClock(until));
    final color = AppColors.warning.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Symbols.pause_circle, size: 18, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: MapStrings.selfPaused,
                      style: AppTextStyles.subhead(
                        context,
                        emphasized: true,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: '. $detail',
                      style: AppTextStyles.subhead(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris anggota: avatar, nama, status teks, waktu pembaruan, baterai, ikon
/// bergerak/diam. Status tidak hanya dengan warna: selalu ada teks.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.member,
    required this.isSelf,
    required this.now,
    required this.onTap,
  });

  final MapMember member;
  final bool isSelf;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presence = presenceOf(member, now);
    final loc = member.location;
    final ago = loc == null ? null : formatRelativeTime(loc.lastSeenAt, now);
    final showFix = hasMarker(presence);
    final status = MapStrings.statusText(
      presence,
      isMoving: loc?.isMoving,
      ago: ago,
    );
    final updated = presence == PresenceState.active ? ago : null;
    final battery = showFix ? loc?.batteryPct : null;
    final moving = presence == PresenceState.active ? loc?.isMoving : null;
    final vehicle = presence == PresenceState.active
        ? (loc?.vehicle ?? VehicleType.none)
        : VehicleType.none;
    final speedKmh = presence == PresenceState.active ? loc?.speedKmh : null;
    final dim = presence != PresenceState.active;
    final secondary = AppColors.textSecondary;

    return Semantics(
      button: showFix,
      hint: showFix ? MapStrings.centerOnMember : null,
      label: MapStrings.memberLabel(
        member.displayName,
        isSelf: isSelf,
        status: status,
        updated: updated == null ? null : MapStrings.updated(updated),
        batteryPct: battery,
      ),
      excludeSemantics: true,
      onTap: showFix ? onTap : null,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 56),
        alignment: Alignment.centerLeft,
        // Anggota tanpa marker tidak punya titik untuk dipusatkan.
        onPressed: showFix ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.groupedItemBackground
                .resolveFrom(context)
                .withValues(alpha: AppColors.isDark(context) ? 0.7 : 1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.isDark(context)
                  ? const Color(0x0DFFFFFF)
                  : AppColors.separator.resolveFrom(context),
            ),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: dim ? 0.55 : 1,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MemberAvatar(
                      name: member.displayName,
                      colorHex: member.colorHex,
                      size: 44,
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: presence == PresenceState.active
                              ? AppColors.success.resolveFrom(context)
                              : AppColors.textTertiary.resolveFrom(context),
                          border: Border.all(
                            color: AppColors.groupedItemBackground.resolveFrom(
                              context,
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelf
                          ? '${member.displayName} (${MapStrings.you})'
                          : member.displayName,
                      style: AppTextStyles.callout(context, emphasized: true),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          status,
                          style: AppTextStyles.footnote(
                            context,
                            color: presence == PresenceState.paused
                                ? AppColors.warning
                                : secondary,
                          ),
                        ),
                        if (vehicle != VehicleType.none &&
                            vehicle != VehicleType.walking)
                          _VehicleSheetBadge(
                            vehicle: vehicle,
                            speedKmh: speedKmh,
                          ),
                      ],
                    ),
                    if (updated != null)
                      Text(
                        MapStrings.updated(updated),
                        style: AppTextStyles.footnote(
                          context,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (battery != null || moving != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (battery != null)
                      Text(
                        '$battery%',
                        style: AppTextStyles.caption1(
                          context,
                          color: secondary,
                        ),
                      ),
                    if (moving != null)
                      Icon(
                        moving ? Symbols.near_me : Symbols.radio_button_checked,
                        size: 18,
                        color: AppColors.success.resolveFrom(context),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge kendaraan (mobil/motor) dan kecepatan km/jam di kartu anggota sheet.
class _VehicleSheetBadge extends StatelessWidget {
  const _VehicleSheetBadge({required this.vehicle, this.speedKmh});

  final VehicleType vehicle;
  final double? speedKmh;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (vehicle) {
      VehicleType.motorcycle => Symbols.two_wheeler,
      VehicleType.car => Symbols.directions_car,
      VehicleType.walking => Symbols.directions_walk,
      VehicleType.none => null,
    };
    if (iconData == null) return const SizedBox.shrink();

    final label = vehicle == VehicleType.motorcycle
        ? 'Motor'
        : (vehicle == VehicleType.car ? 'Mobil' : 'Jalan');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          AppColors.tint.withValues(alpha: 0.12),
          context,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 13,
            color: CupertinoDynamicColor.resolve(AppColors.tint, context),
          ),
          const SizedBox(width: 4),
          Text(
            speedKmh != null && speedKmh! >= 1.5
                ? '$label · ${speedKmh!.round()} km/jam'
                : label,
            style: AppTextStyles.caption2(
              context,
              emphasized: true,
              color: CupertinoDynamicColor.resolve(AppColors.tint, context),
            ),
          ),
        ],
      ),
    );
  }
}
