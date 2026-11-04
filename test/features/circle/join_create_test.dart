import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/circle/domain/circle.dart';
import 'package:tether/features/circle/domain/circle_repository.dart';

import '../../support/fake_circle_repository.dart';
import '../../support/pump_circle.dart';

Finder inSheet(String text) => find.descendant(
  of: find.byType(CupertinoActionSheet),
  matching: find.text(text),
);

final codeField = find.byType(CupertinoTextField);

Future<void> openJoin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Gabung dengan kode'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gabung dengan kode'));
  await tester.pumpAndSettle();
}

Future<void> openCreate(WidgetTester tester) async {
  await tester.tap(find.text('Buat Circle'));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester) =>
    tester.widget<CupertinoTextField>(codeField).controller!.text;

/// Repo kosong dengan satu undangan valid 'ABC234' ke Circle "Keluarga".
FakeCircleRepository joinRepo() => FakeCircleRepository()
  ..previews['ABC234'] = const InvitePreview(
    circleName: 'Keluarga',
    memberCount: 3,
  )
  ..joinTargets['ABC234'] = 'c-join'
  ..membersByCircle['c-join'] = [
    fakeMember('user-9', 'Ibu Rina', role: CircleRole.admin),
  ];

void main() {
  group('gabung', () {
    testWidgets('input dinormalkan: huruf besar, spasi dan simbol dibuang, 6', (
      tester,
    ) async {
      await pumpCircleApp(tester, repo: joinRepo());
      await openJoin(tester);

      await tester.enterText(codeField, 'a0b-c 2345z');
      await tester.pump();
      expect(fieldText(tester), 'ABC234');

      await tester.enterText(codeField, ' abc 234 ');
      await tester.pump();
      expect(fieldText(tester), 'ABC234');
    });

    testWidgets('kode belum lengkap: pesan lokal, server tidak dipanggil', (
      tester,
    ) async {
      final repo = joinRepo();
      await pumpCircleApp(tester, repo: repo);
      await openJoin(tester);

      await tester.enterText(codeField, 'ABC');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Kode terdiri dari 6 karakter.'), findsOneWidget);
      expect(repo.calls.any((c) => c.startsWith('previewInvite')), isFalse);
    });

    testWidgets('berhasil: pratinjau, konfirmasi, gabung, Circle terpilih', (
      tester,
    ) async {
      final repo = joinRepo();
      final c = await pumpCircleApp(tester, repo: repo);
      await openJoin(tester);

      await tester.enterText(codeField, 'abc 234');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('previewInvite:ABC234'));
      expect(inSheet('Gabung ke Keluarga? (3 anggota)'), findsOneWidget);
      expect(repo.calls.any((c) => c.startsWith('joinCircle')), isFalse);

      await tester.tap(inSheet('Gabung'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('joinCircle:ABC234'));
      expect(selectedCircle(c), 'c-join');
      // Kembali ke tab Circle yang kini menampilkan Circle baru.
      expect(find.text('Keluarga'), findsOneWidget);
      expect(find.text('Ibu Rina'), findsOneWidget);
      expect(find.text('Lanjut'), findsNothing);
    });

    testWidgets('batal di sheet konfirmasi: tidak gabung', (tester) async {
      final repo = joinRepo();
      await pumpCircleApp(tester, repo: repo);
      await openJoin(tester);

      await tester.enterText(codeField, 'ABC234');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Batal'));
      await tester.pumpAndSettle();

      expect(repo.calls.any((c) => c.startsWith('joinCircle')), isFalse);
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('kode salah: pesan umum, tanpa membedakan penyebab', (
      tester,
    ) async {
      final repo = joinRepo();
      await pumpCircleApp(tester, repo: repo);
      await openJoin(tester);

      await tester.enterText(codeField, 'ZZZ999');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Kode tidak valid atau kedaluwarsa'), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(repo.calls.any((c) => c.startsWith('joinCircle')), isFalse);
    });

    testWidgets('join mengembalikan NULL: pesan umum yang sama', (
      tester,
    ) async {
      final repo = joinRepo()..joinTargets.clear();
      await pumpCircleApp(tester, repo: repo);
      await openJoin(tester);

      await tester.enterText(codeField, 'ABC234');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Gabung'));
      await tester.pumpAndSettle();

      expect(find.text('Kode tidak valid atau kedaluwarsa'), findsOneWidget);
    });

    for (final (kind, text, at) in [
      (
        CircleErrorKind.tooManyAttempts,
        'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.',
        'previewInvite:ABC234',
      ),
      (
        CircleErrorKind.circleFull,
        'Circle ini sudah penuh.',
        'joinCircle:ABC234',
      ),
      (
        CircleErrorKind.circleLimit,
        'Kamu sudah mencapai batas jumlah Circle.',
        'joinCircle:ABC234',
      ),
    ]) {
      testWidgets('galat $kind ditampilkan', (tester) async {
        final repo = joinRepo()..failures[at] = CircleError(kind);
        await pumpCircleApp(tester, repo: repo);
        await openJoin(tester);

        await tester.enterText(codeField, 'ABC234');
        await tester.tap(find.text('Lanjut'));
        await tester.pumpAndSettle();
        if (at.startsWith('joinCircle')) {
          await tester.tap(inSheet('Gabung'));
          await tester.pumpAndSettle();
        }

        expect(find.text(text), findsOneWidget);
        // Tetap di halaman gabung, tombol bisa dicoba lagi.
        expect(find.text('Lanjut'), findsOneWidget);
      });
    }

    testWidgets('indikator aktivitas selama memproses', (tester) async {
      final repo = joinRepo();
      await pumpCircleApp(tester, repo: repo);
      await openJoin(tester);

      repo.gate = Completer<void>();
      await tester.enterText(codeField, 'ABC234');
      await tester.tap(find.text('Lanjut'));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('skala teks 2.0 tanpa overflow', (tester) async {
      final repo = joinRepo()
        ..failures['previewInvite:ABC234'] = const CircleError(
          CircleErrorKind.tooManyAttempts,
        );
      await pumpCircleApp(tester, repo: repo, textScale: 2.0);
      await openJoin(tester);
      await tester.enterText(codeField, 'ABC234');
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('buat Circle', () {
    testWidgets('berhasil: nama dipangkas, Circle baru terpilih dan tampil', (
      tester,
    ) async {
      final repo = FakeCircleRepository();
      final c = await pumpCircleApp(tester, repo: repo);
      await openCreate(tester);

      await tester.enterText(codeField, '  Keluarga Besar  ');
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('createCircle:Keluarga Besar'));
      expect(selectedCircle(c), 'circle-new-1');
      expect(find.text('Keluarga Besar'), findsOneWidget);
      expect(find.text('Undang'), findsOneWidget); // pembuat adalah admin
    });

    testWidgets('kosong dan lebih dari 40 karakter ditolak lokal', (
      tester,
    ) async {
      final repo = FakeCircleRepository();
      await pumpCircleApp(tester, repo: repo);
      await openCreate(tester);

      await tester.enterText(codeField, '   ');
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();
      expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);

      await tester.enterText(codeField, 'a' * 41);
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();
      expect(find.text('Nama maksimal 40 karakter.'), findsOneWidget);

      await tester.enterText(codeField, 'a' * 40);
      await tester.pump();
      expect(find.text('Nama maksimal 40 karakter.'), findsNothing);
      expect(repo.calls.any((c) => c.startsWith('createCircle')), isFalse);
    });

    testWidgets('batas Circle tercapai: pesan, tetap di form', (tester) async {
      final repo = FakeCircleRepository()
        ..failures['createCircle:Baru'] = const CircleError(
          CircleErrorKind.circleLimit,
        );
      await pumpCircleApp(tester, repo: repo);
      await openCreate(tester);

      await tester.enterText(codeField, 'Baru');
      await tester.tap(find.text('Buat'));
      await tester.pumpAndSettle();

      expect(
        find.text('Kamu sudah mencapai batas jumlah Circle.'),
        findsOneWidget,
      );
      expect(find.text('Buat'), findsOneWidget);
    });

    testWidgets('indikator aktivitas selama memproses', (tester) async {
      final repo = FakeCircleRepository();
      await pumpCircleApp(tester, repo: repo);
      await openCreate(tester);

      repo.gate = Completer<void>();
      await tester.enterText(codeField, 'Baru');
      await tester.tap(find.text('Buat'));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  });
}
