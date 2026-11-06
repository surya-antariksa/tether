import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../map/presentation/relative_time.dart';
import '../../auth/data/auth_providers.dart';
import '../../circle/data/circle_providers.dart';
import '../../circle/domain/circle.dart';
import '../../safety/presentation/safety_sheet.dart';
import '../data/activity_providers.dart';
import '../domain/activity_event.dart';
import 'activity_strings.dart';
import 'activity_tile.dart';

/// Tab Aktivitas (T4.6): daftar event Circle terpilih, terbaru dulu.
class ActivityTabPage extends ConsumerStatefulWidget {
  const ActivityTabPage({super.key});

  @override
  ConsumerState<ActivityTabPage> createState() => _ActivityTabPageState();
}

/// Kategori filter feed (hanya menyaring tampilan, bukan data).
enum _Filter { all, safety, places, circle }

bool _inFilter(_Filter f, ActivityType t) => switch (f) {
  _Filter.all => true,
  _Filter.safety => t == ActivityType.checkin || t == ActivityType.sos,
  _Filter.places => t == ActivityType.arrive || t == ActivityType.leave,
  _Filter.circle =>
    t != ActivityType.checkin &&
        t != ActivityType.sos &&
        t != ActivityType.arrive &&
        t != ActivityType.leave,
};

