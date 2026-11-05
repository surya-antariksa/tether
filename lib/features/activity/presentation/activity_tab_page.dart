import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../auth/data/auth_providers.dart';
import '../../circle/data/circle_providers.dart';
import '../../circle/domain/circle.dart';
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

class _ActivityTabPageState extends ConsumerState<ActivityTabPage>
    with WidgetsBindingObserver {
  late final ActivityUnread _unread;
  bool _tickerEnabled = true;
  bool _appResumed = true;
  bool _visible = false;
  DateTime? _markedUpTo;

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

    Widget body;
    if (circles == null) {
      body = circlesAsync.hasError
          ? _Failed(onRetry: () => ref.invalidate(myCirclesProvider))
          : const Center(child: CupertinoActivityIndicator());
    } else if (circles.isEmpty) {
      body = const _Message(
        icon: CupertinoIcons.bell,
        title: ActivityStrings.noCircleTitle,
        body: ActivityStrings.noCircleBody,
      );
    } else {
      final current = _resolve(circles, selectedId);
      body = _CircleActivity(
        key: ValueKey(current.id),
        circle: current,
        circles: circles,
        onSelectCircle: (id) =>
            ref.read(selectedCircleIdProvider.notifier).select(id),
        onNewest: _markRead,
      );
    }
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(ActivityStrings.title),
      ),
      child: SafeArea(child: body),
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
}

class _CircleActivity extends ConsumerWidget {
  const _CircleActivity({
    super.key,
    required this.circle,
    required this.circles,
    required this.onSelectCircle,
    required this.onNewest,
  });

  final Circle circle;
  final List<Circle> circles;
  final ValueChanged<String> onSelectCircle;
  final ValueChanged<DateTime> onNewest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activityListProvider(circle.id));
    final state = async.value;
    final selfId = ref.watch(currentUserIdProvider);
    final now = ref.watch(activityClockProvider);

    if (state == null) {
      return async.hasError
          ? _Failed(
              onRetry: () => ref.invalidate(activityListProvider(circle.id)),
            )
          : const Center(child: CupertinoActivityIndicator());
    }
    if (state.events.isNotEmpty) onNewest(state.events.first.createdAt);

    final notifier = ref.read(activityListProvider(circle.id).notifier);
    final canSwitch = circles.length > 1;

    // Indeks 0: kepala; lalu event; terakhir: kaki (muat lagi / akhir).
    final eventCount = state.events.length;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: notifier.refresh),
        SliverToBoxAdapter(
          child: _Header(
            name: circle.name,
            canSwitch: canSwitch,
            offline: !state.realtimeConnected,
            onTap: canSwitch ? () => _pick(context) : null,
          ),
        ),
        if (eventCount == 0)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _Message(
              icon: CupertinoIcons.bell,
              title: ActivityStrings.emptyTitle,
              body: ActivityStrings.emptyBody,
            ),
          )
        else ...[
          SliverList.separated(
            itemCount: eventCount,
            separatorBuilder: (context, _) => Container(
              height: 0.5,
              margin: const EdgeInsets.only(left: 52),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            itemBuilder: (context, i) {
              final e = state.events[i];
              final isSelf = e.userId == selfId;
              final who = isSelf
                  ? ActivityStrings.you
                  : (e.displayName ??
                        state.names[e.userId] ??
                        ActivityStrings.someone);
              return ActivityTile(
                key: ValueKey(e.id),
                event: e,
                who: who,
                now: now,
                onShowOnMap: e.type == ActivityType.sos && e.hasCoordinates
                    ? () => _showOnMap(context, ref, e)
                    : null,
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
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final id = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(ActivityStrings.circlePickerTitle),
        actions: [
          for (final c in circles)
            CupertinoActionSheetAction(
              isDefaultAction: c.id == circle.id,
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
    if (id != null && id != circle.id) onSelectCircle(id);
  }

  void _showOnMap(BuildContext context, WidgetRef ref, ActivityEvent e) {
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
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final title = Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title3(context, emphasized: true),
          ),
        ),
        if (canSwitch) ...[
          const SizedBox(width: 4),
          ExcludeSemantics(
            child: Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: secondary,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: canSwitch,
              label: ActivityStrings.circleLabel(name, canSwitch: canSwitch),
              excludeSemantics: true,
              onTap: onTap,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(alignment: Alignment.centerLeft, child: title),
                ),
              ),
            ),
          ),
          if (offline)
            Semantics(
              label: ActivityStrings.realtimeOfflineLabel,
              excludeSemantics: true,
              child: Text(
                ActivityStrings.realtimeOffline,
                style: AppTextStyles.footnote(context, color: secondary),
              ),
            ),
        ],
      ),
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
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
                  color: CupertinoColors.secondaryLabel,
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
