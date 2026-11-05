import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/circle/domain/circle.dart';
import 'package:tether/features/circle/domain/circle_repository.dart';

import 'package:tether/core/widgets/primary_button.dart';

import '../../support/fake_circle_repository.dart';
import '../../support/pump_circle.dart';

Finder inDialog(String text) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(text),
);

Finder inSheet(String text) => find.descendant(
  of: find.byType(CupertinoActionSheet),
  matching: find.text(text),
);

const keluarga = Circle(id: 'c1', name: 'Keluarga');
const kantor = Circle(id: 'c2', name: 'Kantor');

/// user-1 (Rina) admin, Raka anggota, Sari anggota dengan jeda tanpa batas.
FakeCircleRepository adminRepo() => FakeCircleRepository(
  circles: [keluarga],
  members: {
    'c1': [
      fakeMember(
        'user-1',
        'Rina Wati',
        role: CircleRole.admin,
        color: '#0F766E',
      ),
      fakeMember('user-2', 'Raka', joinedDay: 2),
      fakeMember('user-3', 'Sari Dewi', joinedDay: 3, pausedIndefinitely: true),
    ],
  },
);

/// user-1 hanyalah anggota biasa.
FakeCircleRepository memberRepo() => FakeCircleRepository(
  circles: [keluarga],
  members: {
    'c1': [
      fakeMember('user-9', 'Ibu Rina', role: CircleRole.admin),
      fakeMember('user-1', 'Rina Wati', joinedDay: 2),
    ],
  },
);

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  group('keadaan kosong', () {
    testWidgets('satu tombol primer dan tautan sekunder', (tester) async {
      final repo = FakeCircleRepository();
      final c = await pumpCircleApp(tester, repo: repo);

      expect(find.text('Belum ada Circle'), findsOneWidget);
      expect(find.text('Buat Circle'), findsOneWidget);
      expect(find.text('Gabung dengan kode'), findsOneWidget);
      expect(find.text('Undang'), findsNothing);
      // Satu tombol menonjol (primer); tautan gabung adalah tombol teks biasa.
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(selectedCircle(c), isNull);
    });

    testWidgets('Buat Circle membuka form, tautan membuka input kode', (
      tester,
    ) async {
      await pumpCircleApp(tester, repo: FakeCircleRepository());

      await tester.tap(find.text('Buat Circle'));
      await tester.pumpAndSettle();
      expect(find.text('Mis. Keluarga'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gabung dengan kode'));
      await tester.pumpAndSettle();
      expect(find.text('Kode 6 karakter'), findsOneWidget);
    });
  });

  group('daftar anggota', () {
    testWidgets('nama, peran, status teks, avatar inisial; tanpa koordinat', (
      tester,
    ) async {
      final c = await pumpCircleApp(tester, repo: adminRepo());

      expect(find.text('Keluarga'), findsOneWidget);
      expect(find.text('3 anggota'), findsOneWidget);
      expect(find.text('Rina Wati'), findsOneWidget);
      expect(find.text('(Kamu)'), findsOneWidget);
      expect(find.text('Raka'), findsOneWidget);
      expect(find.text('Sari Dewi'), findsOneWidget);
      expect(find.text('RW'), findsOneWidget);
      expect(find.text('SD'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Anggota'), findsNWidgets(2));
      // 2 status anggota + 1 judul baris sakelar berbagi.
      expect(find.text('Berbagi lokasi'), findsNWidgets(3));
      expect(find.text('Menjeda berbagi lokasi'), findsOneWidget);
      expect(selectedCircle(c), 'c1');

      final coord = RegExp(r'-?\d{1,3}\.\d{3,}');
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && coord.hasMatch(w.data ?? ''),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'jeda kedaluwarsa tampil sebagai berbagi; dimatikan tampil teks',
      (tester) async {
        final repo = FakeCircleRepository(
          circles: [keluarga],
          members: {
            'c1': [
              fakeMember('user-1', 'Rina Wati', role: CircleRole.admin),
              fakeMember(
                'user-2',
                'Raka',
                pausedUntil: DateTime.now().subtract(const Duration(hours: 1)),
              ),
              fakeMember('user-3', 'Sari', sharingEnabled: false),
            ],
          },
        );
        await pumpCircleApp(tester, repo: repo);

        expect(find.text('Berbagi lokasi'), findsNWidgets(3)); // 2 status + baris sakelar
        expect(find.text('Berbagi lokasi dimatikan'), findsOneWidget);
        expect(find.text('Menjeda berbagi lokasi'), findsNothing);
      },
    );

    testWidgets('pilihan yang sudah ada dipertahankan', (tester) async {
      final repo = adminRepo()
        ..circles.add(kantor)
        ..membersByCircle['c2'] = [
          fakeMember('user-1', 'Rina Wati', role: CircleRole.admin),
        ];
      final c = await pumpCircleApp(tester, repo: repo);
      expect(selectedCircle(c), 'c1');
    });
  });

  group('sakelar berbagi', () {
    testWidgets('sakelar mengikuti status berbagi diri sendiri', (tester) async {
      final repo = FakeCircleRepository(
        circles: [keluarga],
        members: {
          'c1': [
            fakeMember(
              'user-1',
              'Rina Wati',
              role: CircleRole.admin,
              sharingEnabled: false,
            ),
            fakeMember('user-2', 'Raka'),
          ],
        },
      );
      await pumpCircleApp(tester, repo: repo);

      Finder sw({bool? value}) => find.byWidgetPredicate(
        (w) => w is CupertinoSwitch && (value == null || w.value == value),
      );
      expect(sw(value: false), findsOneWidget);
      expect(sw(value: true), findsNothing);
    });

    testWidgets('menggeser sakelar menyimpan dan status diperbarui', (
      tester,
    ) async {
      final repo = adminRepo();
      await pumpCircleApp(tester, repo: repo);

      Finder sw({bool? value}) => find.byWidgetPredicate(
        (w) => w is CupertinoSwitch && (value == null || w.value == value),
      );
      await tester.tap(sw(value: true));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('setSharingEnabled:c1:false'));
      expect(sw(value: false), findsOneWidget);
      expect(find.text('Berbagi lokasi dimatikan'), findsOneWidget);
    });

    testWidgets('gagal menyimpan: sakelar kembali dan dialog galat', (
      tester,
    ) async {
      final repo = adminRepo()
        ..failures['setSharingEnabled:c1:false'] = const CircleError(
          CircleErrorKind.network,
        );
      await pumpCircleApp(tester, repo: repo);

      Finder sw({bool? value}) => find.byWidgetPredicate(
        (w) => w is CupertinoSwitch && (value == null || w.value == value),
      );
      await tester.tap(sw(value: true));
      await tester.pumpAndSettle();

      expect(inDialog('Tidak bisa terhubung. Periksa koneksi internet kamu.'),
          findsOneWidget);
      expect(sw(value: true), findsOneWidget);
      expect(find.text('Berbagi lokasi dimatikan'), findsNothing);
      await tester.tap(inDialog('Tutup'));
      await tester.pumpAndSettle();
    });
  });

  group('undang', () {
    testWidgets('admin: kode besar, masa berlaku, catatan 48 jam, salin', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = adminRepo();
      await pumpCircleApp(tester, repo: repo);

      await tester.tap(find.text('Undang'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('createInvite:c1'));
      expect(find.text('ABC234'), findsOneWidget);
      expect(find.textContaining('Berlaku sampai'), findsOneWidget);
      expect(
        find.text('Kode berlaku 48 jam dan menggantikan kode sebelumnya.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Salin kode'));
      await tester.pumpAndSettle();
      expect(copied, ['ABC234']);
      expect(find.text('Kode tersalin'), findsOneWidget);

      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
      expect(find.text('ABC234'), findsNothing);
    });

    testWidgets('bukan admin: tidak ada tombol Undang dan Keluarkan', (
      tester,
    ) async {
      await pumpCircleApp(tester, repo: memberRepo());

      expect(find.text('Rina Wati'), findsOneWidget);
      expect(find.text('Undang'), findsNothing);
      expect(find.text('Keluarkan'), findsNothing);
      expect(find.text('Keluar dari Circle'), findsOneWidget);
    });

    testWidgets('galat server ditampilkan sebagai alert', (tester) async {
      final repo = adminRepo()
        ..failures['createInvite:c1'] = const CircleError(
          CircleErrorKind.notAdmin,
        );
      await pumpCircleApp(tester, repo: repo);

      await tester.tap(find.text('Undang'));
      await tester.pumpAndSettle();

      expect(inDialog('Hanya admin yang bisa melakukan ini.'), findsOneWidget);
    });
  });

  group('keluar dan keluarkan', () {
    testWidgets('keluar: Batal tidak memanggil, konfirmasi memanggil', (
      tester,
    ) async {
      final repo = adminRepo();
      await pumpCircleApp(tester, repo: repo);

      await scrollTo(tester, find.text('Keluar dari Circle'));
      await tester.tap(find.text('Keluar dari Circle'));
      await tester.pumpAndSettle();
      expect(inDialog('Keluar dari Keluarga?'), findsOneWidget);

      await tester.tap(inDialog('Batal'));
      await tester.pumpAndSettle();
      expect(repo.calls.any((c) => c.startsWith('leaveCircle')), isFalse);

      await tester.tap(find.text('Keluar dari Circle'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Keluar'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('leaveCircle:c1'));
      expect(find.text('Belum ada Circle'), findsOneWidget);
    });

    testWidgets('anggota terakhir diberi tahu Circle akan dihapus', (
      tester,
    ) async {
      final repo = FakeCircleRepository(
        circles: [keluarga],
        members: {
          'c1': [fakeMember('user-1', 'Rina Wati', role: CircleRole.admin)],
        },
      );
      await pumpCircleApp(tester, repo: repo);

      await tester.tap(find.text('Keluar dari Circle'));
      await tester.pumpAndSettle();
      expect(
        inDialog('Kamu anggota terakhir, jadi Circle ini akan dihapus.'),
        findsOneWidget,
      );
    });

    testWidgets('keluar dengan sisa Circle: pilihan pindah ke Circle lain', (
      tester,
    ) async {
      final repo = adminRepo()
        ..circles.add(kantor)
        ..membersByCircle['c2'] = [
          fakeMember('user-1', 'Rina Wati', role: CircleRole.admin),
        ];
      final c = await pumpCircleApp(tester, repo: repo);

      await scrollTo(tester, find.text('Keluar dari Circle'));
      await tester.tap(find.text('Keluar dari Circle'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Keluar'));
      await tester.pumpAndSettle();

      expect(selectedCircle(c), 'c2');
      expect(find.text('Kantor'), findsOneWidget);
    });

    testWidgets('keluarkan: alert destruktif, lalu anggota hilang', (
      tester,
    ) async {
      final repo = adminRepo();
      await pumpCircleApp(tester, repo: repo);

      expect(find.text('Keluarkan'), findsNWidgets(2));
      await tester.tap(find.text('Keluarkan').first);
      await tester.pumpAndSettle();
      expect(inDialog('Keluarkan Raka?'), findsOneWidget);

      final destructive = tester.widget<CupertinoDialogAction>(
        find.ancestor(
          of: inDialog('Keluarkan'),
          matching: find.byType(CupertinoDialogAction),
        ),
      );
      expect(destructive.isDestructiveAction, isTrue);

      await tester.tap(inDialog('Batal'));
      await tester.pumpAndSettle();
      expect(repo.calls.any((c) => c.startsWith('removeMember')), isFalse);

      await tester.tap(find.text('Keluarkan').first);
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Keluarkan'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('removeMember:c1:user-2'));
      expect(find.text('Raka'), findsNothing);
      expect(find.text('2 anggota'), findsOneWidget);
    });
  });

  group('beberapa Circle', () {
    testWidgets('ganti lewat action sheet menyimpan pilihan', (tester) async {
      final repo = adminRepo()
        ..circles.add(kantor)
        ..membersByCircle['c2'] = [
          fakeMember('user-1', 'Rina Wati', role: CircleRole.admin),
          fakeMember('user-5', 'Budi', joinedDay: 2),
        ];
      final c = await pumpCircleApp(tester, repo: repo);
      expect(selectedCircle(c), 'c1');

      await tester.tap(find.text('Keluarga'));
      await tester.pumpAndSettle();
      expect(inSheet('Kantor'), findsOneWidget);
      expect(inSheet('Batal'), findsOneWidget);
      await tester.tap(inSheet('Kantor'));
      await tester.pumpAndSettle();

      expect(selectedCircle(c), 'c2');
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Raka'), findsNothing);
    });

    testWidgets('satu Circle: tidak ada pengganti', (tester) async {
      await pumpCircleApp(tester, repo: adminRepo());
      await tester.tap(find.text('Keluarga'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
    });

    testWidgets('tombol tambah membuka pilihan buat atau gabung', (
      tester,
    ) async {
      await pumpCircleApp(tester, repo: adminRepo());
      await tester.tap(find.bySemanticsLabel('Tambah Circle'));
      await tester.pumpAndSettle();
      expect(inSheet('Buat Circle baru'), findsOneWidget);
      expect(inSheet('Gabung dengan kode'), findsOneWidget);
    });
  });

  group('penyegaran', () {
    testWidgets('event realtime mengambil ulang anggota tanpa loading', (
      tester,
    ) async {
      final repo = adminRepo();
      await pumpCircleApp(tester, repo: repo);
      final before = repo.membersFetches;

      repo.membersByCircle['c1']!.add(
        fakeMember('user-4', 'Budi Santoso', joinedDay: 4),
      );
      repo.emitChange('c1');
      await tester.pump();
      // Selama mengambil ulang, daftar lama tetap tampil.
      expect(find.text('Raka'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(repo.membersFetches, before + 1);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('4 anggota'), findsOneWidget);
    });

    testWidgets('tarik untuk memuat ulang mengambil ulang Circle dan anggota', (
      tester,
    ) async {
      final repo = adminRepo();
      await pumpCircleApp(tester, repo: repo);
      final circles = repo.circlesFetches;
      final members = repo.membersFetches;

      repo.membersByCircle['c1']!.add(
        fakeMember('user-4', 'Budi Santoso', joinedDay: 4),
      );
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repo.circlesFetches, greaterThan(circles));
      expect(repo.membersFetches, greaterThan(members));
      expect(find.text('Budi Santoso'), findsOneWidget);
    });

    testWidgets('gagal memuat Circle: pesan dan coba lagi', (tester) async {
      final repo = adminRepo()
        ..failures['myCircles'] = const CircleError(CircleErrorKind.network);
      await pumpCircleApp(tester, repo: repo);

      expect(find.text('Circle tidak bisa dimuat.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Keluarga'), findsOneWidget);
    });
  });

  group('aksesibilitas', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('skala teks $scale tanpa overflow (admin)', (tester) async {
        await pumpCircleApp(tester, repo: adminRepo(), textScale: scale);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Undang'));
        await tester.pumpAndSettle();
        expect(find.text('ABC234'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('skala teks 2.0: keadaan kosong, alert, dan pilihan', (
      tester,
    ) async {
      await pumpCircleApp(tester, repo: FakeCircleRepository(), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skala teks 2.0: dua Circle dan alert keluar', (tester) async {
      final repo = adminRepo()
        ..circles.add(kantor)
        ..membersByCircle['c2'] = [
          fakeMember('user-1', 'Rina Wati', role: CircleRole.admin),
        ];
      await pumpCircleApp(tester, repo: repo, textScale: 2.0);
      await scrollTo(tester, find.text('Keluar dari Circle'));
      await tester.tap(find.text('Keluar dari Circle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(inDialog('Keluar dari Keluarga?'), findsOneWidget);
    });

    testWidgets('label Semantics anggota, tombol, dan kode undangan', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCircleApp(tester, repo: adminRepo());

      expect(
        find.bySemanticsLabel('Rina Wati, Admin, Berbagi lokasi'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Sari Dewi, Anggota, Menjeda berbagi lokasi'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Keluarkan Raka'), findsOneWidget);
      expect(find.bySemanticsLabel('Undang'), findsOneWidget);

      await tester.tap(find.text('Undang'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Kode undangan: A B C 2 3 4'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('area sentuh tombol minimal 44 pt', (tester) async {
      await pumpCircleApp(tester, repo: adminRepo());
      await scrollTo(tester, find.text('Keluar dari Circle'));
      for (final label in ['Undang', 'Keluar dari Circle']) {
        final size = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(CupertinoButton),
              )
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
      }
      final removeSize = tester.getSize(
        find
            .ancestor(
              of: find.text('Keluarkan').first,
              matching: find.byType(CupertinoButton),
            )
            .first,
      );
      expect(removeSize.height, greaterThanOrEqualTo(44));
      expect(removeSize.width, greaterThanOrEqualTo(44));
    });
  });
}
