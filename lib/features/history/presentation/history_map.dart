import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../map/presentation/members_map.dart'
    show kTileUrlTemplate, kUserAgentPackageName;
import '../../map/presentation/osm_attribution.dart';
import '../domain/history_point.dart';
import 'history_strings.dart';

/// Peta ringkas jejak: garis dari titik terlama ke terbaru. Tidak interaktif
/// (tidak berebut gestur dengan daftar yang bisa digulir).
class HistoryMap extends StatelessWidget {
  const HistoryMap({
    super.key,
    required this.points,
    required this.tileProvider,
  });

  /// Terbaru dulu (urutan repository).
  final List<HistoryPoint> points;
  final TileProvider tileProvider;

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
        height: 220,
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                label: HistoryStrings.mapLabel,
                child: ExcludeSemantics(
                  child: FlutterMap(
                    options: MapOptions(
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
                      TileLayer(
                        urlTemplate: kTileUrlTemplate,
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
