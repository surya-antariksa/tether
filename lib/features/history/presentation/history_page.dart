import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../map/data/map_providers.dart';
import '../data/history_providers.dart';
import '../domain/history_point.dart';
import '../domain/history_repository.dart';
import 'history_map.dart';
import 'history_strings.dart';

/// Riwayat lokasi sendiri 48 jam terakhir + tombol hapus riwayat (F11).
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(HistoryStrings.deleteTitle),
        content: const Text(HistoryStrings.deleteMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(HistoryStrings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(HistoryStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final n = await ref.read(historyRepositoryProvider).deleteAll();
      ref.invalidate(locationHistoryProvider);
      if (!mounted) return;
      setState(() => _deleting = false);
      await _alert(
        HistoryStrings.deletedTitle,
        HistoryStrings.deletedMessage(n),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final kind = e is HistoryFailure ? e.kind : HistoryFailureKind.unknown;
      await _alert(HistoryStrings.errorTitle, HistoryStrings.failure(kind));
    }
  }

  Future<void> _alert(String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(HistoryStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(locationHistoryProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(HistoryStrings.title),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: history.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (_, _) => _Message(
                text: HistoryStrings.loadFailed,
                action: CupertinoButton(
                  minimumSize: const Size(44, 44),
                  onPressed: () => ref.invalidate(locationHistoryProvider),
                  child: const Text(HistoryStrings.retry),
                ),
              ),
              data: (points) => points.isEmpty
                  ? const _Message(
                      title: HistoryStrings.emptyTitle,
                      text: HistoryStrings.emptyBody,
                      footer: HistoryStrings.privacy,
                    )
                  : _HistoryContent(
                      points: points,
                      deleting: _deleting,
                      onDelete: _confirmDelete,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({this.title, required this.text, this.action, this.footer});

  final String? title;
  final String text;
  final Widget? action;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTextStyles.title3(context, emphasized: true),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              context,
              color: title == null ? null : AppColors.textSecondary,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
          if (footer != null) ...[
            const SizedBox(height: 32),
            Text(
              footer!,
              textAlign: TextAlign.center,
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Item daftar: judul hari atau satu titik.
sealed class _Item {}

class _DayHeader extends _Item {
  _DayHeader(this.label);
  final String label;
}

class _PointRow extends _Item {
  _PointRow(this.point);
  final HistoryPoint point;
}

List<_Item> _group(List<HistoryPoint> points, DateTime now) {
  final items = <_Item>[];
  DateTime? day;
  for (final p in points) {
    final d = DateTime(p.recordedAt.year, p.recordedAt.month, p.recordedAt.day);
    if (day != d) {
      day = d;
      items.add(_DayHeader(_dayLabel(d, now)));
    }
    items.add(_PointRow(p));
  }
  return items;
}

String _dayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return HistoryStrings.today;
  if (diff == 1) return HistoryStrings.yesterday;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}/${two(day.month)}/${day.year}';
}

String _clock(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}.${two(t.minute)}';
}

class _HistoryContent extends ConsumerWidget {
  const _HistoryContent({
    required this.points,
    required this.deleting,
    required this.onDelete,
  });

  final List<HistoryPoint> points;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _group(points, ref.watch(historyClockProvider)());
    final truncated = points.length >= maxHistoryPoints;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
            children: [
              HistoryMap(
                points: points,
                tileProvider: ref.watch(mapTileProviderProvider),
              ),
              const SizedBox(height: 8),
              const _Legend(),
              const SizedBox(height: 4),
              Text(
                HistoryStrings.count(points.length),
                style: AppTextStyles.subhead(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              if (truncated)
                Text(
                  HistoryStrings.truncated(points.length),
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 16),
              _DeleteButton(busy: deleting, onPressed: onDelete),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  HistoryStrings.privacy,
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => switch (items[i]) {
              _DayHeader(:final label) => _DayHeaderView(label),
              _PointRow(:final point) => _PointRowView(point: point),
            },
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.footnote(
            context,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        item(
          CupertinoDynamicColor.resolve(AppColors.textSecondary, context),
          HistoryStrings.mapStart,
        ),
        item(
          CupertinoDynamicColor.resolve(AppColors.tint, context),
          HistoryStrings.mapEnd,
        ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: busy ? HistoryStrings.deleting : HistoryStrings.delete,
      excludeSemantics: true,
      onTap: busy ? null : onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
            AppColors.groupedItemBackground,
            context,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size.fromHeight(44),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const CupertinoActivityIndicator()
              : Text(
                  HistoryStrings.delete,
                  style: AppTextStyles.body(context, color: AppColors.danger),
                ),
        ),
      ),
    );
  }
}

class _DayHeaderView extends StatelessWidget {
  const _DayHeaderView(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.footnote(
            context,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PointRowView extends StatelessWidget {
  const _PointRowView({required this.point});

  final HistoryPoint point;

  @override
  Widget build(BuildContext context) {
    final time = _clock(point.recordedAt);
    final state = point.isMoving ? HistoryStrings.moving : HistoryStrings.still;
    final acc = point.accuracyM == null
        ? null
        : HistoryStrings.accuracy(point.accuracyM!.round());
    return Semantics(
      label: HistoryStrings.rowLabel(time, state.toLowerCase(), acc),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(time, style: AppTextStyles.body(context)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  acc == null ? state : '$state, $acc',
                  style: AppTextStyles.body(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
