import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:tether/core/selected_circle.dart';
import 'package:tether/features/activity/data/activity_providers.dart';
import 'package:tether/features/map/data/map_providers.dart';
import 'package:tether/features/map/domain/map_circle.dart';
import 'package:tether/features/map/domain/map_member.dart';
import 'package:tether/features/map/domain/map_repository.dart';
import 'package:tether/features/map/domain/paused_until.dart';
import 'package:tether/features/map/presentation/member_marker.dart';
import 'package:tether/features/map/presentation/members_sheet.dart';
import 'package:tether/features/map/presentation/relative_time.dart';

import 'fake_map_repository.dart';
import 'map_harness.dart';

const keluarga = MapCircle(id: 'c1', name: 'Keluarga');
const kantor = MapCircle(id: 'c2', name: 'Kantor');

Duration mins(int m) => Duration(minutes: m);

MapMember rina({
  PausedUntil pause = PausedUntil.none,
  bool sharing = true,
  MemberLocation? location,
}) => MapMember(
  userId: 'u1',
  displayName: 'Rina Wati',
  colorHex: '#0F766E',
  sharingEnabled: sharing,
  pause: pause,
  location:
      location ??
      locationAt(fixedNow.subtract(mins(1)), battery: 80, moving: true),
);

/// Rina (diri sendiri, aktif, bergerak), Raka (dijeda), Sari (basi 2 jam),
/// Budi (belum ada lokasi).
FakeMapRepository familyRepo() => FakeMapRepository(
  circles: [keluarga],
  members: {
    'c1': [
      rina(),
      MapMember(
        userId: 'u2',
        displayName: 'Raka',
        colorHex: '#2563EB',
        pause: PausedUntil.indefinitely,
      ),
      MapMember(
        userId: 'u3',
        displayName: 'Sari Dewi',
        colorHex: '#DB2777',
        location: locationAt(fixedNow.subtract(const Duration(hours: 2))),
      ),
      const MapMember(userId: 'u4', displayName: 'Budi', colorHex: '#EA580C'),
    ],
  },
);

Finder inSheet(String text) => find.descendant(
  of: find.byType(CupertinoActionSheet),
  matching: find.text(text),
);

/// Teks di dalam baris panel anggota (nama yang sama juga ada di label marker).
Finder inRow(String text) =>
    find.descendant(of: find.byType(MemberRow), matching: find.text(text));

Finder inDialog(String text) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(text),
);

