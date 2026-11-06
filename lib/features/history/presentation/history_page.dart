import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../map/data/map_providers.dart';
import '../../map/presentation/share_route_sheet.dart';
import '../data/history_providers.dart';
import '../domain/history_point.dart';
import '../domain/history_repository.dart';
import 'history_map.dart';
import '../../profile/profile_routes.dart';
import '../domain/route_stats.dart';
import 'history_strings.dart';
import 'route_strings.dart';

/// Riwayat lokasi sendiri 30 hari terakhir + tombol hapus riwayat (F11).
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
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .resolveFrom(context)
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger
                        .resolveFrom(context)
                        .withValues(alpha: 0.40),
                  ),
                ),
                child: Icon(
                  Symbols.delete,
                  size: 22,
                  color: AppColors.danger.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                HistoryStrings.deleteMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textPrimary.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .resolveFrom(context)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.danger
                        .resolveFrom(context)
                        .withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Symbols.shield,
                      size: 14,
                      color: AppColors.danger.resolveFrom(context),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Data penanda terakhir pada Circle tetap aktif kecuali Anda mengaktifkan Jeda Berbagi Lokasi.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: AppColors.danger.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text(HistoryStrings.title),
        trailing: history.maybeWhen(
          data: (points) => points.isNotEmpty
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showShareRouteSheet(context),
                  child: Semantics(
                    label: 'Bagikan rute',
                    child: const Icon(Symbols.share, size: 20),
                  ),
                )
              : null,
          orElse: () => null,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.tint
                  .resolveFrom(context)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.tint
                    .resolveFrom(context)
                    .withValues(alpha: 0.20),
              ),
            ),
            child: Icon(
              Symbols.pin_drop,
              color: AppColors.tint.resolveFrom(context),
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.textPrimary.resolveFrom(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: AppColors.textSecondary.resolveFrom(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
          if (footer != null) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.groupedItemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.separator
                      .resolveFrom(context)
                      .withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Symbols.shield,
                      size: 16,
                      color: AppColors.tint.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      footer!,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.textSecondary.resolveFrom(context),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
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
              // Interactive Map Card Container
              Container(
                decoration: BoxDecoration(
                  color: AppColors.groupedItemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.separator
                        .resolveFrom(context)
                        .withValues(alpha: 0.20),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryMap(
                      points: points,
                      tileProvider: ref.watch(mapTileProviderProvider),
                    ),
                    _Legend(count: points.length),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Counter Headline & Quick Stat
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    HistoryStrings.count(points.length),
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppColors.textPrimary.resolveFrom(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.sync,
                        size: 13,
                        color: AppColors.success.resolveFrom(context),
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Diperbarui otomatis',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textTertiary.resolveFrom(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (truncated) ...[
                const SizedBox(height: 4),
                Text(
                  HistoryStrings.truncated(points.length),
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _RouteActions(points: points),
              const SizedBox(height: 12),
              _DeleteButton(busy: deleting, onPressed: onDelete),
              const SizedBox(height: 10),
              // Privacy Notice Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.groupedItemBackground
                      .resolveFrom(context)
                      .withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.separator
                        .resolveFrom(context)
                        .withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.resolveFrom(context),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Symbols.shield,
                        size: 15,
                        color: AppColors.tint.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        HistoryStrings.privacy,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: AppColors.textSecondary.resolveFrom(context),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => switch (items[i]) {
              _DayHeader(:final label) => _DayHeaderView(label),
              _PointRow(:final point) => _PointRowView(
                point: point,
                isNewest: point == points.first,
                onTap: () {
                  final i = points.indexOf(point);
                  // points terbaru dulu: titik sebelumnya = indeks berikutnya.
                  final prev = i >= 0 && i + 1 < points.length
                      ? points[i + 1]
                      : null;
                  context.push(
                    ProfileRoutes.pointDetailPath,
                    extra: PointDetailArgs(point, prev),
                  );
                },
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.groupedItemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.70),
        border: Border(
          top: BorderSide(
            color: AppColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.10),
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.separator.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    HistoryStrings.mapStart,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary.resolveFrom(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tint.resolveFrom(context),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tint
                              .resolveFrom(context)
                              .withValues(alpha: 0.70),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    HistoryStrings.mapEnd,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textPrimary.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.tint
                  .resolveFrom(context)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.tint
                    .resolveFrom(context)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '$count titik • 30 hari',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.tint.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
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
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: AppColors.danger.resolveFrom(context).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.danger
                .resolveFrom(context)
                .withValues(alpha: 0.30),
          ),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size.fromHeight(44),
          onPressed: busy ? null : onPressed,
          child: busy
              ? CupertinoActivityIndicator(
                  color: AppColors.danger.resolveFrom(context),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.delete,
                      size: 18,
                      color: AppColors.danger.resolveFrom(context),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        HistoryStrings.delete,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: AppColors.danger.resolveFrom(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.2,
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

class _DayHeaderView extends StatelessWidget {
  const _DayHeaderView(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Semantics(
        header: true,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary.resolveFrom(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '±12m - ±21m presisi',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textTertiary.resolveFrom(context),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointRowView extends StatelessWidget {
  const _PointRowView({required this.point, this.isNewest = false, this.onTap});

  final HistoryPoint point;
  final bool isNewest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = _clock(point.recordedAt);
    final state = point.isMoving ? HistoryStrings.moving : HistoryStrings.still;
    final acc = point.accuracyM == null
        ? null
        : HistoryStrings.accuracy(point.accuracyM!.round());
    return Semantics(
      button: onTap != null,
      label: HistoryStrings.rowLabel(time, state.toLowerCase(), acc),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.groupedItemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNewest
                      ? AppColors.tint.resolveFrom(context)
                      : AppColors.textTertiary.resolveFrom(context),
                  boxShadow: isNewest
                      ? [
                          BoxShadow(
                            color: AppColors.tint
                                .resolveFrom(context)
                                .withValues(alpha: 0.70),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: AppColors.textPrimary.resolveFrom(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (isNewest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tint
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.tint
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              'Terbaru',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.tint.resolveFrom(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      acc == null ? state : '$state, $acc',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.textSecondary.resolveFrom(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    point.isMoving ? Symbols.explore : Symbols.check_circle,
                    size: 14,
                    color: point.isMoving
                        ? AppColors.tint.resolveFrom(context)
                        : AppColors.success.resolveFrom(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    point.isMoving ? 'Bergerak' : 'Stabil',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: point.isMoving
                          ? AppColors.tint.resolveFrom(context)
                          : AppColors.success.resolveFrom(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aksi di bawah peta riwayat: putar rute dan bandingkan dua hari.
class _RouteActions extends StatelessWidget {
  const _RouteActions({required this.points});

  /// Terbaru dulu (urutan repository).
  final List<HistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final days = groupByDay(points).length;
    final canCompare = days >= 2;
    // Putar hari terbaru yang punya minimal 2 titik (urut waktu naik).
    final latestDay = groupByDay(
      points,
    ).map((e) => e.$2).where((d) => d.length >= 2).firstOrNull;
    final asc = latestDay ?? const <HistoryPoint>[];

    Widget btn(String label, IconData icon, VoidCallback? onTap, bool primary) {
      final tint = AppColors.tint.resolveFrom(context);
      final fg = primary
          ? AppColors.onTint.resolveFrom(context)
          : AppColors.textPrimary.resolveFrom(context);
      return Expanded(
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          excludeSemantics: true,
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary
                      ? tint
                      : AppColors.surfaceHigh.resolveFrom(context),
                  borderRadius: BorderRadius.circular(999),
                  border: primary
                      ? null
                      : Border.all(
                          color: AppColors.separator.resolveFrom(context),
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, fill: primary ? 1 : 0, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.labelMd(context, color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            btn(
              RouteStrings.play,
              Symbols.play_arrow,
              asc.length < 2
                  ? null
                  : () => context.push(ProfileRoutes.playbackPath, extra: asc),
              true,
            ),
            const SizedBox(width: 10),
            btn(
              RouteStrings.compare,
              Symbols.compare_arrows,
              canCompare
                  ? () => context.push(ProfileRoutes.comparePath, extra: points)
                  : null,
              false,
            ),
          ],
        ),
        if (!canCompare && points.length >= 2)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              RouteStrings.compareNeedTwoDays,
              style: AppTextStyles.caption1(
                context,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}
