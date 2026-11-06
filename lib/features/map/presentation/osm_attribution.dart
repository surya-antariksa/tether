import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../data/map_style_provider.dart';
import '../domain/map_style.dart';
import 'map_strings.dart';

/// Atribusi OSM yang wajib terlihat. Diketuk membuka penjelasan lisensi
/// (tanpa tautan keluar: paket peluncur URL belum jadi dependensi).
class OsmAttribution extends ConsumerWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topo = ref.watch(mapStyleProvider) == MapStyle.topo;
    final bg = AppColors.background
        .resolveFrom(context)
        .withValues(alpha: 0.85);
    return Semantics(
      button: true,
      label: MapStrings.attributionLabel,
      onTap: () => _show(context),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _show(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    topo
                        ? MapStrings.osmAttributionTopo
                        : MapStrings.osmAttribution,
                    style: AppTextStyles.caption1(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _show(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(MapStrings.attributionTitle),
        content: const Text(MapStrings.osmAttributionHint),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(MapStrings.close),
          ),
        ],
      ),
    );
  }
}
