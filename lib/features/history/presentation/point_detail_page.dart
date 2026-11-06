import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../activity/data/activity_providers.dart';
import '../../location_tracking/domain/geo.dart';
import '../../map/data/map_providers.dart';
import '../../map/presentation/map_theme.dart';
import '../../map/presentation/members_map.dart' show kUserAgentPackageName;
import '../../map/presentation/osm_attribution.dart';
import '../../places/places_routes.dart';
import '../domain/history_point.dart';
import 'route_strings.dart';

/// Detail satu titik riwayat: peta kecil dengan lingkar akurasi, koordinat,
/// waktu, status, akurasi, baterai, kecepatan, dan jarak dari titik
/// sebelumnya. Hanya nilai yang tercatat yang ditampilkan.
class PointDetailPage extends ConsumerStatefulWidget {
  const PointDetailPage({super.key, required this.point, this.previous});

  final HistoryPoint point;

  /// Titik tercatat tepat sebelumnya (waktu lebih awal), bila ada.
  final HistoryPoint? previous;

  @override
  ConsumerState<PointDetailPage> createState() => _PointDetailPageState();
}

class _PointDetailPageState extends ConsumerState<PointDetailPage> {
  bool _copied = false;

  String get _coords =>
      '${widget.point.point.latitude.toStringAsFixed(5)}, '
      '${widget.point.point.longitude.toStringAsFixed(5)}';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _coords));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  static String _dateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} '
        '${two(t.hour)}.${two(t.minute)}.${two(t.second)}';
  }

  static String _gap(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} j ${d.inMinutes % 60} mnt';
    if (d.inMinutes >= 1) return '${d.inMinutes} mnt';
    return '${d.inSeconds} dtk';
  }

  void _showOnMap() {
    final circleId = ref.read(selectedCircleIdProvider);
    if (circleId == null) return;
    ref
        .read(activityMapFocusProvider.notifier)
        .focus(
          ActivityMapFocus(
            circleId: circleId,
            lat: widget.point.point.latitude,
            lng: widget.point.point.longitude,
          ),
        );
    context.go(AppRoutes.map);
  }

  void _makePlace() {
    final circleId = ref.read(selectedCircleIdProvider);
    if (circleId == null) return;
    context.push(
      PlacesRoutes.create(
        circleId,
        lat: widget.point.point.latitude,
        lng: widget.point.point.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.point;
    final prev = widget.previous;
    final tint = AppColors.tint.resolveFrom(context);
    final tiles = ref.watch(mapTileProviderProvider);
    final hasCircle = ref.watch(selectedCircleIdProvider) != null;
    final dist = prev == null
        ? null
        : haversineMeters(
            prev.point.latitude,
            prev.point.longitude,
            p.point.latitude,
            p.point.longitude,
          ).round();
    final gap = prev == null ? null : p.recordedAt.difference(prev.recordedAt);

    Widget cell(String label, String value, IconData icon) => Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.caption2(
                context,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.callout(context, emphasized: true),
            ),
          ],
        ),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(RouteStrings.detailTitle),
      ),
      child: AtmosphereBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: FlutterMap(
                            options: MapOptions(
                              backgroundColor: mapBackground(context),
                              initialCenter: p.point,
                              initialZoom: 16,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              ThemedTileLayer(
                                userAgentPackageName: kUserAgentPackageName,
                                tileProvider: tiles,
                              ),
                              if (p.accuracyM != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: p.point,
                                      radius: p.accuracyM!,
                                      useRadiusInMeter: true,
                                      color: tint.withValues(alpha: 0.15),
                                      borderColor: tint.withValues(alpha: 0.6),
                                      borderStrokeWidth: 1.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: p.point,
                                    width: 22,
                                    height: 22,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: tint,
                                        border: Border.all(
                                          color: AppColors.background
                                              .resolveFrom(context),
                                          width: 3,
                                        ),
                                      ),
                                    ),
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
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RouteStrings.coordinates.toUpperCase(),
                      style: AppTextStyles.caption2(
                        context,
                        color: AppColors.textTertiary,
                      ).copyWith(letterSpacing: 0.7),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _coords,
                            style: AppTextStyles.title3(context),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: RouteStrings.copyCoordinates,
                          excludeSemantics: true,
                          onTap: _copy,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _copy,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                _copied ? Symbols.check : Symbols.content_copy,
                                size: 20,
                                color: tint,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateTime(p.recordedAt),
                      style: AppTextStyles.footnote(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  cell(
                    RouteStrings.status,
                    p.isMoving
                        ? RouteStrings.movingLabel
                        : RouteStrings.stillLabel,
                    p.isMoving ? Symbols.directions_run : Symbols.pause_circle,
                  ),
                  const SizedBox(width: 10),
                  cell(
                    RouteStrings.accuracy,
                    p.accuracyM == null
                        ? RouteStrings.unavailable
                        : '±${p.accuracyM!.round()} m',
                    Symbols.my_location,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  cell(
                    RouteStrings.battery,
                    p.batteryPct == null
                        ? RouteStrings.unavailable
                        : '${p.batteryPct}%',
                    Symbols.battery_full,
                  ),
                  const SizedBox(width: 10),
                  cell(
                    RouteStrings.speed,
                    p.speedKmh == null
                        ? RouteStrings.unavailable
                        : '${p.speedKmh!.round()} ${RouteStrings.kmh}',
                    Symbols.speed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionLabel(RouteStrings.movementTitle),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Symbols.timeline, size: 22, color: tint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dist == null
                            ? RouteStrings.noPrevious
                            : RouteStrings.sincePrevious(dist, _gap(gap!)),
                        style: AppTextStyles.callout(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TintPillButton(
                label: RouteStrings.makePlace,
                icon: Symbols.bookmark,
                expand: true,
                onPressed: hasCircle ? _makePlace : null,
              ),
              const SizedBox(height: 10),
              Semantics(
                button: true,
                label: RouteStrings.showOnMap,
                excludeSemantics: true,
                onTap: hasCircle ? _showOnMap : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasCircle ? _showOnMap : null,
                  child: Opacity(
                    opacity: hasCircle ? 1 : 0.5,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.resolveFrom(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.separator.resolveFrom(context),
                        ),
                      ),
                      child: Text(
                        RouteStrings.showOnMap,
                        style: AppTextStyles.labelMd(context),
                      ),
                    ),
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
