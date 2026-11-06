import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/history/presentation/history_page.dart';
import 'package:tether/features/profile/domain/profile.dart';
import 'package:tether/features/profile/presentation/delete_account_page.dart';
import 'package:tether/core/widgets/glass_dialog.dart';

import '../../support/fakes.dart';
import 'profile_harness.dart';

FakeProfileRepository withEmail() => FakeProfileRepository(
  profile: const Profile(
    id: 'user-1',
    displayName: 'Rina Wati',
    color: '#0F766E',
    email: 'rina@example.test',
  ),
);

void main() {
  testWidgets('menampilkan akun, riwayat, keluar, hapus akun, dan privasi', (
    tester,
  ) async {
    await pumpProfile(tester, profile: withEmail());

    expect(find.text('AKUN'), findsOneWidget);
    expect(find.text('rina@example.test'), findsOneWidget);
    expect(find.text('Riwayat lokasi'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Hapus akun'), findsOneWidget);
    expect(find.textContaining('dibuang tuntas dalam 30 hari'), findsOne);
  });

  testWidgets('tanpa email: bagian Akun tidak tampil', (tester) async {
    await pumpProfile(tester);
    expect(find.text('AKUN'), findsNothing);
    expect(find.text('Hapus akun'), findsOneWidget);
  });

  testWidgets('baris Riwayat lokasi membuka halaman riwayat', (tester) async {
    final h = await pumpProfile(tester, profile: withEmail());

    await tester.tap(find.text('Riwayat lokasi'));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(h.location, '/profile/history');
    expect(h.history.fetchCalls, 1);
  });

  testWidgets('baris Hapus akun membuka halaman hapus akun', (tester) async {
    final h = await pumpProfile(tester, profile: withEmail());

    await tester.ensureVisible(find.text('Hapus akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus akun'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(h.location, '/profile/delete-account');
    expect(h.account.deleteCalls, 0);
  });

  testWidgets('keluar tetap memakai konfirmasi dan kembali ke /auth', (
    tester,
  ) async {
    final h = await pumpProfile(tester, profile: withEmail());

    await tester.ensureVisible(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(GlassDialog),
        matching: find.text('Keluar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(h.auth.calls, ['signOut']);
    expect(h.location, '/auth');
  });

  testWidgets('aksesibilitas: baris pengaturan berlabel dan >= 44 pt', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpProfile(tester, profile: withEmail());

    expect(
      find.bySemanticsLabel('Riwayat lokasi, 30 hari terakhir, bisa dihapus'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Hapus akun'), findsOneWidget);
    expect(find.bySemanticsLabel('Akun rina@example.test'), findsOneWidget);
    for (final label in ['Riwayat lokasi', 'Hapus akun']) {
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(GestureDetector),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    }
    handle.dispose();
  });

  testWidgets('skala teks besar tidak menimbulkan overflow', (tester) async {
    await pumpProfile(tester, profile: withEmail(), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}
