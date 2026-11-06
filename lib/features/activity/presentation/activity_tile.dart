import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../map/presentation/relative_time.dart';
import '../domain/activity_event.dart';
import 'activity_strings.dart';
import 'activity_tab_icon.dart';

IconData activityIcon(ActivityType type) => switch (type) {
  ActivityType.arrive => Symbols.pin_drop,
  ActivityType.leave => Symbols.arrow_circle_right,
  ActivityType.memberJoined => Symbols.person_add,
  ActivityType.memberLeft => Symbols.person_remove,
  ActivityType.memberRemoved => Symbols.person_remove,
  ActivityType.paused => Symbols.pause_circle,
  ActivityType.resumed => Symbols.play_circle,
  ActivityType.checkin => Symbols.verified_user,
  ActivityType.sos => Symbols.warning,
  ActivityType.sharingChanged => Symbols.sync,
};

/// Warna aksen ikon per jenis: hijau = aman/tiba, kuning = jeda/pergi,
/// tint = anggota/pengaturan, merah = keluar/dikeluarkan/SOS.
CupertinoDynamicColor activityAccent(ActivityType type) => switch (type) {
  ActivityType.arrive ||
  ActivityType.checkin ||
  ActivityType.resumed => AppColors.success,
  ActivityType.leave || ActivityType.paused => AppColors.warning,
  ActivityType.memberJoined || ActivityType.sharingChanged => AppColors.tint,
  ActivityType.memberLeft ||
  ActivityType.memberRemoved ||
  ActivityType.sos => AppColors.danger,
};

/// Satu baris aktivitas. SOS tampil menonjol dengan tombol ke peta.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.event,
    required this.who,
    required this.now,
    this.onShowOnMap,
  });

  final ActivityEvent event;

  /// Nama pelaku atau "Anda".
  final String who;
  final DateTime now;

  /// Hanya dipakai kartu SOS yang punya koordinat.
  final VoidCallback? onShowOnMap;

  String get _timeLabel {
    final relative = formatRelativeTime(event.shownAt, now);
    return event.type == ActivityType.sos
        ? '${formatClock(event.shownAt)} · $relative'
        : relative;
  }

  @override
  Widget build(BuildContext context) {
    return event.type == ActivityType.sos
        ? _buildSos(context)
        : _buildPlain(context);
  }

  Widget _buildPlain(BuildContext context) {
    final sentence = ActivityStrings.sentence(event, who);
    final accent = activityAccent(event.type);
    final isSelf = who == ActivityStrings.you;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        accentLeft: isSelf ? AppColors.success.resolveFrom(context) : null,
        glow: accent.resolveFrom(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: activityIcon(event.type), color: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Semantics(
                container: true,
                label: '$sentence, $_timeLabel',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          sentence,
                          style: AppTextStyles.labelMd(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _timeLabel,
                        style: AppTextStyles.caption2(
                          context,
                          color: AppColors.textTertiary,
                        ),
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

  Widget _buildSos(BuildContext context) {
    final sentence = ActivityStrings.sentence(event, who);
    final hasMap = event.hasCoordinates && onShowOnMap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: activityBadgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activityBadgeColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                label: '${ActivityStrings.sosBadge}. $sentence, $_timeLabel',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: activityBadgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Symbols.warning,
                                size: 14,
                                color: CupertinoColors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ActivityStrings.sosBadge,
                                style: AppTextStyles.footnote(
                                  context,
                                  emphasized: true,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _timeLabel,
                            style: AppTextStyles.subhead(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(sentence, style: AppTextStyles.headline(context)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (hasMap)
                Semantics(
                  button: true,
                  label: ActivityStrings.showOnMapLabel(who),
                  excludeSemantics: true,
                  onTap: onShowOnMap,
                  child: CupertinoButton(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: onShowOnMap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.map, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          ActivityStrings.showOnMap,
                          style: AppTextStyles.body(
                            context,
                            emphasized: true,
                            color: AppColors.tint.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  ActivityStrings.sosNoLocation,
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
