import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/map/domain/map_circle.dart';
import 'package:tether/features/map/domain/map_member.dart';
import 'package:tether/features/places/domain/place_error.dart';
import 'package:tether/features/places/presentation/place_strings.dart';
import 'package:tether/features/places/presentation/places_page.dart';

import '../map/fake_map_repository.dart';
import '../map/map_harness.dart';
import 'fake_place_repository.dart';

FakeMapRepository mapRepo() => FakeMapRepository(
  circles: const [MapCircle(id: 'c1', name: 'Keluarga')],
  members: {
    'c1': [
      MapMember(
        userId: 'u1',
        displayName: 'Rina Wati',
        colorHex: '#0F766E',
        location: locationAt(fixedNow),
      ),
    ],
  },
);

void main() {
  testWidgets('tempat Circle digambar sebagai lingkaran radius meter + nama', (
    tester,
  ) async {
    final places = FakePlaceRepository(
      places: [
        placeOf('p1', name: 'Rumah', radiusM: 300),
        placeOf('p2', name: 'Sekolah', radiusM: 1500),
        placeOf('p3', circleId: 'c2', name: 'Circle lain'),
      ],
    );
    await pumpMapApp(tester, repo: mapRepo(), placeRepo: places);
    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(layer.circles.map((c) => c.radius), [300, 1500]);
    expect(layer.circles.every((c) => c.useRadiusInMeter), isTrue);
    expect(find.text('Rumah'), findsOneWidget);
    expect(find.text('Sekolah'), findsOneWidget);
    expect(find.text('Circle lain'), findsNothing);
  });

  testWidgets('label peta dibacakan dengan nama dan radius', (tester) async {
    final handle = tester.ensureSemantics();
    final places = FakePlaceRepository(
      places: [placeOf('p1', name: 'Rumah', radiusM: 300)],
    );
    await pumpMapApp(tester, repo: mapRepo(), placeRepo: places);
    expect(find.bySemanticsLabel('Tempat Rumah, Radius 300 m'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('galat memuat tempat tidak mengganggu peta', (tester) async {
    final places = FakePlaceRepository()
      ..placesFailure = const PlaceError(PlaceErrorKind.network);
    await pumpMapApp(tester, repo: mapRepo(), placeRepo: places);
    expect(find.text('Keluarga · 1 anggota'), findsOneWidget);
    expect(
      tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol Kelola tempat di peta membuka halaman daftar', (
    tester,
  ) async {
    final places = FakePlaceRepository(places: [placeOf('p1', name: 'Rumah')]);
    final h = await pumpMapApp(tester, repo: mapRepo(), placeRepo: places);
    final button = find.bySemanticsLabel(PlaceStrings.openFromMap);
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(PlacesPage), findsOneWidget);
    expect(h.router.state.uri.path, '/places/c1');
    expect(find.text(PlaceStrings.count(1)), findsOneWidget);
  });

  testWidgets('tombol Kelola tempat: area sentuh minimal 44 pt', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpMapApp(tester, repo: mapRepo());
    final size = tester.getSize(
      find.bySemanticsLabel(PlaceStrings.openFromMap),
    );
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    handle.dispose();
  });

  testWidgets('tempat yang dihapus lewat halaman daftar hilang dari peta', (
    tester,
  ) async {
    final places = FakePlaceRepository(places: [placeOf('p1', name: 'Rumah')]);
    final h = await pumpMapApp(tester, repo: mapRepo(), placeRepo: places);
    await tester.tap(find.bySemanticsLabel(PlaceStrings.openFromMap));
    await tester.pumpAndSettle();

    // Pembuat menghapus lewat halaman daftar; peta (di belakang) ikut berubah.
    await tester.tap(find.text('Rumah').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlaceStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text(PlaceStrings.delete),
      ),
    );
    await tester.pumpAndSettle();
    h.router.pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
      isEmpty,
    );
  });
}
