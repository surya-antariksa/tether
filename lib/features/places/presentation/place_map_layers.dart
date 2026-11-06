import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../domain/place.dart';
import 'place_strings.dart';

/// Lingkaran radius tempat (dalam meter, ikut zoom). Lapisan peta: letakkan di
/// dalam children FlutterMap, di atas tile dan di bawah marker anggota.
class PlaceCirclesLayer extends StatelessWidget {
  const PlaceCirclesLayer({super.key, required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    return CircleLayer(
      circles: [
        for (final p in places)
          CircleMarker(
            point: p.center,
            radius: p.radiusM.toDouble(),
            useRadiusInMeter: true,
            color: tint.withValues(alpha: 0.14),
            borderColor: tint,
            borderStrokeWidth: 2,
          ),
      ],
    );
  }
}

/// Nama tempat di titik pusatnya. Tidak menangkap sentuhan.
class PlaceLabelsLayer extends StatelessWidget {
  const PlaceLabelsLayer({super.key, required this.places});

  final List<Place> places;

  static const _width = 148.0;
  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        for (final p in places)
          Marker(
            point: p.center,
            width: _width,
            height: _height,
            child: IgnorePointer(
              child: Semantics(
                label: PlaceStrings.mapLabel(p),
                excludeSemantics: true,
                child: _PlaceChip(name: p.name),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background
              .resolveFrom(context)
              .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.location_on, size: 12, color: tint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption1(context, emphasized: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
