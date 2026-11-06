import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../data/map_style_provider.dart';
import '../domain/map_style.dart';

const String kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kTopoTileUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';

/// Tipe efektif setelah [MapStyle.auto] diurai menurut mode sistem.
MapStyle effectiveMapStyle(BuildContext context, MapStyle chosen) {
  if (chosen != MapStyle.auto) return chosen;
  return AppColors.isDark(context) ? MapStyle.dark : MapStyle.standard;
}

/// Tema ubin gelap: ubin OSM diinversi dan diwarnai ke biru malam lewat filter
/// warna di klien, tanpa penyedia ubin lain.
/// out = skala * (255 - luminans) + dasar, per kanal.
const _darkMatrix = <double>[
  -0.1169, -0.3934, -0.0397, 0, 148.3, //
  -0.1382, -0.4649, -0.0469, 0, 177.8, //
  -0.1807, -0.6079, -0.0614, 0, 236.8, //
  0, 0, 0, 1, 0, //
];

Widget _darkTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) => ColorFiltered(
  colorFilter: const ColorFilter.matrix(_darkMatrix),
  child: tileWidget,
);

/// Warna latar kanvas peta saat ubin belum dimuat.
Color mapBackground(BuildContext context, [MapStyle chosen = MapStyle.auto]) =>
    effectiveMapStyle(context, chosen) == MapStyle.dark
    ? const Color(0xFF0A0F18)
    : const Color(0xFFDDDDDD);

/// Lapisan ubin sesuai tipe peta pilihan pengguna.
class ThemedTileLayer extends ConsumerWidget {
  const ThemedTileLayer({
    super.key,
    required this.tileProvider,
    required this.userAgentPackageName,
    this.maxNativeZoom = 19,
  });

  final TileProvider? tileProvider;
  final String userAgentPackageName;
  final int maxNativeZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = effectiveMapStyle(context, ref.watch(mapStyleProvider));
    final topo = style == MapStyle.topo;
    return TileLayer(
      // Kunci per tipe: ganti tipe membuang cache ubin tipe sebelumnya.
      key: ValueKey(style),
      urlTemplate: topo ? kTopoTileUrl : kOsmTileUrl,
      subdomains: const ['a', 'b', 'c'],
      tileBuilder: style == MapStyle.dark ? _darkTileBuilder : null,
      userAgentPackageName: userAgentPackageName,
      tileProvider: tileProvider,
      maxNativeZoom: topo ? 17 : maxNativeZoom,
      // Ubin yang gagal dimuat (jaringan putus sesaat) dicoba lagi saat peta
      // digeser atau di-zoom, bukan dibiarkan kosong.
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
    );
  }
}
