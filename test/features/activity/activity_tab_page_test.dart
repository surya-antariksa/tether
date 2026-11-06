import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/selected_circle.dart';
import 'package:tether/core/widgets/glass_card.dart';
import 'package:tether/features/activity/data/activity_providers.dart';
import 'package:tether/features/activity/domain/activity_event.dart';
import 'package:tether/features/activity/domain/notification_gateway.dart';

import 'activity_harness.dart';
import 'fake_activity.dart';

FakeActivityRepository sampleRepo() => FakeActivityRepository(
  events: {
    'c1': [
      ev('a', minutesAgo: 5, place: 'Rumah'),
      ev('b', minutesAgo: 90, type: ActivityType.memberJoined, name: 'Budi'),
      ev('c', minutesAgo: 3000, type: ActivityType.leave, place: 'Sekolah'),
      ev('d', minutesAgo: 20, userId: 'u1', type: ActivityType.resumed),
    ],
  },
  names: {'u2': 'Sinta', 'u1': 'Rina'},
);

Future<void> scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('memuat: indikator tampil', (tester) async {
    final repo = sampleRepo()..fetchGate = Completer<void>();
    await pumpActivityApp(tester, repo: repo, settle: false);
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsWidgets);
    repo.fetchGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sinta tiba di Rumah'), findsOneWidget);
  });

  testWidgets('sukses: kalimat Indonesia, waktu relatif, "Anda" untuk diri', (
    tester,
  ) async {
    await pumpActivityApp(tester, repo: sampleRepo());
    expect(find.text('Aktivitas'), findsOneWidget); // judul bar
    expect(find.text('Keluarga'), findsOneWidget);
    expect(find.text('Sinta tiba di Rumah'), findsOneWidget);
    expect(find.text('5 mnt lalu'), findsOneWidget);
    expect(find.text('Budi bergabung ke Circle'), findsOneWidget);
    expect(find.text('1 jam lalu'), findsOneWidget);
    expect(find.text('Sinta meninggalkan Sekolah'), findsOneWidget);
    expect(find.text('2 hari lalu'), findsOneWidget);
    expect(find.text('Anda melanjutkan berbagi lokasi'), findsOneWidget);
    expect(find.text('Tidak ada aktivitas yang lebih lama'), findsOneWidget);
  });

  testWidgets('urutan terbaru dulu', (tester) async {
    await pumpActivityApp(tester, repo: sampleRepo());
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(
      y('Sinta tiba di Rumah'),
      lessThan(y('Anda melanjutkan berbagi lokasi')),
    );
    expect(
      y('Anda melanjutkan berbagi lokasi'),
      lessThan(y('Budi bergabung ke Circle')),
    );
    expect(
      y('Budi bergabung ke Circle'),
      lessThan(y('Sinta meninggalkan Sekolah')),
    );
  });

  testWidgets('kosong: pesan dan petunjuk', (tester) async {
    await pumpActivityApp(tester, repo: FakeActivityRepository());
    expect(find.text('Belum ada aktivitas'), findsOneWidget);
    expect(find.textContaining('check-in Circle'), findsOneWidget);
  });

  testWidgets('galat: pesan dan coba lagi memuat ulang', (tester) async {
    final repo = sampleRepo()..fetchFailure = Exception('x');
    await pumpActivityApp(tester, repo: repo);
    expect(find.text('Aktivitas tidak bisa dimuat.'), findsOneWidget);
    final retry = find.text('Coba lagi');
    expect(
      tester
          .getSize(
            find
                .ancestor(of: retry, matching: find.byType(CupertinoButton))
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );

    repo.fetchFailure = null;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Sinta tiba di Rumah'), findsOneWidget);
  });

  testWidgets('tanpa Circle: ajakan', (tester) async {
    await pumpActivityApp(tester, repo: sampleRepo(), circles: const []);
    expect(find.text('Belum ada Circle'), findsOneWidget);
  });

  testWidgets('event realtime muncul langsung di atas', (tester) async {
    final repo = sampleRepo();
    await pumpActivityApp(tester, repo: repo);
    repo.insert(
      ev(
        'n',
        minutesAgo: 0,
        userId: 'u3',
        name: 'Dewi',
        type: ActivityType.memberLeft,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dewi keluar dari Circle'), findsOneWidget);
    expect(find.text('baru saja'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Dewi keluar dari Circle')).dy,
      lessThan(tester.getTopLeft(find.text('Sinta tiba di Rumah')).dy),
    );
  });

  testWidgets('indikator koneksi realtime terputus', (tester) async {
    final repo = sampleRepo();
    await pumpActivityApp(tester, repo: repo);
    expect(find.text('Menyambung ulang'), findsNothing);
    repo.connection(false);
    await tester.pumpAndSettle();
    expect(find.text('Menyambung ulang'), findsOneWidget);
    repo.connection(true);
    await tester.pumpAndSettle();
    expect(find.text('Menyambung ulang'), findsNothing);
  });

  group('paginasi', () {
    FakeActivityRepository many() => FakeActivityRepository(
      events: {
        'c1': [
          for (var i = 0; i < 40; i++)
            ev('e$i', minutesAgo: i + 1, place: 'Tempat $i'),
        ],
      },
      names: {'u2': 'Sinta'},
    );

    testWidgets('tombol muat lebih lama menambah daftar', (tester) async {
      await pumpActivityApp(tester, repo: many());
      await scrollToEnd(tester);
      expect(find.text('Sinta tiba di Tempat 35'), findsNothing);
      await tester.tap(find.text('Muat yang lebih lama'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);
      expect(find.text('Sinta tiba di Tempat 35'), findsOneWidget);
    });

    testWidgets('gagal memuat: tombol coba lagi tetap ada', (tester) async {
      final repo = many();
      await pumpActivityApp(tester, repo: repo);
      await scrollToEnd(tester);
      repo.fetchFailuresLeft = 1;
      await tester.tap(find.text('Muat yang lebih lama'));
      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat. Ketuk untuk coba lagi.'), findsOneWidget);
      await tester.tap(find.text('Gagal memuat. Ketuk untuk coba lagi.'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);
    });
  });

  group('SOS', () {
    FakeActivityRepository sosRepo({bool coords = true}) =>
        FakeActivityRepository(
          events: {
            'c1': [
              ev(
                's1',
                minutesAgo: 2,
                type: ActivityType.sos,
                name: 'Sinta',
                lat: coords ? -6.2 : null,
                lng: coords ? 106.8 : null,
                triggeredAt: fixedNow.subtract(const Duration(minutes: 2)),
              ),
              ev('a', minutesAgo: 60, place: 'Rumah', name: null),
            ],
          },
          names: {'u2': 'Sinta'},
        );

    testWidgets('tampil menonjol dengan waktu dan tombol ke peta', (
      tester,
    ) async {
      await pumpActivityApp(tester, repo: sosRepo());
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('SOS dari Sinta'), findsOneWidget);
      expect(find.textContaining('mnt lalu'), findsWidgets);
      // Jam lokal tampil di samping waktu relatif.
      expect(find.textContaining(' · 2 mnt lalu'), findsOneWidget);
      expect(find.text('Lihat di peta'), findsOneWidget);
    });

    testWidgets(
      'tombol ke peta memilih Circle, menyimpan fokus, pindah ke tab Peta',
      (tester) async {
        final h = await pumpActivityApp(tester, repo: sosRepo());
        await tester.tap(find.text('Lihat di peta'));
        await tester.pumpAndSettle();
        expect(find.text('Halaman tab Peta'), findsOneWidget);
        expect(h.container.read(selectedCircleIdProvider), 'c1');
        final focus = h.container.read(activityMapFocusProvider)!;
        expect((focus.circleId, focus.lat, focus.lng), ('c1', -6.2, 106.8));
      },
    );

    testWidgets('tombol ke peta berukuran minimal 44 dan berlabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpActivityApp(tester, repo: sosRepo());
      final button = find.ancestor(
        of: find.text('Lihat di peta'),
        matching: find.byType(CupertinoButton),
      );
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(
        find.bySemanticsLabel('Lihat lokasi SOS Sinta di peta'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Lihat lokasi SOS Sinta di peta'),
        ),
        isSemantics(isButton: true),
      );
      handle.dispose();
    });

    testWidgets('tombol ke peta bisa dijalankan lewat aksi ketuk semantik', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = await pumpActivityApp(tester, repo: sosRepo());
      tester.semantics.tap(
        find.semantics.byLabel('Lihat lokasi SOS Sinta di peta'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Halaman tab Peta'), findsOneWidget);
      expect(h.container.read(activityMapFocusProvider), isNotNull);
      handle.dispose();
    });

    testWidgets('tanpa koordinat: tanpa tombol, ada keterangan', (
      tester,
    ) async {
      await pumpActivityApp(tester, repo: sosRepo(coords: false));
      expect(find.text('SOS dari Sinta'), findsOneWidget);
      expect(find.text('Lihat di peta'), findsNothing);
      expect(find.text('Lokasi sudah tidak tersimpan.'), findsOneWidget);
    });
  });

  testWidgets('aksesibilitas: setiap baris punya satu label gabungan', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpActivityApp(tester, repo: sampleRepo());
    expect(
      find.bySemanticsLabel('Sinta tiba di Rumah, 5 mnt lalu'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Budi bergabung ke Circle, 1 jam lalu'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Circle Keluarga'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('baris biasa berukuran minimal 44 pt', (tester) async {
    await pumpActivityApp(tester, repo: sampleRepo());
    final tile = find.ancestor(
      of: find.text('Sinta tiba di Rumah'),
      matching: find.byType(GlassCard),
    );
    expect(tester.getSize(tile.first).height, greaterThanOrEqualTo(44));
  });

  testWidgets('skala teks 2.0 tanpa overflow', (tester) async {
    await pumpActivityApp(tester, repo: sampleRepo(), textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.text('Sinta tiba di Rumah'), findsOneWidget);
  });

  group('beberapa Circle', () {
    testWidgets('judul membuka pemilih, memilih mengganti daftar', (
      tester,
    ) async {
      final repo = FakeActivityRepository(
        events: {
          'c1': [ev('a', place: 'Rumah', name: null)],
          'c2': [ev('b', circleId: 'c2', place: 'Kantor Pusat')],
        },
        names: {'u2': 'Sinta'},
      );
      await pumpActivityApp(
        tester,
        repo: repo,
        circles: const [keluarga, kantor],
      );
      expect(find.text('Sinta tiba di Rumah'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Circle Keluarga, ketuk untuk ganti Circle'),
        findsOneWidget,
      );

      await tester.tap(find.text('Keluarga'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Circle'), findsOneWidget);
      await tester.tap(find.text('Kantor'));
      await tester.pumpAndSettle();
      expect(find.text('Sinta tiba di Kantor Pusat'), findsOneWidget);
      expect(find.text('Sinta tiba di Rumah'), findsNothing);
    });

    testWidgets('judul bisa membuka pemilih lewat aksi ketuk semantik', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpActivityApp(
        tester,
        repo: FakeActivityRepository(
          events: {
            'c1': [ev('a', place: 'Rumah', name: null)],
          },
          names: {'u2': 'Sinta'},
        ),
        circles: const [keluarga, kantor],
      );
      tester.semantics.tap(
        find.semantics.byLabel('Circle Keluarga, ketuk untuk ganti Circle'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pilih Circle'), findsOneWidget);
      handle.dispose();
    });
  });

  group('lencana tab', () {
    testWidgets('event baru saat tab terlihat tidak menambah lencana', (
      tester,
    ) async {
      final repo = sampleRepo();
      final h = await pumpActivityApp(tester, repo: repo);
      expect(h.container.read(activityUnreadProvider), 0);
      repo.insert(
        ev(
          'n',
          minutesAgo: 0,
          userId: 'u3',
          name: 'Dewi',
          type: ActivityType.memberLeft,
        ),
      );
      await tester.pumpAndSettle();
      expect(h.container.read(activityUnreadProvider), 0);
      expect(h.gateway.shown, isEmpty);
    });

    testWidgets(
      'lencana tampil bila ada belum dibaca dan menghilang setelah dibaca',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = sampleRepo()..unreadIds = ['x', 'y', 'z'];
        final h = await pumpActivityApp(tester, repo: repo);
        // Tab tersembunyi (ticker cabang mati).
        h.tabEnabled.value = false;
        await tester.pumpAndSettle();
        repo.insert(
          ev(
            'n1',
            minutesAgo: 0,
            userId: 'u3',
            name: 'Dewi',
            type: ActivityType.memberLeft,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(find.bySemanticsLabel('1 belum dibaca'), findsOneWidget);
        await h.container.read(activityUnreadProvider.notifier).markAllRead();
        await tester.pumpAndSettle();
        expect(find.text('1'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('di atas 99 tampil 99+', (tester) async {
      final repo = sampleRepo()
        ..unreadIds = [for (var i = 0; i < 100; i++) 'i$i'];
      final h = await pumpActivityApp(tester, repo: repo);
      h.tabEnabled.value = false;
      await tester.pumpAndSettle();
      repo.connection(false);
      repo.connection(true);
      await tester.pumpAndSettle();
      expect(find.text('99+'), findsOneWidget);
    });
  });

  testWidgets('notifikasi SOS ditampilkan lewat gateway palsu', (tester) async {
    final repo = sampleRepo();
    final h = await pumpActivityApp(tester, repo: repo);
    repo.insert(
      ev(
        's9',
        userId: 'u3',
        type: ActivityType.sos,
        name: 'Dewi',
        lat: 1,
        lng: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(h.gateway.shown.single.urgency, NotificationUrgency.high);
    expect(h.gateway.shown.single.title, 'SOS dari Dewi');
  });
}