class _ActivityTabPageState extends ConsumerState<ActivityTabPage>
    with WidgetsBindingObserver {
  late final ActivityUnread _unread;
  bool _tickerEnabled = true;
  bool _appResumed = true;
  bool _visible = false;
  DateTime? _markedUpTo;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _unread = ref.read(activityUnreadProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cabang tab yang tidak aktif tetap hidup (indexedStack) tetapi tickernya
    // mati: dipakai sebagai tanda tab terlihat.
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled != _tickerEnabled) {
      _tickerEnabled = enabled;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unread.setTabVisible(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncVisibility();
  }

  void _syncVisibility() {
    if (!mounted) return;
    final visible = _tickerEnabled && _appResumed;
    if (visible == _visible) return;
    _visible = visible;
    _unread.setTabVisible(visible);
    if (visible) {
      _markedUpTo = null;
      _unread.markAllRead();
      final id = ref.read(selectedCircleIdProvider);
      if (id != null) ref.read(activityListProvider(id).notifier).refresh();
    }
  }

  /// Tandai terbaca sampai event terbaru yang tampil.
  void _markRead(DateTime newest) {
    if (!_visible) return;
    if (_markedUpTo != null && !newest.isAfter(_markedUpTo!)) return;
    _markedUpTo = newest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unread.markAllRead(newestSeen: newest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final circlesAsync = ref.watch(myCirclesProvider);
    final selectedId = ref.watch(selectedCircleIdProvider);
    final circles = circlesAsync.value;
    final selfId = ref.watch(currentUserIdProvider);
    final now = ref.watch(activityClockProvider);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      child: AtmosphereBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (circles == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: circlesAsync.hasError
                      ? _Failed(
                          onRetry: () => ref.invalidate(myCirclesProvider),
                        )
                      : const Center(child: CupertinoActivityIndicator()),
                )
              else if (circles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Message(
                    icon: Symbols.notifications,
                    title: ActivityStrings.noCircleTitle,
                    body: ActivityStrings.noCircleBody,
                  ),
                )
              else
                ..._buildCircleSlivers(
                  context,
                  circles,
                  selectedId,
                  selfId,
                  now,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Circle yang ditampilkan: pilihan bila ada di daftar, kalau tidak yang
  /// pertama (dan dipilih).
  Circle _resolve(List<Circle> circles, String? selectedId) {
    final match = circles.where((c) => c.id == selectedId).firstOrNull;
    if (match != null) return match;
    Future.microtask(() {
      if (mounted) {
        ref.read(selectedCircleIdProvider.notifier).select(circles.first.id);
      }
    });
    return circles.first;
  }

  List<Widget> _buildCircleSlivers(
    BuildContext context,
    List<Circle> circles,
    String? selectedId,
    String? selfId,
    DateTime now,
  ) {
    final current = _resolve(circles, selectedId);
    final async = ref.watch(activityListProvider(current.id));
    final state = async.value;

    if (state == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: async.hasError
              ? _Failed(
                  onRetry: () =>
                      ref.invalidate(activityListProvider(current.id)),
                )
              : const Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }

    if (state.events.isNotEmpty) _markRead(state.events.first.createdAt);

    final notifier = ref.read(activityListProvider(current.id).notifier);
    final canSwitch = circles.length > 1;
    final eventCount = state.events.length;
    final visible = [
      for (final e in state.events)
        if (_inFilter(_filter, e.type)) e,
    ];

    return [
      CupertinoSliverRefreshControl(onRefresh: notifier.refresh),
      SliverToBoxAdapter(
        child: _Header(
          name: current.name,
          canSwitch: canSwitch,
          offline: !state.realtimeConnected,
          onTap: canSwitch ? () => _pick(context, current, circles) : null,
        ),
      ),
      SliverToBoxAdapter(
        child: _StatusCard(
          lastCheckin: state.events
              .where(
                (e) => e.type == ActivityType.checkin && e.userId == selfId,
              )
              .map((e) => e.shownAt)
              .firstOrNull,
          now: now,
          onCheckin: () => showSafetySheet(context, circleId: current.id),
        ),
      ),
      SliverToBoxAdapter(
        child: _Filters(
          selected: _filter,
          onSelect: (f) => setState(() => _filter = f),
        ),
      ),
      if (eventCount == 0)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            icon: Symbols.notifications,
            title: ActivityStrings.emptyTitle,
            body: ActivityStrings.emptyBody,
          ),
        )
      else if (visible.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(32), child: _FilterEmpty()),
        )
      else ...[
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final e = visible[i];
            final isSelf = e.userId == selfId;
            final who = isSelf
                ? ActivityStrings.you
                : (e.displayName ??
                      state.names[e.userId] ??
                      ActivityStrings.someone);
            final day = e.shownAt.toLocal();
            final newDay =
                i == 0 || !_sameDay(day, visible[i - 1].shownAt.toLocal());
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (newDay)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: SectionLabel(ActivityStrings.dayLabel(day, now)),
                    ),
                  ActivityTile(
                    key: ValueKey(e.id),
                    event: e,
                    who: who,
                    now: now,
                    onShowOnMap: e.type == ActivityType.sos && e.hasCoordinates
                        ? () => _showOnMap(context, e)
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: _Footer(
            hasMore: state.hasMore,
            loading: state.loadingMore,
            failed: state.loadMoreFailed,
            onLoadMore: notifier.loadMore,
          ),
        ),
      ],
      // Ruang untuk tab bar melayang.
      const SliverToBoxAdapter(child: SizedBox(height: 88)),
    ];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pick(
    BuildContext context,
    Circle current,
    List<Circle> circles,
  ) async {
    final id = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(ActivityStrings.circlePickerTitle),
        actions: [
          for (final c in circles)
            CupertinoActionSheetAction(
              isDefaultAction: c.id == current.id,
              onPressed: () => Navigator.of(ctx).pop(c.id),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(ActivityStrings.circlePickerCancel),
        ),
      ),
    );
    if (id != null && id != current.id) {
      ref.read(selectedCircleIdProvider.notifier).select(id);
    }
  }

  void _showOnMap(BuildContext context, ActivityEvent e) {
    ref.read(selectedCircleIdProvider.notifier).select(e.circleId);
    ref
        .read(activityMapFocusProvider.notifier)
        .focus(
          ActivityMapFocus(circleId: e.circleId, lat: e.lat!, lng: e.lng!),
        );
    context.go(AppRoutes.map);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.canSwitch,
    required this.offline,
    required this.onTap,
  });

  final String name;
  final bool canSwitch;
  final bool offline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      ActivityStrings.title,
                      style: AppTextStyles.largeTitle(context),
                    ),
                  ),
                  offline
                      ? Semantics(
                          label: ActivityStrings.realtimeOfflineLabel,
                          excludeSemantics: true,
                          child: const StatusBadge(
                            text: ActivityStrings.realtimeOffline,
                            dotColor: AppColors.warning,
                          ),
                        )
                      : const StatusBadge(text: ActivityStrings.realtimeBadge),
                ],
              ),
              CirclePill(
                name: name,
                canSwitch: canSwitch,
                onTap: onTap,
                semanticLabel: ActivityStrings.circleLabel(
                  name,
                  canSwitch: canSwitch,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ActivityStrings.subtitle,
            style: AppTextStyles.footnote(context, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Kartu "Status Anda": waktu kabar terakhir dan tombol Kabar Aman.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.lastCheckin,
    required this.now,
    required this.onCheckin,
  });

  final DateTime? lastCheckin;
  final DateTime now;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final detail = lastCheckin == null
        ? ActivityStrings.statusNone
        : ActivityStrings.statusUpdated(formatRelativeTime(lastCheckin!, now));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        glow: AppColors.success.resolveFrom(context),
        child: _statusBody(context, detail),
      ),
    );
  }

  Widget _statusBody(BuildContext context, String detail) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 16 * 1.5;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ActivityStrings.statusTitle,
          style: AppTextStyles.labelMd(context),
        ),
        Text(
          detail,
          style: AppTextStyles.footnote(
            context,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    final button = TintPillButton(
      label: ActivityStrings.checkinButton,
      icon: Symbols.check_circle,
      onPressed: onCheckin,
    );
    const icon = IconTile(
      icon: Symbols.verified_user,
      color: AppColors.success,
      size: 40,
      iconSize: 22,
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(child: texts),
            ],
          ),
          const SizedBox(height: 12),
          button,
        ],
      );
    }
    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(child: texts),
        const SizedBox(width: 8),
        button,
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final _Filter selected;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_Filter.all, ActivityStrings.filterAll, Symbols.all_inclusive),
      (_Filter.safety, ActivityStrings.filterSafety, Symbols.shield),
      (_Filter.places, ActivityStrings.filterPlaces, Symbols.pin_drop),
      (_Filter.circle, ActivityStrings.filterCircle, Symbols.group),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          for (final (f, label, icon) in items) ...[
            FilterPill(
              label: label,
              icon: icon,
              selected: f == selected,
              onTap: () => onSelect(f),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty();

  @override
  Widget build(BuildContext context) {
    return Text(
      ActivityStrings.filterEmpty,
      textAlign: TextAlign.center,
      style: AppTextStyles.callout(context, color: AppColors.textSecondary),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool loading;
  final bool failed;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          ActivityStrings.end,
          textAlign: TextAlign.center,
          style: AppTextStyles.footnote(
            context,
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      );
    }
    return Center(
      child: CupertinoButton(
        minimumSize: const Size(44, 44),
        onPressed: onLoadMore,
        child: Text(
          failed ? ActivityStrings.loadMoreFailed : ActivityStrings.loadMore,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 48,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title2(context, emphasized: true),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ActivityStrings.loadFailed,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              minimumSize: const Size(44, 44),
              onPressed: onRetry,
              child: const Text(ActivityStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
