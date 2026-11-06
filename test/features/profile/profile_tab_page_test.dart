import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/auth/presentation/auth_page.dart';
import 'package:tether/features/profile/domain/profile_repository.dart';
import 'package:tether/features/profile/presentation/profile_tab_page.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tether/core/widgets/glass_dialog.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

Finder inDialog(String text) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is CupertinoAlertDialog || w is GlassDialog,
  ),
  matching: find.text(text),
);

Future<void> openProfile(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeProfileRepository? profile,
  double textScale = 1.0,
}) async {
  await pumpTetherApp(
    tester,
    auth: auth ?? FakeAuthRepository(userId: 'user-1'),
    profile: profile,
    textScale: textScale,
  );
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.text('Profil'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'menampilkan avatar inisial berwarna, nama, dan tanpa koordinat',
    (tester) async {
      await openProfile(tester);

      expect(find.byType(ProfileTabPage), findsOneWidget);
      expect(find.text('RW'), findsOneWidget);
      expect(find.text('Rina Wati'), findsOneWidget);
      // Tidak ada teks mirip koordinat (mis. -6.2088 atau 106.8456).
      final coord = RegExp(r'-?\d{1,3}\.\d{3,}');
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && coord.hasMatch(w.data ?? ''),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('ubah nama: tersimpan lewat repository dan tampil', (
    tester,
  ) async {
    final profile = FakeProfileRepository();
    await openProfile(tester, profile: profile);

    await tester.tap(find.text('Ubah nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '  Ibu Rina  ');
    await tester.tap(inDialog('Simpan'));
    await tester.pumpAndSettle();

    expect(profile.updates, [
      {'displayName': 'Ibu Rina', 'color': null},
    ]);
    expect(find.text('Ibu Rina'), findsOneWidget);
    expect(find.text('IR'), findsOneWidget);
  });

  testWidgets(
    'ubah nama: kosong dan terlalu panjang ditolak, batal tidak menyimpan',
    (tester) async {
      final profile = FakeProfileRepository();
      await openProfile(tester, profile: profile);

      await tester.tap(find.text('Ubah nama'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '   ');
      await tester.tap(inDialog('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'a' * 41);
      await tester.tap(inDialog('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama maksimal 40 karakter.'), findsOneWidget);
      expect(profile.updates, isEmpty);

      await tester.tap(inDialog('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(profile.updates, isEmpty);
    },
  );

  testWidgets('pilih warna dari 8 warna: kirim hex dan tandai terpilih', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final profile = FakeProfileRepository();
    await openProfile(tester, profile: profile);

    for (final n in [
      'Teal',
      'Biru',
      'Oranye',
      'Pink',
      'Ungu',
      'Hijau',
      'Amber',
      'Abu-abu',
    ]) {
      expect(find.bySemanticsLabel('Warna $n'), findsOneWidget, reason: n);
    }
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Warna Teal'))
          .flagsCollection
          .isSelected
          .name,
      'isTrue',
    );

    await tester.tap(find.bySemanticsLabel('Warna Biru'));
    await tester.pumpAndSettle();

    expect(profile.updates, [
      {'displayName': null, 'color': '#2563EB'},
    ]);
    expect(profile.profile.color, '#2563EB');
    // Centang berpindah ke Biru (bukan hanya warna).
    expect(find.byIcon(Symbols.check), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Warna Biru'))
          .flagsCollection
          .isSelected
          .name,
      'isTrue',
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Warna Teal'))
          .flagsCollection
          .isSelected
          .name,
      isNot('isTrue'),
    );
    handle.dispose();
  });

  testWidgets('keluar: alert konfirmasi destruktif, Batal tidak keluar', (
    tester,
  ) async {
    final auth = FakeAuthRepository(userId: 'user-1');
    await openProfile(tester, auth: auth);

    await tester.ensureVisible(find.widgetWithText(CupertinoButton, 'Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassDialog), findsOneWidget);
    expect(find.text('Keluar dari Tether?'), findsOneWidget);
    final actions = tester
        .widgetList<GlassDialogAction>(find.byType(GlassDialogAction))
        .toList();
    expect(actions, hasLength(2));
    final cancel = actions.firstWhere((a) => a.label == 'Batal');
    final confirm = actions.firstWhere((a) => a.label == 'Keluar');
    expect(confirm.destructive, isTrue);
    expect(cancel.destructive, isFalse);

    await tester.tap(inDialog('Batal'));
    await tester.pumpAndSettle();
    expect(auth.calls, isNot(contains('signOut')));
    expect(find.byType(ProfileTabPage), findsOneWidget);
  });

  testWidgets(
    'keluar: konfirmasi memanggil signOut dan kembali ke halaman auth',
    (tester) async {
      final auth = FakeAuthRepository(userId: 'user-1');
      await openProfile(tester, auth: auth);

      await tester.ensureVisible(
        find.widgetWithText(CupertinoButton, 'Keluar'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoButton, 'Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Keluar'));
      await tester.pumpAndSettle();

      expect(auth.calls, contains('signOut'));
      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byType(ProfileTabPage), findsNothing);
    },
  );

  testWidgets('gagal menyimpan: alert ramah tanpa detail teknis', (
    tester,
  ) async {
    final profile = FakeProfileRepository();
    await openProfile(tester, profile: profile);
    profile.failure = const ProfileFailure(ProfileFailureKind.network);

    await tester.tap(find.bySemanticsLabel('Warna Biru'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal menyimpan'), findsOneWidget);
    expect(
      find.text('Tidak bisa terhubung. Periksa koneksi internet Anda.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    // Profil lama tetap.
    expect(find.text('Rina Wati'), findsOneWidget);
  });

  testWidgets('gagal memuat: tombol coba lagi dan tetap bisa keluar', (
    tester,
  ) async {
    final profile = FakeProfileRepository()
      ..failure = const ProfileFailure(ProfileFailureKind.network);
    await openProfile(tester, profile: profile);

    expect(find.text('Profil tidak bisa dimuat.'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    profile.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Rina Wati'), findsOneWidget);
  });

  testWidgets('Semantics: avatar, tombol ubah nama dan keluar berlabel', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openProfile(tester);

    expect(find.bySemanticsLabel('Avatar Rina Wati'), findsOneWidget);
    for (final l in ['Ubah nama', 'Keluar']) {
      final node = tester.getSemantics(find.text(l));
      expect(node.flagsCollection.isButton, isTrue, reason: l);
      expect(node.label, contains(l));
    }
    handle.dispose();
  });

  testWidgets(
    'textScaler 2.0: halaman profil, dialog ubah nama dan keluar tanpa overflow',
    (tester) async {
      await openProfile(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ubah nama'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(inDialog('Batal'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(CupertinoButton, 'Keluar'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(CupertinoButton, 'Keluar'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoButton, 'Keluar'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
