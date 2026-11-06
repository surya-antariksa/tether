import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../map/data/map_providers.dart';
import '../../map/presentation/map_theme.dart';
import '../../map/presentation/members_map.dart' show kUserAgentPackageName;
import '../../map/presentation/osm_attribution.dart';
import '../domain/history_point.dart';
import '../domain/route_stats.dart';
import 'route_strings.dart';

/// Membandingkan dua hari dari riwayat: jejak keduanya di satu peta dan
/// selisih jarak, durasi, kecepatan. Semua dari titik yang tercatat.
class RouteComparePage extends ConsumerStatefulWidget {
  const RouteComparePage({super.key, required this.points});

  /// Titik riwayat (urutan bebas).
  final List<HistoryPoint> points;

  @override
  ConsumerState<RouteComparePage> createState() => _RouteComparePageState();
}

class _RouteComparePageState extends ConsumerState<RouteComparePage> {
  late final List<(DateTime, List<HistoryPoint>)> _days = groupByDay(
    widget.points,
  );
  // Hari terbaru dulu: A = hari sebelumnya, B = terbaru.
  int _a = 1;
  int _b = 0;

  static String _dayName(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _pick(bool forA) async {
    final picked = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(RouteStrings.chooseDay),
        actions: [
          for (var i = 0; i < _days.length; i++)
            CupertinoActionSheetAction(
              isDefaultAction: i == (forA ? _a : _b),
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text(
                '${_dayName(_days[i].$1)} (${_days[i].$2.length} titik)',
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(RouteStrings.cancel),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => forA ? _a = picked : _b = picked);
  }

  static String _km(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  static String _dur(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} j ${d.inMinutes % 60} mnt';
    return '${d.inMinutes} mnt';
  }

  /// "+1,2 km lebih" / "-3 mnt kurang" / "sama" untuk b dibanding a.
  static String _delta(double a, double b, String Function(double) fmt) {
    final d = b - a;
    if (d.abs() < 0.0001) return RouteStrings.same;
    final sign = d > 0 ? '+' : '-';
    final word = d > 0 ? RouteStrings.moreThan : RouteStrings.lessThan;
    return '$sign${fmt(d.abs())} $word';
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    final warn = AppColors.warning.resolveFrom(context);
    final tiles = ref.watch(mapTileProviderProvider);
    final ready = _days.length >= 2;
    final a = ready ? _days[_a].$2 : const <HistoryPoint>[];
    final b = ready ? _days[_b].$2 : const <HistoryPoint>[];
    final sa = RouteStats.of(a);
    final sb = RouteStats.of(b);
    final all = [
      for (final p in [...a, ...b]) p.point,
    ];

    Widget row(String label, String va, String vb, String delta) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              va,
              textAlign: TextAlign.end,
              style: AppTextStyles.callout(
                context,
                emphasized: true,
              ).copyWith(color: warn),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              vb,
              textAlign: TextAlign.end,
              style: AppTextStyles.callout(
                context,
                emphasized: true,
              ).copyWith(color: tint),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              delta,
              textAlign: TextAlign.end,
              style: AppTextStyles.caption1(
                context,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );

    Widget picker(bool forA) => Expanded(
      child: Semantics(
        button: true,
        label:
            '${forA ? RouteStrings.dayA : RouteStrings.dayB}: ${_dayName(_days[forA ? _a : _b].$1)}',
        excludeSemantics: true,
        onTap: () => _pick(forA),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pick(forA),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: forA ? warn : tint, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forA ? RouteStrings.dayA : RouteStrings.dayB,
                        style: AppTextStyles.caption2(
                          context,
                          emphasized: true,
                          color: forA ? AppColors.warning : AppColors.tint,
                        ),
                      ),
                      Text(
                        _dayName(_days[forA ? _a : _b].$1),
                        style: AppTextStyles.callout(context, emphasized: true),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.unfold_more,
                  size: 18,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(RouteStrings.compareTitle),
      ),
      child: AtmosphereBackground(
        child: SafeArea(
          child: !ready
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      RouteStrings.compareNeedTwoDays,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        picker(true),
                        const SizedBox(width: 10),
                        picker(false),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: RouteStrings.tracksLegend,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 240,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ExcludeSemantics(
                                  child: FlutterMap(
                                    key: ValueKey('$_a-$_b'),
                                    options: MapOptions(
                                      backgroundColor: mapBackground(context),
                                      initialCameraFit: CameraFit.coordinates(
                                        coordinates: all,
                                        padding: const EdgeInsets.all(36),
                                        maxZoom: 17,
                                      ),
                                      interactionOptions:
                                          const InteractionOptions(
                                            flags:
                                                InteractiveFlag.pinchZoom |
                                                InteractiveFlag.drag,
                                          ),
                                    ),
                                    children: [
                                      ThemedTileLayer(
                                        userAgentPackageName:
                                            kUserAgentPackageName,
                                        tileProvider: tiles,
                                      ),
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: [
                                              for (final p in a) p.point,
                                            ],
                                            strokeWidth: 4,
                                            color: warn,
                                          ),
                                          Polyline(
                                            points: [
                                              for (final p in b) p.point,
                                            ],
                                            strokeWidth: 4,
                                            color: tint,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 6,
                                bottom: 4,
                                child: OsmAttribution(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionLabel(RouteStrings.deltaTitle),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          row(
                            RouteStrings.distance,
                            _km(sa.distanceM),
                            _km(sb.distanceM),
                            _delta(sa.distanceM, sb.distanceM, _km),
                          ),
                          row(
                            RouteStrings.movingTime,
                            _dur(sa.movingDuration),
                            _dur(sb.movingDuration),
                            _delta(
                              sa.movingDuration.inSeconds.toDouble(),
                              sb.movingDuration.inSeconds.toDouble(),
                              (v) => _dur(Duration(seconds: v.round())),
                            ),
                          ),
                          row(
                            RouteStrings.avgSpeed,
                            '${sa.avgSpeedKmh.round()}',
                            '${sb.avgSpeedKmh.round()}',
                            _delta(
                              sa.avgSpeedKmh,
                              sb.avgSpeedKmh,
                              (v) => '${v.round()} ${RouteStrings.kmh}',
                            ),
                          ),
                          row(
                            RouteStrings.maxSpeed,
                            '${sa.maxSpeedKmh.round()}',
                            '${sb.maxSpeedKmh.round()}',
                            _delta(
                              sa.maxSpeedKmh,
                              sb.maxSpeedKmh,
                              (v) => '${v.round()} ${RouteStrings.kmh}',
                            ),
                          ),
                          row(
                            RouteStrings.points,
                            '${sa.count}',
                            '${sb.count}',
                            _delta(
                              sa.count.toDouble(),
                              sb.count.toDouble(),
                              (v) => '${v.round()}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