/// Indikator sibuk di panel tetap berputar selama dialog galat tampil, jadi
/// pumpAndSettle tidak akan selesai: maju beberapa frame saja.
Future<void> pumpDialog(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lepas pohon widget agar timer kedaluwarsa jeda dibatalkan sebelum tes
/// selesai (pemeriksaan timer berjalan sebelum addTearDown).
Future<void> unmount(WidgetTester tester, MapHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  h.container.dispose();
}

void main() {
  group('daftar Circle', () {
    testWidgets('memuat: indikator, belum ada peta', (tester) async {
      final repo = FakeMapRepository(circles: [keluarga])
        ..circlesGate = Completer<void>();
      await pumpMapApp(tester, repo: repo, settle: false);

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Belum ada Circle'), findsNothing);
      expect(find.text('Peta tidak bisa dimuat.'), findsNothing);
      expect(find.byType(MembersSheet), findsNothing);

      repo.circlesGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MembersSheet), findsOneWidget);
    });

    testWidgets('kosong: ajakan membuat Circle, tombol membuka tab Circle', (
      tester,
    ) async {
      final repo = FakeMapRepository();
      await pumpMapApp(tester, repo: repo);

      expect(find.text('Belum ada Circle'), findsOneWidget);
      expect(find.textContaining('Buat Circle atau gabung'), findsOneWidget);
      expect(find.byType(MembersSheet), findsNothing);

      await tester.tap(find.text('Buka tab Circle'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman tab Circle'), findsOneWidget);
    });

    testWidgets('galat: pesan dan Coba lagi memuat ulang', (tester) async {
      final repo = FakeMapRepository(circles: [keluarga])
        ..circlesFailure = const MapFailure(MapFailureKind.network);
      await pumpMapApp(tester, repo: repo);

      expect(find.text('Peta tidak bisa dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.byType(MembersSheet), findsNothing);
      final calls = repo.fetchCirclesCalls;

      repo.circlesFailure = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(repo.fetchCirclesCalls, greaterThan(calls));
      expect(find.text('Peta tidak bisa dimuat.'), findsNothing);
      expect(find.byType(MembersSheet), findsOneWidget);
    });

    testWidgets('tanpa pilihan: Circle pertama dipilih otomatis', (
      tester,
    ) async {
      final repo = FakeMapRepository(
        circles: [keluarga, kantor],
        members: {
          'c1': [rina()],
        },
      );
      final h = await pumpMapApp(tester, repo: repo);

      expect(h.container.read(selectedCircleIdProvider), 'c1');
      expect(find.text('Keluarga'), findsOneWidget);
      expect(repo.fetchMembersCalls, ['c1']);
    });

    testWidgets('pilihan yang sudah ada dihormati', (tester) async {
      final repo = FakeMapRepository(
        circles: [keluarga, kantor],
        members: {
          'c1': [rina()],
          'c2': [rina()],
        },
      );
      final h = await pumpMapApp(tester, repo: repo);
      // Sebelum pilihan diubah, tab menampilkan c1; ganti lewat provider.
      h.container.read(selectedCircleIdProvider.notifier).select('c2');
      await tester.pumpAndSettle();

      expect(find.text('Kantor'), findsOneWidget);
      expect(repo.fetchMembersCalls, contains('c2'));
    });

    testWidgets('pemilih Circle: judul diketuk, pilih Circle lain', (
      tester,
    ) async {
      final repo = FakeMapRepository(
        circles: [keluarga, kantor],
        members: {
          'c1': [rina()],
          'c2': [rina()],
        },
      );
      final h = await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Keluarga'));
      await tester.pumpAndSettle();
      expect(inSheet('Pilih Circle'), findsOneWidget);
      expect(inSheet('Keluarga'), findsOneWidget);
      expect(inSheet('Kantor'), findsOneWidget);

      await tester.tap(inSheet('Kantor'));
      await tester.pumpAndSettle();

      expect(h.container.read(selectedCircleIdProvider), 'c2');
      expect(find.text('Kantor'), findsOneWidget);
      expect(find.text('Kantor · 1 anggota'), findsOneWidget);
    });

    testWidgets('satu Circle: judul bukan tombol pemilih', (tester) async {
      await pumpMapApp(tester, repo: familyRepo());

      await tester.tap(find.text('Keluarga'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
    });

    testWidgets('batal di pemilih tidak mengganti Circle', (tester) async {
      final repo = FakeMapRepository(
        circles: [keluarga, kantor],
        members: {
          'c1': [rina()],
        },
      );
      final h = await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Keluarga'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Batal'));
      await tester.pumpAndSettle();

      expect(h.container.read(selectedCircleIdProvider), 'c1');
      expect(find.byType(CupertinoActionSheet), findsNothing);
    });
  });

  group('anggota Circle', () {
    testWidgets('memuat: indikator, panel belum tampil', (tester) async {
      final repo = familyRepo()..membersGate = Completer<void>();
      await pumpMapApp(tester, repo: repo, settle: false);
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(MembersSheet), findsNothing);

      repo.membersGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MembersSheet), findsOneWidget);
    });

    testWidgets('galat: pesan, Coba lagi memuat ulang anggota', (tester) async {
      final repo = familyRepo()
        ..membersFailure = const MapFailure(MapFailureKind.network);
      await pumpMapApp(tester, repo: repo);

      expect(find.text('Peta tidak bisa dimuat.'), findsOneWidget);
      expect(find.byType(MembersSheet), findsNothing);

      repo.membersFailure = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Peta tidak bisa dimuat.'), findsNothing);
      expect(find.byType(MembersSheet), findsOneWidget);
    });

    testWidgets('Circle tanpa anggota lain: panel menampilkan jumlah 0', (
      tester,
    ) async {
      final repo = FakeMapRepository(circles: [keluarga], members: {'c1': []});
      await pumpMapApp(tester, repo: repo);

      expect(find.text('Keluarga · 0 anggota'), findsOneWidget);
      expect(find.text('Belum ada anggota.'), findsOneWidget);
      expect(find.byType(MemberMarker), findsNothing);
      // Tanpa marker, tombol pusatkan nonaktif; atribusi tetap ada.
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('aktif, dijeda, basi, tanpa lokasi: baris dan marker', (
      tester,
    ) async {
      await pumpMapApp(tester, repo: familyRepo());

      expect(find.text('Keluarga · 4 anggota'), findsOneWidget);
      expect(inRow('Rina Wati (Kamu)'), findsOneWidget);
      expect(find.text('Bergerak'), findsOneWidget);
      expect(find.text('Diperbarui 1 mnt lalu'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      expect(inRow('Raka'), findsOneWidget);
      expect(find.text('Menjeda berbagi lokasi'), findsOneWidget);

      expect(inRow('Sari Dewi'), findsOneWidget);
      expect(find.text('Terakhir terlihat 2 jam lalu'), findsOneWidget);

      expect(inRow('Budi'), findsOneWidget);
      expect(find.text('Belum ada lokasi'), findsOneWidget);

      // Marker hanya untuk Rina (aktif) dan Sari (basi).
      expect(find.byType(MemberMarker), findsNWidgets(2));
      final markers = tester
          .widgetList<MemberMarker>(find.byType(MemberMarker))
          .toList();
      expect(markers.map((m) => m.name).toSet(), {'Rina Wati', 'Sari Dewi'});
      expect(
        markers.firstWhere((m) => m.name == 'Rina Wati').semanticLabel,
        'Rina Wati, Kamu, Bergerak, Diperbarui 1 mnt lalu',
      );
      expect(
        markers.firstWhere((m) => m.name == 'Sari Dewi').semanticLabel,
        'Sari Dewi, Terakhir terlihat 2 jam lalu',
      );
    });

    testWidgets('diri sendiri digambar paling atas (terakhir)', (tester) async {
      final repo = FakeMapRepository(
        circles: [keluarga],
        members: {
          'c1': [
            rina(),
            MapMember(
              userId: 'u3',
              displayName: 'Sari Dewi',
              colorHex: '#DB2777',
              location: locationAt(fixedNow),
            ),
          ],
        },
      );
      await pumpMapApp(tester, repo: repo);

      final names = tester
          .widgetList<MemberMarker>(find.byType(MemberMarker))
          .map((m) => m.name)
          .toList();
      expect(names, ['Sari Dewi', 'Rina Wati']);
    });

    testWidgets('tile palsu dipakai, tanpa jaringan', (tester) async {
      final h = await pumpMapApp(tester, repo: familyRepo());

      expect(h.tiles.requests, greaterThan(0));
    });

    testWidgets('atribusi OSM tampil, diketuk membuka penjelasan lisensi', (
      tester,
    ) async {
      await pumpMapApp(tester, repo: familyRepo());

      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      await tester.tap(find.text('© OpenStreetMap contributors'));
      await tester.pumpAndSettle();
      expect(inDialog('Atribusi peta'), findsOneWidget);
      expect(find.textContaining('ODbL'), findsOneWidget);

      await tester.tap(inDialog('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('galat anggota: peta tidak tampil, atribusi ikut hilang', (
      tester,
    ) async {
      final repo = familyRepo()
        ..membersFailure = const MapFailure(MapFailureKind.network);
      await pumpMapApp(tester, repo: repo);

      expect(find.text('© OpenStreetMap contributors'), findsNothing);
    });

    testWidgets('skala teks besar tidak membuat layout meluap', (tester) async {
      await pumpMapApp(tester, repo: familyRepo(), textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    });
  });

  group('jam peta', () {
    testWidgets(
      'waktu maju: anggota aktif menjadi basi dan waktu relatif ikut',
      (tester) async {
        final h = await pumpMapApp(tester, repo: familyRepo());
        expect(find.text('Bergerak'), findsOneWidget);

        h.clock.advance(mins(45));
        await tester.pumpAndSettle();

        expect(find.text('Bergerak'), findsNothing);
        expect(find.text('Terakhir terlihat 46 mnt lalu'), findsOneWidget);
      },
    );
  });

  group('realtime', () {
    testWidgets('lokasi anggota berubah lewat StatusChanged', (tester) async {
      final repo = familyRepo();
      await pumpMapApp(tester, repo: repo);
      expect(find.text('Terakhir terlihat 2 jam lalu'), findsOneWidget);

      repo.events.add(
        StatusChanged(
          'u3',
          locationAt(fixedNow.subtract(mins(2)), moving: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terakhir terlihat 2 jam lalu'), findsNothing);
      expect(find.text('Diam'), findsOneWidget);
      expect(find.text('Diperbarui 2 mnt lalu'), findsOneWidget);
    });

    testWidgets('StatusChanged anggota Circle lain diabaikan', (tester) async {
      final repo = familyRepo();
      await pumpMapApp(tester, repo: repo);

      repo.events.add(StatusChanged('asing', locationAt(fixedNow)));
      await tester.pumpAndSettle();

      expect(find.text('Keluarga · 4 anggota'), findsOneWidget);
      expect(find.byType(MemberMarker), findsNWidgets(2));
    });

    testWidgets('RefreshNeeded memuat ulang anggota tanpa loading', (
      tester,
    ) async {
      final repo = familyRepo();
      await pumpMapApp(tester, repo: repo);
      final before = repo.fetchMembersCalls.length;

      repo.members['c1'] = [
        ...repo.members['c1']!,
        const MapMember(userId: 'u5', displayName: 'Tika', colorHex: '#7C3AED'),
      ];
      repo.events.add(const RefreshNeeded());
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      await tester.pumpAndSettle();

      expect(repo.fetchMembersCalls.length, before + 1);
      expect(find.text('Keluarga · 5 anggota'), findsOneWidget);
    });

    testWidgets('koneksi terputus menampilkan chip, tersambung memuat ulang', (
      tester,
    ) async {
      final repo = familyRepo();
      await pumpMapApp(tester, repo: repo);
      expect(find.text('Menyambung ulang'), findsNothing);
      final before = repo.fetchMembersCalls.length;

      repo.events.add(const ConnectionChanged(connected: false));
      await tester.pumpAndSettle();
      expect(find.text('Menyambung ulang'), findsOneWidget);

      repo.events.add(const ConnectionChanged(connected: true));
      await tester.pumpAndSettle();
      expect(find.text('Menyambung ulang'), findsNothing);
      expect(repo.fetchMembersCalls.length, before + 1);
    });
  });

  group('jeda berbagi', () {
    testWidgets('Jeda 15 menit: panggil repo, tampil catatan dan Lanjutkan', (
      tester,
    ) async {
      final repo = familyRepo();
      final h = await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();
      expect(inSheet('Jeda berbagi lokasi'), findsOneWidget);

      await tester.tap(inSheet('15 menit'));
      await tester.pumpAndSettle();

      expect(repo.pauseCalls, [(circleId: 'c1', minutes: 15)]);
      expect(find.text('Lanjutkan'), findsOneWidget);
      expect(find.text('Jeda'), findsNothing);
      expect(
        find.textContaining('Kamu menjeda berbagi lokasi'),
        findsOneWidget,
      );
      final clock = formatClock(fixedNow.add(mins(15)));
      expect(find.textContaining('Sampai pukul $clock'), findsOneWidget);
      // Rina dijeda: markernya hilang, tinggal Sari.
      expect(find.byType(MemberMarker), findsOneWidget);
      await unmount(tester, h);
    });

    testWidgets('Jeda sampai dinyalakan lagi, lalu Lanjutkan', (tester) async {
      final repo = familyRepo();
      await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Sampai saya nyalakan lagi'));
      await tester.pumpAndSettle();

      expect(repo.pauseCalls, [(circleId: 'c1', minutes: null)]);
      expect(
        find.textContaining('Sampai kamu menyalakannya lagi'),
        findsOneWidget,
      );

      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      expect(repo.resumeCalls, ['c1']);
      expect(find.text('Jeda'), findsOneWidget);
      expect(find.textContaining('Kamu menjeda berbagi lokasi'), findsNothing);
      expect(find.byType(MemberMarker), findsNWidgets(2));
    });

    testWidgets('batal di lembar jeda tidak memanggil repo', (tester) async {
      final repo = familyRepo();
      await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Batal'));
      await tester.pumpAndSettle();

      expect(repo.pauseCalls, isEmpty);
      expect(find.text('Jeda'), findsOneWidget);
    });

    testWidgets('gagal menjeda: dialog dengan pesan sesuai jenis galat', (
      tester,
    ) async {
      final repo = familyRepo()
        ..pauseFailure = const MapFailure(MapFailureKind.network);
      await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('1 jam'));
      await pumpDialog(tester);

      expect(inDialog('Gagal menjeda'), findsOneWidget);
      expect(
        inDialog('Tidak bisa terhubung. Periksa koneksi internet Anda.'),
        findsOneWidget,
      );
      await tester.tap(inDialog('Tutup'));
      await tester.pumpAndSettle();
      // Tombol kembali bisa dipakai (busy dibersihkan).
      expect(find.text('Jeda'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('galat non-MapFailure dipetakan ke pesan umum', (tester) async {
      final repo = familyRepo()..pauseFailure = StateError('rusak');
      await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('15 menit'));
      await pumpDialog(tester);

      expect(inDialog('Gagal menjeda'), findsOneWidget);
      expect(inDialog('Terjadi masalah. Coba lagi nanti.'), findsOneWidget);
    });

    testWidgets('gagal melanjutkan: dialog judul berbeda', (tester) async {
      final repo = FakeMapRepository(
        circles: [keluarga],
        members: {
          'c1': [rina(pause: PausedUntil.indefinitely)],
        },
      )..pauseFailure = const MapFailure(MapFailureKind.notMember);
      await pumpMapApp(tester, repo: repo);

      await tester.tap(find.text('Lanjutkan'));
      await pumpDialog(tester);

      expect(inDialog('Gagal melanjutkan'), findsOneWidget);
      expect(inDialog('Kamu bukan anggota Circle ini lagi.'), findsOneWidget);
    });
  });

  group('interaksi panel', () {
    testWidgets('ketuk baris anggota bermarker tidak menimbulkan galat', (
      tester,
    ) async {
      await pumpMapApp(tester, repo: familyRepo());

      await tester.tap(inRow('Sari Dewi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MembersSheet), findsOneWidget);
    });

    testWidgets('ketuk marker memusatkan tanpa galat', (tester) async {
      await pumpMapApp(tester, repo: familyRepo());

      await tester.tap(find.byType(MemberMarker).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('baris diurutkan: diri sendiri dulu, lalu menurut nama', (
      tester,
    ) async {
      await pumpMapApp(tester, repo: familyRepo());

      final ys = {
        for (final n in ['Rina Wati (Kamu)', 'Budi', 'Raka', 'Sari Dewi'])
          n: tester.getTopLeft(inRow(n)).dy,
      };
      expect(ys['Rina Wati (Kamu)']! < ys['Budi']!, isTrue);
      expect(ys['Budi']! < ys['Raka']!, isTrue);
      expect(ys['Raka']! < ys['Sari Dewi']!, isTrue);
      expect(find.byType(MemberRow), findsNWidgets(4));
    });
  });

  group('fokus dari tab Aktivitas', () {
    FakeMapRepository twoCircles() => FakeMapRepository(
      circles: [keluarga, kantor],
      members: {
        'c1': [rina()],
        'c2': [rina()],
      },
    );

    testWidgets('Circle lain dengan anggota masih dimuat: tanpa galat, fokus '
        'diterapkan setelah peta terpasang', (tester) async {
      final repo = twoCircles();
      final h = await pumpMapApp(tester, repo: repo);
      repo.membersGate = Completer<void>();

      // Persis urutan _showOnMap di tab Aktivitas.
      h.container.read(selectedCircleIdProvider.notifier).select('c2');
      h.container
          .read(activityMapFocusProvider.notifier)
          .focus(const ActivityMapFocus(circleId: 'c2', lat: -6.9, lng: 107.6));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsNothing); // masih memuat
      expect(h.container.read(activityMapFocusProvider), isNull);

      repo.membersGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      expect(camera.zoom, greaterThanOrEqualTo(15));
      expect(camera.center.latitude, closeTo(-6.9, 0.05));
      expect(camera.center.longitude, closeTo(107.6, 0.05));
    });

    testWidgets('Circle yang sama sudah terpasang: fokus langsung diterapkan', (
      tester,
    ) async {
      final h = await pumpMapApp(tester, repo: twoCircles());
      h.container
          .read(activityMapFocusProvider.notifier)
          .focus(const ActivityMapFocus(circleId: 'c1', lat: -6.9, lng: 107.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(h.container.read(activityMapFocusProvider), isNull);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      expect(camera.center.latitude, closeTo(-6.9, 0.05));
    });
  });

  group('MapSnapshot', () {
    test('self mencari menurut selfId, null bila tidak ada', () {
      final snap = MapSnapshot(members: [rina()], selfId: 'u1');
      expect(snap.self?.displayName, 'Rina Wati');
      expect(MapSnapshot(members: [rina()], selfId: 'x').self, isNull);
      expect(const MapSnapshot(members: [], selfId: null).self, isNull);
    });

    test('copyWith mempertahankan selfId dan realtimeConnected', () {
      final snap = MapSnapshot(members: [rina()], selfId: 'u1');
      expect(snap.realtimeConnected, isTrue);
      final c = snap.copyWith(realtimeConnected: false);
      expect(c.realtimeConnected, isFalse);
      expect(c.selfId, 'u1');
      expect(c.members, snap.members);
    });
  });
}
