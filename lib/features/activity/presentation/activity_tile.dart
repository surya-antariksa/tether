import 'package:flutter/cupertino.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../map/presentation/relative_time.dart';
import '../domain/activity_event.dart';
import 'activity_strings.dart';
import 'activity_tab_icon.dart';

IconData activityIcon(ActivityType type) => switch (type) {
  ActivityType.arrive => CupertinoIcons.map_pin_ellipse,
  ActivityType.leave => CupertinoIcons.arrow_right_circle,
  ActivityType.memberJoined => CupertinoIcons.person_add_solid,
  ActivityType.memberLeft => CupertinoIcons.person_badge_minus,
  ActivityType.memberRemoved => CupertinoIcons.person_crop_circle_badge_xmark,
  ActivityType.paused => CupertinoIcons.pause_circle,
  ActivityType.resumed => CupertinoIcons.play_circle,
  ActivityType.checkin => CupertinoIcons.checkmark_shield,
  ActivityType.sos => CupertinoIcons.exclamationmark_triangle_fill,
  ActivityType.sharingChanged => CupertinoIcons.arrow_2_circlepath_circle,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                activityIcon(event.type),
                size: 24,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                container: true,
                label: '$sentence, $_timeLabel',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sentence, style: AppTextStyles.body(context)),
                    Text(
                      _timeLabel,
                      style: AppTextStyles.footnote(
                        context,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: activityBadgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
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
                                CupertinoIcons.exclamationmark_triangle_fill,
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
                        const Icon(CupertinoIcons.map, size: 20),
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
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
