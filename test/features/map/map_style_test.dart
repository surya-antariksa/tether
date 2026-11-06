import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tether/features/map/data/map_style_provider.dart';
import 'package:tether/features/map/domain/map_style.dart';
import 'package:tether/features/map/presentation/map_strings.dart';
import 'package:tether/features/map/presentation/map_theme.dart';

import 'map_harness.dart';
import 'map_tab_page_test.dart' show familyRepo;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('MapStyle.fromWire: nilai tak dikenal jatuh ke otomatis', () {
    expect(MapStyle.fromWire('dark'), MapStyle.dark);
    expect(MapStyle.fromWire('topo'), MapStyle.topo);
    expect(MapStyle.fromWire('aneh'), MapStyle.auto);
    expect(MapStyle.fromWire(null), MapStyle.auto);
  });

  test('pilihan disimpan dan dibaca ulang', () async {
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    expect(c1.read(mapStyleProvider), MapStyle.auto);
    await c1.read(mapStyleProvider.notifier).select(MapStyle.topo);
    expect(c1.read(mapStyleProvider), MapStyle.topo);

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(mapStyleProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(mapStyleProvider), MapStyle.topo);
  });

  testWidgets('tombol Tipe peta: sheet pilihan, memilih Topografi', (
    tester,
  ) async {
    final h = await pumpMapApp(tester, repo: familyRepo());
    expect(h.container.read(mapStyleProvider), MapStyle.auto);

    await tester.tap(find.bySemanticsLabel(MapStrings.mapTypeLabel));
    await tester.pumpAndSettle();
    expect(find.text(MapStrings.mapTypeTitle), findsOneWidget);
    expect(find.text(MapStrings.mapTypeAuto), findsOneWidget);
    expect(find.text(MapStrings.mapTypeActive.toUpperCase()), findsOneWidget);
    expect(find.text(MapStrings.mapTypeTopoDesc), findsOneWidget);

    await tester.tap(find.text(MapStrings.mapTypeTopo));
    await tester.pumpAndSettle();
    expect(h.container.read(mapStyleProvider), MapStyle.topo);
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, kTopoTileUrl);
    expect(find.text(MapStrings.osmAttributionTopo), findsOneWidget);
  });

  testWidgets('Gelap memakai ubin OSM dengan filter warna', (tester) async {
    final h = await pumpMapApp(tester, repo: familyRepo());
    await h.container.read(mapStyleProvider.notifier).select(MapStyle.dark);
    await tester.pumpAndSettle();
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, kOsmTileUrl);
    expect(layer.tileBuilder, isNotNull);
  });
}
