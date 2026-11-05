import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tether/features/map/data/map_providers.dart';
import 'package:tether/features/map/domain/map_circle.dart';
import 'package:tether/features/map/domain/map_member.dart';
import 'package:tether/features/map/presentation/members_map.dart';
import 'package:tether/features/places/domain/place.dart';
import 'package:tether/features/places/domain/place_error.dart';
import 'package:tether/features/places/places_routes.dart';
import 'package:tether/features/places/presentation/place_strings.dart';

import '../map/fake_map_repository.dart';
import '../map/map_harness.dart' show fixedNow;
import 'fake_place_repository.dart';
import 'places_harness.dart';

final _open = PlacesRoutes.create('c1');

/// Ketuk peta (menunggu jeda deteksi ketuk ganda flutter_map).
Future<void> tapMap(WidgetTester tester, [Offset? at]) async {
  await tester.tapAt(at ?? const Offset(195, 250));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Finder get nameField => find.byType(CupertinoTextField);

void main() {
  testWidgets('awal: petunjuk tampil, belum ada formulir', (tester) async {
    await pumpPlaces(tester, repo: FakePlaceRepository(), open: _open);
    expect(find.text(PlaceStrings.pickHint), findsOneWidget);
    expect(nameField, findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
    // Atribusi OSM wajib terlihat.
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('ketuk peta: pin, lingkaran radius, dan formulir muncul', (
    tester,
  ) async {
    await pumpPlaces(tester, repo: FakePlaceRepository(), open: _open);
    await tapMap(tester);
    expect(nameField, findsOneWidget);
    expect(find.byType(CupertinoSlider), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.location_solid), findsOneWidget);
    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer).last);
    final c = layer.circles.single;
    expect(c.useRadiusInMeter, isTrue);
    expect(c.radius, PlaceLimits.defaultRadiusM.toDouble());
  });

  testWidgets('tahan peta juga memilih titik', (tester) async {
    await pumpPlaces(tester, repo: FakePlaceRepository(), open: _open);
    await tester.longPressAt(const Offset(150, 300));
    await tester.pumpAndSettle();
    expect(nameField, findsOneWidget);
  });

  testWidgets('slider radius menggeser lingkaran dan label', (tester) async {
    await pumpPlaces(tester, repo: FakePlaceRepository(), open: _open);
    await tapMap(tester);
    final slider = tester.widget<CupertinoSlider>(find.byType(CupertinoSlider));
    expect(slider.min, 100);
    expect(slider.max, 5000);
    slider.onChanged!(1500);
    await tester.pump();
    expect(find.text('1,5 km'), findsOneWidget);
    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer).last);
    expect(layer.circles.single.radius, 1500);
  });

  testWidgets('simpan: memanggil create_place dengan nama terpangkas', (
    tester,
  ) async {
    final repo = FakePlaceRepository();
    final h = await pumpPlaces(tester, repo: repo, open: _open);
    await tapMap(tester);
    await tester.enterText(nameField, '  Sekolah ');
    tester.widget<CupertinoSlider>(find.byType(CupertinoSlider)).onChanged!(
      800,
    );
    await tester.pump();
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    final c = repo.created.single;
    expect(c.circleId, 'c1');
    expect(c.name, 'Sekolah');
    expect(c.radiusM, 800);
    // Titik ketukan dekat pusat awal peta (zoom 11), bukan koordinat acak.
    expect((c.center.latitude - kDefaultCenter.latitude).abs(), lessThan(0.2));
    expect(
      (c.center.longitude - kDefaultCenter.longitude).abs(),
      lessThan(0.2),
    );
    // Kembali ke halaman sebelumnya.
    expect(find.text('Halaman peta'), findsOneWidget);
    expect(h.router.state.uri.path, '/');
  });

  testWidgets('tombol titik tengah peta memasang pin di pusat peta', (
    tester,
  ) async {
    final repo = FakePlaceRepository();
    await pumpPlaces(tester, repo: repo, open: _open);
    await tester.tap(find.bySemanticsLabel(PlaceStrings.useMapCenter));
    await tester.pumpAndSettle();
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Taman');
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    final c = repo.created.single.center;
    expect(c.latitude, closeTo(kDefaultCenter.latitude, 1e-6));
    expect(c.longitude, closeTo(kDefaultCenter.longitude, 1e-6));
  });

  testWidgets('peta mulai dari lokasi diri sendiri bila ada', (tester) async {
    const home = LatLng(-7.25, 112.75);
    final mapRepo = FakeMapRepository(
      circles: const [MapCircle(id: 'c1', name: 'Keluarga')],
      members: {
        'c1': [
          MapMember(
            userId: 'u1',
            displayName: 'Rina',
            colorHex: '#0F766E',
            location: locationAt(fixedNow, point: home),
          ),
        ],
      },
    );
    final repo = FakePlaceRepository();
    // Anggota sudah dimuat di tab Peta sebelum halaman dibuka.
    final h = await pumpPlaces(tester, repo: repo, mapRepo: mapRepo, open: '/');
    final sub = h.container.listen(mapMembersProvider('c1'), (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    h.router.push(_open);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(PlaceStrings.useMapCenter));
    await tester.pumpAndSettle();
    await tester.enterText(nameField, 'Rumah');
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(repo.created.single.center.latitude, closeTo(home.latitude, 1e-6));
  });

  testWidgets('nama kosong: pesan, server tidak dipanggil', (tester) async {
    final repo = FakePlaceRepository();
    await pumpPlaces(tester, repo: repo, open: _open);
    await tapMap(tester);
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.nameEmpty), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('nama 41 karakter: pesan, server tidak dipanggil', (
    tester,
  ) async {
    final repo = FakePlaceRepository();
    await pumpPlaces(tester, repo: repo, open: _open);
    await tapMap(tester);
    await tester.enterText(nameField, 'x' * 41);
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.nameTooLong), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('TH005: pesan batas 5 tempat yang ramah, tetap di halaman', (
    tester,
  ) async {
    final repo = FakePlaceRepository(
      places: [for (var i = 0; i < 5; i++) placeOf('p$i', name: 'T$i')],
    );
    await pumpPlaces(tester, repo: repo, open: _open);
    await tapMap(tester);
    await tester.enterText(nameField, 'Keenam');
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.limitReached)),
      findsOneWidget,
    );
    expect(find.text(PlaceStrings.pickTitle), findsWidgets);
    expect(repo.created, isEmpty);
  });

  testWidgets('42501 saat buat: bukan anggota lagi', (tester) async {
    final repo = FakePlaceRepository()
      ..mutationFailure = const PlaceError(PlaceErrorKind.notMember);
    await pumpPlaces(tester, repo: repo, open: _open);
    await tapMap(tester);
    await tester.enterText(nameField, 'Rumah');
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.notMember)),
      findsOneWidget,
    );
  });

  testWidgets('22023 dan galat jaringan menampilkan pesan Indonesia', (
    tester,
  ) async {
    final repo = FakePlaceRepository()
      ..mutationFailure = const PlaceError(PlaceErrorKind.invalid);
    await pumpPlaces(tester, repo: repo, open: _open);
    await tapMap(tester);
    await tester.enterText(nameField, 'Rumah');
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.invalid)),
      findsOneWidget,
    );

    repo.mutationFailure = const PlaceError(PlaceErrorKind.network);
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.network)),
      findsOneWidget,
    );
  });

  testWidgets('galat dihapus saat mengetik ulang nama', (tester) async {
    await pumpPlaces(tester, repo: FakePlaceRepository(), open: _open);
    await tapMap(tester);
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.nameEmpty), findsOneWidget);
    await tester.enterText(nameField, 'R');
    await tester.pump();
    expect(find.text(PlaceStrings.nameEmpty), findsNothing);
  });

  testWidgets('tempat yang sudah ada digambar di peta pemilih', (tester) async {
    final repo = FakePlaceRepository(
      places: [placeOf('p1', name: 'Rumah', radiusM: 300)],
    );
    await pumpPlaces(tester, repo: repo, open: _open);
    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer).first);
    expect(layer.circles.single.radius, 300);
    expect(find.text('Rumah'), findsOneWidget);
  });

  testWidgets('aksesibilitas: tombol titik tengah, slider, dan area sentuh', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPlaces(tester, repo: FakePlaceRepository(), open: _open);
    final centerBtn = find.bySemanticsLabel(PlaceStrings.useMapCenter);
    expect(centerBtn, findsOneWidget);
    expect(tester.getSize(centerBtn).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(centerBtn).width, greaterThanOrEqualTo(44));

    await tapMap(tester);
    expect(
      tester.getSemantics(find.byType(CupertinoSlider)),
      matchesSemantics(
        label: PlaceStrings.radiusLabel,
        value: '200 meter',
        increasedValue: '250 meter',
        decreasedValue: '150 meter',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        isSlider: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
      tester.getSize(find.byType(CupertinoSlider)).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.bySemanticsLabel(PlaceStrings.draftPinLabel), findsOneWidget);
    final save = find.widgetWithText(CupertinoButton, PlaceStrings.save);
    expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
    handle.dispose();
  });

  testWidgets('teks besar 200%: formulir tidak overflow', (tester) async {
    await pumpPlaces(
      tester,
      repo: FakePlaceRepository(),
      open: _open,
      textScale: 2.0,
    );
    await tapMap(tester);
    expect(tester.takeException(), isNull);
    expect(nameField, findsOneWidget);
  });
}
