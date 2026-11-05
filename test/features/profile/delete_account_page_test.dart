import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/auth/domain/auth_repository.dart';
import 'package:tether/features/profile/domain/account_repository.dart';
import 'package:tether/features/profile/domain/profile.dart';
import 'package:tether/features/profile/presentation/delete_account_page.dart';
import 'package:tether/features/safety/domain/sos_models.dart';

import '../../support/fakes.dart';
import 'profile_harness.dart';

Finder inDialog(String text) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(text),
);

Future<ProfileHarness> openDelete(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeAccountRepository? account,
  double textScale = 1.0,
}) => pumpProfile(
  tester,
  auth: auth,
  account: account,
  initial: '/profile/delete-account',
  textScale: textScale,
);

/// Tombol berada di bawah lipatan layar: gulir dulu.
Future<void> tapStart(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Hapus akun saya'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hapus akun saya'));
  await tester.pumpAndSettle();
}

/// Menjalankan dua dialog konfirmasi sampai tombol akhir ditekan.
Future<void> confirmBoth(WidgetTester tester) async {
  await tapStart(tester);
  await tester.tap(inDialog('Lanjutkan'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(CupertinoTextField), 'HAPUS');
  await tester.pumpAndSettle();
  await tester.tap(inDialog('Hapus akun'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menampilkan penjelasan data yang dihapus dan masa 30 hari', (
    tester,
  ) async {
    await openDelete(tester);

    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(find.textContaining('Riwayat lokasi dan posisi terakhir'), findsOne);
    expect(find.textContaining('Keanggotaan di semua Circle'), findsOneWidget);
    expect(find.textContaining('tuntas dalam 30 hari'), findsOneWidget);
  });

  testWidgets('konfirmasi pertama dibatalkan: tidak ada yang dipanggil', (
    tester,
  ) async {
    final h = await openDelete(tester);

    await tapStart(tester);
    await tester.pumpAndSettle();
    expect(inDialog('Hapus akun?'), findsOneWidget);
    await tester.tap(inDialog('Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoTextField), findsNothing);
    expect(h.account.deleteCalls, 0);
  });

  testWidgets('konfirmasi kedua: tombol mati sampai HAPUS diketik', (
    tester,
  ) async {
    final h = await openDelete(tester);

    await tapStart(tester);
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(inDialog('Konfirmasi terakhir'), findsOneWidget);

    CupertinoDialogAction action() => tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Hapus akun'),
    );
    expect(action().onPressed, isNull);

    await tester.enterText(find.byType(CupertinoTextField), 'HAPU');
    await tester.pumpAndSettle();
    expect(action().onPressed, isNull);
    await tester.tap(inDialog('Hapus akun'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(h.account.deleteCalls, 0);

    await tester.enterText(find.byType(CupertinoTextField), 'hapus');
    await tester.pumpAndSettle();
    expect(action().onPressed, isNotNull);
  });

  testWidgets('batal di konfirmasi kedua tidak menghapus', (tester) async {
    final h = await openDelete(tester);

    await tapStart(tester);
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Lanjutkan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'HAPUS');
    await tester.tap(inDialog('Batal'));
    await tester.pumpAndSettle();

    expect(h.account.deleteCalls, 0);
    expect(find.byType(DeleteAccountPage), findsOneWidget);
  });

  testWidgets('sukses: RPC dipanggil, keluar, kembali ke /auth', (
    tester,
  ) async {
    final h = await openDelete(tester);

    await confirmBoth(tester);

    expect(h.account.deleteCalls, 1);
    expect(h.auth.calls, contains('signOut'));
    expect(h.auth.currentUserId, isNull);
    expect(h.location, '/auth');
    expect(find.text('Halaman masuk'), findsOneWidget);
  });

  testWidgets('sukses: SOS tertunda milik akun yang dihapus dibersihkan, '
      'milik akun lain tetap', (tester) async {
    final h = await openDelete(tester);
    PendingSos pending(String id, String user) => PendingSos(
      clientId: id,
      userId: user,
      triggeredAt: DateTime.utc(2026, 11, 5, 10),
      fix: const SosFix(lat: -6.2, lng: 106.8),
    );
    await h.sosStore.add(pending('a', 'user-1'));
    await h.sosStore.add(pending('b', 'orang-lain'));

    await confirmBoth(tester);

    expect(h.account.deleteCalls, 1);
    expect((await h.sosStore.load()).map((s) => s.clientId), ['b']);
  });

  testWidgets('gagal hapus akun: antrean SOS tidak disentuh', (tester) async {
    final account = FakeAccountRepository()
      ..failure = const AccountFailure(AccountFailureKind.network);
    final h = await openDelete(tester, account: account);
    await h.sosStore.add(
      PendingSos(
        clientId: 'a',
        userId: 'user-1',
        triggeredAt: DateTime.utc(2026, 11, 5, 10),
        fix: const SosFix(lat: -6.2, lng: 106.8),
      ),
    );

    await confirmBoth(tester);

    expect(await h.sosStore.load(), hasLength(1));
  });

  testWidgets('sedang memproses: tombol mati dan indikator tampil', (
    tester,
  ) async {
    final gate = Completer<void>();
    final account = FakeAccountRepository()..gate = gate;
    final h = await openDelete(tester, account: account);

    await tapStart(tester);
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Lanjutkan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'HAPUS');
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Hapus akun'));
    // Lewati animasi tutup dialog; RPC masih tertahan di gate.
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: find.byType(DeleteAccountPage),
        matching: find.byType(CupertinoActivityIndicator, skipOffstage: false),
      ),
      findsOneWidget,
    );
    final button = tester
        .widgetList<CupertinoButton>(
          find.byType(CupertinoButton, skipOffstage: false),
        )
        .singleWhere((b) => b.child is CupertinoActivityIndicator);
    expect(button.onPressed, isNull);
    expect(h.auth.calls, isNot(contains('signOut')));

    gate.complete();
    await tester.pumpAndSettle();
    expect(h.location, '/auth');
  });

  for (final c in {
    AccountFailureKind.network:
        'Tidak bisa terhubung. Periksa koneksi internet Anda lalu coba lagi.',
    AccountFailureKind.unauthorized:
        'Sesi Anda berakhir. Masuk lagi lalu coba hapus akun.',
    AccountFailureKind.notFound: 'Akun tidak ditemukan.',
    AccountFailureKind.unknown: 'Terjadi masalah. Coba lagi nanti.',
  }.entries) {
    testWidgets('galat ${c.key.name}: pesan tampil, tetap masuk, bisa ulang', (
      tester,
    ) async {
      final account = FakeAccountRepository()..failure = AccountFailure(c.key);
      final h = await openDelete(tester, account: account);

      await confirmBoth(tester);

      expect(inDialog('Gagal menghapus akun'), findsOneWidget);
      expect(inDialog(c.value), findsOneWidget);
      expect(h.auth.calls, isNot(contains('signOut')));
      expect(h.auth.currentUserId, 'user-1');

      await tester.tap(inDialog('Tutup'));
      await tester.pumpAndSettle();
      expect(h.location, '/profile/delete-account');
      final button = tester.widget<CupertinoButton>(
        find.widgetWithText(CupertinoButton, 'Hapus akun saya'),
      );
      expect(button.onPressed, isNotNull);
    });
  }

  testWidgets('akun terhapus tetapi keluar gagal: pesan khusus', (
    tester,
  ) async {
    final auth = FakeAuthRepository(userId: 'user-1')
      ..failure = const AuthFailure(AuthFailureKind.network);
    final h = await openDelete(tester, auth: auth);

    await confirmBoth(tester);

    expect(h.account.deleteCalls, 1);
    expect(inDialog('Gagal menghapus akun'), findsOneWidget);
    expect(find.textContaining('Akun sudah dihapus'), findsOneWidget);
    expect(h.location, '/profile/delete-account');
  });

  testWidgets('aksesibilitas: label, aksi ketuk, area sentuh 44 pt', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openDelete(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Hapus akun saya')),
      matchesSemantics(
        label: 'Hapus akun saya',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester
          .getSize(find.widgetWithText(CupertinoButton, 'Hapus akun saya'))
          .height,
      greaterThanOrEqualTo(44),
    );

    await tapStart(tester);
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Ketik HAPUS untuk konfirmasi')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('skala teks besar tidak menimbulkan overflow', (tester) async {
    await openDelete(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.text('Hapus akun saya'), findsOneWidget);
  });

  test('Profile.copyWith mempertahankan email', () {
    const p = Profile(
      id: 'u',
      displayName: 'A',
      color: '#0F766E',
      email: 'a@example.test',
    );
    expect(p.copyWith(displayName: 'B').email, 'a@example.test');
  });
}
