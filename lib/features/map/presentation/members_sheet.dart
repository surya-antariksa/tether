import 'package:flutter/cupertino.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/member_avatar.dart';
import '../domain/map_member.dart';
import '../domain/paused_until.dart';
import '../domain/presence.dart';
import 'map_strings.dart';
import 'relative_time.dart';

/// Posisi panel anggota (fraksi tinggi): ringkas, sedang, penuh.
const double kSheetCompact = 0.16;
const double kSheetMedium = 0.45;
const double kSheetFull = 0.9;

/// Panel anggota nonmodal di atas peta (lapisan konten: latar opak, bukan
/// Liquid Glass). Peta di belakangnya tetap bisa digerakkan karena area di
/// atas panel tidak menangkap sentuhan.
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
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

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            borderRadius: BorderRadius.circular(3),
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
                  child: Text(title, style: AppTextStyles.headline(context)),
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
              child: Icon(
                CupertinoIcons.pause_circle_fill,
                size: 18,
                color: color,
              ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Opacity(
                opacity: dim ? 0.55 : 1,
                child: MemberAvatar(
                  name: member.displayName,
                  colorHex: member.colorHex,
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
                      style: AppTextStyles.body(context, emphasized: true),
                    ),
                    Text(
                      status,
                      style: AppTextStyles.subhead(
                        context,
                        color: presence == PresenceState.paused
                            ? AppColors.warning
                            : secondary,
                      ),
                    ),
                    if (updated != null)
                      Text(
                        MapStrings.updated(updated),
                        style: AppTextStyles.footnote(
                          context,
                          color: secondary,
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
                        style: AppTextStyles.subhead(context, color: secondary),
                      ),
                    if (moving != null)
                      Icon(
                        moving
                            ? CupertinoIcons.arrow_up_right_circle_fill
                            : CupertinoIcons.stop_circle,
                        size: 20,
                        color: secondary.resolveFrom(context),
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
