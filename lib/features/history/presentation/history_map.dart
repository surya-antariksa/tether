import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../map/presentation/members_map.dart' show kUserAgentPackageName;
import '../../map/presentation/osm_attribution.dart';
import '../domain/history_point.dart';
import '../../map/presentation/map_theme.dart';
import 'history_strings.dart';

/// Peta ringkas jejak: garis dari titik terlama ke terbaru. Tidak interaktif
/// (tidak berebut gestur dengan daftar yang bisa digulir).
class HistoryMap extends StatelessWidget {
  const HistoryMap({
    super.key,
    required this.points,
    required this.tileProvider,
    this.height = 180,
  });

  /// Terbaru dulu (urutan repository).
  final List<HistoryPoint> points;
  final TileProvider tileProvider;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = [for (final p in points.reversed) p.point];
    final tint = CupertinoDynamicColor.resolve(AppColors.tint, context);
    final grey = CupertinoDynamicColor.resolve(
      AppColors.textSecondary,
      context,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                label: HistoryStrings.mapLabel,
                child: ExcludeSemantics(
                  child: FlutterMap(
                    options: MapOptions(
                      backgroundColor: mapBackground(context),
                      initialCenter: track.last,
                      initialZoom: 14,
                      initialCameraFit: track.length > 1
                          ? CameraFit.coordinates(
                              coordinates: track,
                              padding: const EdgeInsets.all(32),
                              maxZoom: 16,
                            )
                          : null,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      ThemedTileLayer(
                        userAgentPackageName: kUserAgentPackageName,
                        tileProvider: tileProvider,
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(points: track, strokeWidth: 4, color: tint),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          _dot(track.first, grey),
                          _dot(track.last, tint),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.groupedBackground
                      .resolveFrom(context)
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.separator
                        .resolveFrom(context)
                        .withValues(alpha: 0.15),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.resolveFrom(context),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success
                                .resolveFrom(context)
                                .withValues(alpha: 0.60),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GPS Presisi Aktif',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary.resolveFrom(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(right: 4, bottom: 4, child: OsmAttribution()),
          ],
        ),
      ),
    );
  }

  static Marker _dot(LatLng at, Color color) => Marker(
    point: at,
    width: 16,
    height: 16,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: CupertinoColors.white, width: 2),
      ),
    ),
  );
}
