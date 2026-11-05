import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/places/data/place_providers.dart';
import 'package:tether/features/places/domain/place.dart';
import 'package:tether/features/places/domain/place_error.dart';
import 'package:tether/features/places/presentation/place_strings.dart';
import 'package:tether/features/places/presentation/places_page.dart';

import 'fake_place_repository.dart';
import 'places_harness.dart';

List<Place> five() => [
  for (var i = 0; i < 5; i++) placeOf('p$i', name: 'Tempat $i'),
];

void main() {
  testWidgets('memuat: indikator aktivitas, tombol Tambah nonaktif', (
    tester,
  ) async {
    final repo = FakePlaceRepository()..placesGate = Completer<void>();
    await pumpPlaces(tester, repo: repo, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    final add = tester.widget<CupertinoButton>(
      find.widgetWithText(CupertinoButton, PlaceStrings.add),
    );
    expect(add.onPressed, isNull);
    repo.placesGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.emptyTitle), findsOneWidget);
  });

  testWidgets('kosong: judul, penjelasan, dan tombol Tambah tempat', (
    tester,
  ) async {
    await pumpPlaces(tester, repo: FakePlaceRepository());
    expect(find.text(PlaceStrings.emptyTitle), findsOneWidget);
    expect(find.text(PlaceStrings.emptyBody), findsOneWidget);
    expect(find.text(PlaceStrings.addPlace), findsOneWidget);
  });

  testWidgets('kosong: Tambah tempat membuka pemilih titik', (tester) async {
    await pumpPlaces(tester, repo: FakePlaceRepository());
    await tester.tap(find.text(PlaceStrings.addPlace));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.pickTitle), findsWidgets);
    expect(find.text(PlaceStrings.pickHint), findsOneWidget);
  });

  testWidgets('galat memuat: pesan dan Coba lagi memuat ulang', (tester) async {
    final repo = FakePlaceRepository()
      ..placesFailure = const PlaceError(PlaceErrorKind.network);
    await pumpPlaces(tester, repo: repo);
    expect(find.text(PlaceStrings.loadFailed), findsOneWidget);
    repo.placesFailure = null;
    repo.all.add(placeOf('p1', name: 'Sekolah'));
    await tester.tap(find.text(PlaceStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text('Sekolah'), findsOneWidget);
  });

  testWidgets('daftar: nama, radius, dan hitungan', (tester) async {
    final repo = FakePlaceRepository(
      places: [
        placeOf('p1', name: 'Rumah', radiusM: 200),
        placeOf('p2', name: 'Sekolah', radiusM: 1500),
        placeOf('p3', circleId: 'c2', name: 'Circle lain'),
      ],
    );
    await pumpPlaces(tester, repo: repo);
    expect(find.text('Rumah'), findsOneWidget);
    expect(find.text('Sekolah'), findsOneWidget);
    expect(find.text('Circle lain'), findsNothing);
    expect(find.text('Radius 200 m'), findsOneWidget);
    expect(find.text('Radius 1,5 km'), findsOneWidget);
    expect(find.text(PlaceStrings.count(2)), findsOneWidget);
    expect(find.text(PlaceStrings.limitNote), findsNothing);
  });

  testWidgets('lima tempat: Tambah nonaktif dan catatan batas tampil', (
    tester,
  ) async {
    await pumpPlaces(tester, repo: FakePlaceRepository(places: five()));
    expect(find.text(PlaceStrings.limitNote), findsOneWidget);
    final add = tester.widget<CupertinoButton>(
      find.widgetWithText(CupertinoButton, PlaceStrings.add),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('baris tempat orang lain tidak bisa diubah oleh anggota biasa', (
    tester,
  ) async {
    final repo = FakePlaceRepository(
      places: [placeOf('p1', name: 'Kantor', createdBy: 'u2')],
    );
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Kantor'));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.editTitle), findsNothing);
  });

  testWidgets('admin boleh mengubah tempat orang lain', (tester) async {
    final repo = FakePlaceRepository(
      places: [placeOf('p1', name: 'Kantor', createdBy: 'u2')],
      admin: true,
    );
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Kantor'));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.editTitle), findsOneWidget);
  });

  testWidgets('ubah nama dan radius memanggil update_place lalu menyegarkan', (
    tester,
  ) async {
    final repo = FakePlaceRepository(
      places: [placeOf('p1', name: 'Rumah', radiusM: 200)],
    );
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Rumah'),
      '  Rumah Nenek ',
    );
    tester.widget<CupertinoSlider>(find.byType(CupertinoSlider)).onChanged!(
      1000,
    );
    await tester.pump();
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();

    expect(repo.updated, [(placeId: 'p1', name: 'Rumah Nenek', radiusM: 1000)]);
    expect(find.text(PlaceStrings.editTitle), findsNothing);
    expect(find.text('Rumah Nenek'), findsOneWidget);
    expect(find.text('Radius 1 km'), findsOneWidget);
  });

  testWidgets('nama kosong ditolak di klien tanpa memanggil server', (
    tester,
  ) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '   ');
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.nameEmpty), findsOneWidget);
    expect(repo.updated, isEmpty);
  });

  testWidgets('nama 41 karakter ditolak', (tester) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'a' * 41);
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.nameTooLong), findsOneWidget);
    expect(repo.updated, isEmpty);
  });

  testWidgets('42501 saat ubah: pesan ramah, lembar tetap terbuka', (
    tester,
  ) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')])
      ..mutationFailure = const PlaceError(PlaceErrorKind.notAllowed);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.notAllowed)),
      findsOneWidget,
    );
    expect(find.text(PlaceStrings.editTitle), findsOneWidget);
  });

  testWidgets('P0002 saat ubah: pesan tempat tidak ditemukan', (tester) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    repo.all.clear(); // dihapus anggota lain saat lembar terbuka
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.notFound)),
      findsOneWidget,
    );
  });

  testWidgets('22023 dari server: pesan nama dan radius', (tester) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')])
      ..mutationFailure = const PlaceError(PlaceErrorKind.invalid);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.invalid)),
      findsOneWidget,
    );
  });

  testWidgets('galat tak dikenal (bukan PlaceError) menjadi pesan umum', (
    tester,
  ) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')])
      ..mutationFailure = StateError('rahasia -6.2088');
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlaceStrings.save));
    await tester.pumpAndSettle();
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.unknown)),
      findsOneWidget,
    );
    expect(find.textContaining('6.2088'), findsNothing);
  });

  testWidgets('hapus: konfirmasi dulu, Batal tidak menghapus', (tester) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlaceStrings.delete));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.deleteConfirmTitle), findsOneWidget);
    expect(repo.deleted, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text(PlaceStrings.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    expect(find.text(PlaceStrings.editTitle), findsOneWidget);
  });

  testWidgets('hapus bisa dijalankan lewat aksi ketuk semantik', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel(PlaceStrings.delete));
    await tester.pumpAndSettle();
    expect(find.text(PlaceStrings.deleteConfirmTitle), findsOneWidget);
    handle.dispose();
  });

  testWidgets('hapus dikonfirmasi: memanggil delete_place dan daftar kosong', (
    tester,
  ) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
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
    expect(repo.deleted, ['p1']);
    expect(find.text(PlaceStrings.editTitle), findsNothing);
    expect(find.text(PlaceStrings.emptyTitle), findsOneWidget);
  });

  testWidgets('hapus gagal 42501: pesan ramah di lembar', (tester) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')])
      ..mutationFailure = const PlaceError(PlaceErrorKind.notAllowed);
    await pumpPlaces(tester, repo: repo);
    await tester.tap(find.text('Rumah'));
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
    expect(
      find.text(PlaceStrings.error(PlaceErrorKind.notAllowed)),
      findsOneWidget,
    );
    expect(find.text('Rumah'), findsWidgets);
  });

  testWidgets('aksesibilitas: label baris dan area sentuh minimal 44 pt', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final repo = FakePlaceRepository(
      places: [
        placeOf('p1', name: 'Rumah', radiusM: 200),
        placeOf('p2', name: 'Kantor', createdBy: 'u2'),
      ],
    );
    await pumpPlaces(tester, repo: repo);

    expect(
      tester.getSemantics(find.text('Rumah')),
      matchesSemantics(
        label: 'Rumah, Radius 200 m, ketuk untuk mengubah',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Kantor, Radius 200 m'), findsOneWidget);

    for (final f in [
      find.widgetWithText(CupertinoButton, PlaceStrings.add),
      find.ancestor(
        of: find.text('Rumah'),
        matching: find.byType(CupertinoListTile),
      ),
    ]) {
      final size = tester.getSize(f);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    }
    handle.dispose();
  });

  testWidgets('teks besar 200%: daftar tetap terbangun tanpa overflow', (
    tester,
  ) async {
    final repo = FakePlaceRepository(
      places: [placeOf('p1', name: 'Rumah Nenek di Kampung Halaman Jauh')],
    );
    await pumpPlaces(tester, repo: repo, textScale: 2.0);
    expect(find.byType(PlacesPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifier: mutasi gagal tetap menyegarkan daftar', (
    tester,
  ) async {
    final repo = FakePlaceRepository(places: [placeOf('p1')]);
    final h = await pumpPlaces(tester, repo: repo);
    final before = repo.placesCalls;
    repo.mutationFailure = const PlaceError(PlaceErrorKind.limitReached);
    await expectLater(
      h.container
          .read(placesProvider('c1').notifier)
          .create(name: 'X', center: placeOf('z').center, radiusM: 200),
      throwsA(isA<PlaceError>()),
    );
    expect(repo.placesCalls, greaterThan(before));
  });
}
