import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/map/domain/map_member.dart';
import 'package:tether/features/map/domain/paused_until.dart';
import 'package:tether/features/map/presentation/members_sheet.dart';
import 'package:tether/features/map/presentation/pause_sheet.dart';
import 'package:tether/features/map/presentation/relative_time.dart';

import 'fake_map_repository.dart';
import 'map_harness.dart' show fixedNow;

Duration mins(int m) => Duration(minutes: m);

Finder inSheet(String text) => find.descendant(
  of: find.byType(CupertinoActionSheet),
  matching: find.text(text),
);

Finder inRow(String text) =>
    find.descendant(of: find.byType(MemberRow), matching: find.text(text));

MapMember member(
  String id,
  String name, {
  PausedUntil pause = PausedUntil.none,
  bool sharing = true,
  MemberLocation? location,
}) => MapMember(
  userId: id,
  displayName: name,
  colorHex: '#2563EB',
  sharingEnabled: sharing,
  pause: pause,
  location: location,
);

Future<Callbacks> pumpSheet(
  WidgetTester tester, {
  required List<MapMember> members,
  String? selfId = 'u1',
  bool busy = false,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final cb = Callbacks();
  final controller = DraggableScrollableController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    CupertinoApp(
      theme: appTheme,
      home: CupertinoPageScaffold(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MembersSheet(
              controller: controller,
              circleName: 'Keluarga',
              members: members,
              selfId: selfId,
              now: fixedNow,
              busy: busy,
              onMemberTap: cb.taps.add,
              onPause: () => cb.pauses++,
              onResume: () => cb.resumes++,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return cb;
}

class Callbacks {
  final taps = <MapMember>[];
  int pauses = 0;
  int resumes = 0;
}

void main() {
  group('MembersSheet', () {
    testWidgets('kosong: judul jumlah 0, pesan, tanpa tombol Jeda', (
      tester,
    ) async {
      await pumpSheet(tester, members: const [], selfId: null);

      expect(find.text('Keluarga · 0 anggota'), findsOneWidget);
      expect(find.text('Belum ada anggota.'), findsOneWidget);
      expect(find.text('Jeda'), findsNothing);
      expect(find.text('Lanjutkan'), findsNothing);
      expect(find.byType(MemberRow), findsNothing);
    });

    testWidgets('diri sendiri tak ada di daftar: tanpa tombol Jeda', (
      tester,
    ) async {
      await pumpSheet(tester, members: [member('u2', 'Raka')]);

      expect(find.text('Jeda'), findsNothing);
      expect(find.byType(MemberRow), findsOneWidget);
    });

    testWidgets(
      'urutan: diri sendiri dulu, lalu nama tanpa peduli huruf besar',
      (tester) async {
        await pumpSheet(
          tester,
          members: [
            member('u2', 'dewi'),
            member('u3', 'Citra'),
            member('u1', 'Zahra'),
            member('u4', 'Anton'),
          ],
        );

        final order = tester
            .widgetList<MemberRow>(find.byType(MemberRow))
            .map((r) => r.member.displayName)
            .toList();
        expect(order, ['Zahra', 'Anton', 'Citra', 'dewi']);
        expect(inRow('Zahra (Kamu)'), findsOneWidget);
      },
    );

    testWidgets('aktif: status Bergerak, waktu, baterai, ikon', (tester) async {
      await pumpSheet(
        tester,
        members: [
          member(
            'u2',
            'Raka',
            location: locationAt(
              fixedNow.subtract(mins(3)),
              battery: 64,
              moving: true,
            ),
          ),
        ],
      );

      expect(inRow('Raka'), findsOneWidget);
      expect(inRow('Bergerak'), findsOneWidget);
      expect(inRow('Diperbarui 3 mnt lalu'), findsOneWidget);
      expect(inRow('64%'), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.arrow_up_right_circle_fill),
        findsOneWidget,
      );
    });

    testWidgets('aktif diam dan aktif tanpa data gerak', (tester) async {
      await pumpSheet(
        tester,
        members: [
          member('u2', 'Raka', location: locationAt(fixedNow, moving: false)),
          member('u3', 'Sari', location: locationAt(fixedNow)),
        ],
      );

      expect(inRow('Diam'), findsOneWidget);
      expect(inRow('Aktif'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.stop_circle), findsOneWidget);
      expect(inRow('Baterai 0%'), findsNothing);
    });

    testWidgets(
      'basi: teks terakhir terlihat, tanpa Diperbarui, baterai tetap',
      (tester) async {
        await pumpSheet(
          tester,
          members: [
            member(
              'u2',
              'Raka',
              location: locationAt(
                fixedNow.subtract(const Duration(hours: 3)),
                battery: 12,
                moving: true,
              ),
            ),
          ],
        );

        expect(inRow('Terakhir terlihat 3 jam lalu'), findsOneWidget);
        expect(find.textContaining('Diperbarui'), findsNothing);
        expect(inRow('12%'), findsOneWidget);
        // Ikon gerak hanya untuk anggota aktif.
        expect(
          find.byIcon(CupertinoIcons.arrow_up_right_circle_fill),
          findsNothing,
        );
      },
    );

    testWidgets('dijeda: status jeda, tanpa waktu/baterai walau ada lokasi', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        members: [
          member(
            'u2',
            'Raka',
            pause: PausedUntil.indefinitely,
            location: locationAt(fixedNow, battery: 50, moving: true),
          ),
        ],
      );

      expect(inRow('Menjeda berbagi lokasi'), findsOneWidget);
      expect(find.textContaining('Diperbarui'), findsNothing);
      expect(find.text('50%'), findsNothing);
    });

    testWidgets('berbagi dimatikan dihitung dijeda', (tester) async {
      await pumpSheet(tester, members: [member('u2', 'Raka', sharing: false)]);

      expect(inRow('Menjeda berbagi lokasi'), findsOneWidget);
    });

    testWidgets('belum ada lokasi', (tester) async {
      await pumpSheet(tester, members: [member('u2', 'Raka')]);

      expect(inRow('Belum ada lokasi'), findsOneWidget);
    });

    testWidgets('ketuk baris: hanya anggota bermarker memicu onMemberTap', (
      tester,
    ) async {
      final cb = await pumpSheet(
        tester,
        members: [
          member('u2', 'Anto', location: locationAt(fixedNow)),
          member(
            'u3',
            'Basi',
            location: locationAt(fixedNow.subtract(const Duration(hours: 1))),
          ),
          member('u4', 'Dijeda', pause: PausedUntil.indefinitely),
          member('u5', 'Kosong'),
        ],
      );

      await tester.tap(inRow('Dijeda'));
      await tester.tap(inRow('Kosong'));
      await tester.pump();
      expect(cb.taps, isEmpty);

      await tester.tap(inRow('Anto'));
      await tester.tap(inRow('Basi'));
      await tester.pump();
      expect(cb.taps.map((m) => m.userId), ['u2', 'u3']);
    });

    group('header diri sendiri', () {
      testWidgets('tidak dijeda: tombol Jeda memanggil onPause', (
        tester,
      ) async {
        final cb = await pumpSheet(
          tester,
          members: [member('u1', 'Rina', location: locationAt(fixedNow))],
        );

        expect(find.text('Jeda'), findsOneWidget);
        expect(find.textContaining('Kamu menjeda'), findsNothing);
        await tester.tap(find.text('Jeda'));
        expect(cb.pauses, 1);
        expect(cb.resumes, 0);
      });

      testWidgets('jeda sampai waktu tertentu: catatan jam dan Lanjutkan', (
        tester,
      ) async {
        final until = fixedNow.add(mins(30));
        final cb = await pumpSheet(
          tester,
          members: [member('u1', 'Rina', pause: PausedUntil.at(until))],
        );

        expect(
          find.textContaining('Kamu menjeda berbagi lokasi'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Sampai pukul ${formatClock(until)}'),
          findsOneWidget,
        );
        expect(find.text('Jeda'), findsNothing);
        await tester.tap(find.text('Lanjutkan'));
        expect(cb.resumes, 1);
        expect(cb.pauses, 0);
      });

      testWidgets('jeda tanpa batas: catatan sampai dinyalakan lagi', (
        tester,
      ) async {
        await pumpSheet(
          tester,
          members: [member('u1', 'Rina', pause: PausedUntil.indefinitely)],
        );

        expect(
          find.textContaining('Sampai kamu menyalakannya lagi'),
          findsOneWidget,
        );
      });

      testWidgets('berbagi dimatikan: dijeda tanpa batas waktu', (
        tester,
      ) async {
        await pumpSheet(
          tester,
          members: [member('u1', 'Rina', sharing: false)],
        );

        expect(find.text('Lanjutkan'), findsOneWidget);
        expect(
          find.textContaining('Sampai kamu menyalakannya lagi'),
          findsOneWidget,
        );
      });

      testWidgets('jeda yang sudah lewat dianggap tidak dijeda', (
        tester,
      ) async {
        await pumpSheet(
          tester,
          members: [
            member(
              'u1',
              'Rina',
              pause: PausedUntil.at(fixedNow.subtract(mins(1))),
            ),
          ],
        );

        expect(find.text('Jeda'), findsOneWidget);
        expect(find.textContaining('Kamu menjeda'), findsNothing);
      });

      testWidgets('sibuk: indikator menggantikan tombol', (tester) async {
        await pumpSheet(tester, members: [member('u1', 'Rina')], busy: true);

        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        expect(find.text('Jeda'), findsNothing);
        expect(find.text('Lanjutkan'), findsNothing);
      });
    });

    testWidgets('Semantics baris: nama, status, waktu, baterai', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(
        tester,
        members: [
          member(
            'u1',
            'Rina',
            location: locationAt(
              fixedNow.subtract(mins(1)),
              battery: 80,
              moving: true,
            ),
          ),
          member('u2', 'Raka', pause: PausedUntil.indefinitely),
        ],
      );

      expect(
        find.bySemanticsLabel(
          'Rina, Kamu, Bergerak, Diperbarui 1 mnt lalu, Baterai 80%',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Raka, Menjeda berbagi lokasi'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('skala teks 2x tidak meluap', (tester) async {
      await pumpSheet(
        tester,
        textScale: 2.0,
        members: [
          member(
            'u1',
            'Rina Wati Kusumawardhani',
            pause: PausedUntil.at(fixedNow.add(mins(30))),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('showPauseSheet', () {
    Future<List<Object?>> open(WidgetTester tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        CupertinoApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async => results.add(await showPauseSheet(context)),
              child: const Text('buka'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('menampilkan judul, pesan, tiga durasi, dan Batal', (
      tester,
    ) async {
      await open(tester);

      expect(inSheet('Jeda berbagi lokasi'), findsOneWidget);
      expect(
        inSheet('Anggota lain melihat kamu sebagai menjeda di Circle ini.'),
        findsOneWidget,
      );
      expect(inSheet('15 menit'), findsOneWidget);
      expect(inSheet('1 jam'), findsOneWidget);
      expect(inSheet('Sampai saya nyalakan lagi'), findsOneWidget);
      expect(inSheet('Batal'), findsOneWidget);
    });

    for (final (label, minutes) in [
      ('15 menit', 15),
      ('1 jam', 60),
      ('Sampai saya nyalakan lagi', null),
    ]) {
      testWidgets('memilih "$label" mengembalikan minutes=$minutes', (
        tester,
      ) async {
        final results = await open(tester);

        await tester.tap(inSheet(label));
        await tester.pumpAndSettle();

        expect(results, hasLength(1));
        expect(results.single, isA<PauseChoice>());
        expect((results.single as PauseChoice).minutes, minutes);
        expect(find.byType(CupertinoActionSheet), findsNothing);
      });
    }

    testWidgets('Batal mengembalikan null', (tester) async {
      final results = await open(tester);

      await tester.tap(inSheet('Batal'));
      await tester.pumpAndSettle();

      expect(results, [null]);
    });
  });

  group('showCirclePicker', () {
    Future<List<String?>> open(WidgetTester tester) async {
      final results = <String?>[];
      await tester.pumpWidget(
        CupertinoApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async => results.add(
                await showCirclePicker(
                  context,
                  circles: const [
                    (id: 'c1', name: 'Keluarga'),
                    (id: 'c2', name: 'Kantor'),
                  ],
                  currentId: 'c1',
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('mendaftar Circle, Circle aktif ditandai bawaan', (
      tester,
    ) async {
      await open(tester);

      expect(inSheet('Pilih Circle'), findsOneWidget);
      final actions = tester
          .widgetList<CupertinoActionSheetAction>(
            find.byType(CupertinoActionSheetAction),
          )
          .toList();
      // Keluarga, Kantor, Batal.
      expect(actions, hasLength(3));
      expect(actions[0].isDefaultAction, isTrue);
      expect(actions[1].isDefaultAction, isFalse);
    });

    testWidgets('memilih mengembalikan id, Batal mengembalikan null', (
      tester,
    ) async {
      var results = await open(tester);
      await tester.tap(inSheet('Kantor'));
      await tester.pumpAndSettle();
      expect(results, ['c2']);

      results = await open(tester);
      await tester.tap(inSheet('Batal'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });
}
