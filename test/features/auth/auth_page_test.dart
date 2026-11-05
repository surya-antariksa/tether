import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/auth/domain/auth_repository.dart';
import 'package:tether/features/map/presentation/map_tab_page.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is CupertinoTextField && w.placeholder == label,
);

final emailField = field('nama@contoh.com');
final passwordField = field('Minimal 8 karakter');
final nameField = field('Nama yang dilihat keluarga');
final submitSignIn = find.widgetWithText(CupertinoButton, 'Masuk');
final submitSignUp = find.widgetWithText(CupertinoButton, 'Buat akun');

/// Teks tampilan yang memuat [s] (tidak termasuk isi kolom input).
Finder shownText(String s) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains(s));

Future<void> openSignUp(WidgetTester tester) async {
  // 'Masuk' ada di segmented control; 'Daftar' hanya di sana.
  await tester.tap(find.text('Daftar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('form kosong: validasi tampil dan server tidak dipanggil', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpTetherApp(tester, auth: auth);

    await tester.tap(submitSignIn);
    await tester.pumpAndSettle();

    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('email salah dan kata sandi pendek ditolak', (tester) async {
    final auth = FakeAuthRepository();
    await pumpTetherApp(tester, auth: auth);

    await tester.enterText(emailField, 'bukan-email');
    await tester.enterText(passwordField, '1234567');
    await tester.tap(submitSignIn);
    await tester.pumpAndSettle();

    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('masuk berhasil memindahkan ke tab Peta', (tester) async {
    final auth = FakeAuthRepository();
    await pumpTetherApp(tester, auth: auth);

    await tester.enterText(emailField, 'rina@contoh.com');
    await tester.enterText(passwordField, 'rahasia123');
    await tester.tap(submitSignIn);
    await tester.pumpAndSettle();

    expect(auth.calls, ['signIn:rina@contoh.com']);
    expect(find.byType(MapTabPage), findsOneWidget);
  });

  testWidgets('daftar meminta nama 1..40 dan mengirim display_name', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpTetherApp(tester, auth: auth);
    await openSignUp(tester);

    await tester.enterText(emailField, 'rina@contoh.com');
    await tester.enterText(passwordField, 'rahasia123');
    await tester.tap(submitSignUp);
    await tester.pumpAndSettle();
    expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.enterText(nameField, 'a' * 41);
    await tester.tap(submitSignUp);
    await tester.pumpAndSettle();
    expect(find.text('Nama maksimal 40 karakter.'), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.enterText(nameField, '  Rina Wati  ');
    await tester.tap(submitSignUp);
    await tester.pumpAndSettle();
    expect(auth.lastSignUp?['displayName'], '  Rina Wati  ');
    expect(find.byType(MapTabPage), findsOneWidget);
  });

  testWidgets('daftar yang butuh verifikasi email: tetap di auth dengan info', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..signUpOutcome = SignUpOutcome.confirmationRequired;
    await pumpTetherApp(tester, auth: auth);
    await openSignUp(tester);

    await tester.enterText(nameField, 'Rina');
    await tester.enterText(emailField, 'rina@contoh.com');
    await tester.enterText(passwordField, 'rahasia123');
    await tester.tap(submitSignUp);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Periksa kotak masuk Anda untuk verifikasi'),
      findsOneWidget,
    );
    expect(find.byType(MapTabPage), findsNothing);
    // Kembali ke mode Masuk.
    expect(nameField, findsNothing);
  });

  testWidgets('galat ramah: tanpa detail teknis dan tanpa email', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..failure = const AuthFailure(AuthFailureKind.invalidCredentials);
    await pumpTetherApp(tester, auth: auth);

    await tester.enterText(emailField, 'rina@contoh.com');
    await tester.enterText(passwordField, 'salah-sandi');
    await tester.tap(submitSignIn);
    await tester.pumpAndSettle();

    expect(find.text('Email atau kata sandi tidak cocok.'), findsOneWidget);
    expect(shownText('rina@contoh.com'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('semua jenis galat punya pesan Indonesia tanpa email', (
    tester,
  ) async {
    for (final k in AuthFailureKind.values) {
      final auth = FakeAuthRepository()..failure = AuthFailure(k);
      await pumpTetherApp(tester, auth: auth);
      await tester.enterText(emailField, 'rina@contoh.com');
      await tester.enterText(passwordField, 'rahasia123');
      await tester.tap(submitSignIn);
      await tester.pumpAndSettle();
      expect(shownText('rina@contoh.com'), findsNothing, reason: '$k');
      expect(
        find.byIcon(CupertinoIcons.exclamationmark_circle_fill),
        findsOneWidget,
        reason: '$k',
      );
      // Bongkar pohon agar tes berikutnya mulai dari nol.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('memproses: ikon aktivitas tampil dan tombol nonaktif', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final auth = FakeAuthRepository()..gate = Completer<void>();
    await pumpTetherApp(tester, auth: auth);

    await tester.enterText(emailField, 'rina@contoh.com');
    await tester.enterText(passwordField, 'rahasia123');
    await tester.tap(submitSignIn);
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    final button = tester.widget<CupertinoButton>(
      find.byType(CupertinoButton).last,
    );
    expect(button.onPressed, isNull);
    expect(find.bySemanticsLabel('Memproses'), findsOneWidget);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MapTabPage), findsOneWidget);
    handle.dispose();
  });

  testWidgets('hanya satu tombol utama (filled) di halaman auth', (
    tester,
  ) async {
    await pumpTetherApp(tester, auth: FakeAuthRepository());
    expect(find.byType(CupertinoButton), findsOneWidget);
  });

  testWidgets('Semantics: tombol utama dan kolom berlabel', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpTetherApp(tester, auth: FakeAuthRepository());

    expect(tester.getSemantics(submitSignIn).flagsCollection.isButton, isTrue);
    expect(tester.getSemantics(submitSignIn).label, 'Masuk');
    for (final (f, label) in [
      (emailField, 'Email'),
      (passwordField, 'Kata sandi'),
    ]) {
      final node = tester.getSemantics(f);
      expect(node.label, contains(label));
      expect(node.flagsCollection.isTextField, isTrue);
    }
    handle.dispose();
  });

  testWidgets(
    'textScaler 2.0: halaman auth (masuk dan daftar) tanpa overflow',
    (tester) async {
      await pumpTetherApp(tester, auth: FakeAuthRepository(), textScale: 2.0);
      expect(tester.takeException(), isNull);
      await openSignUp(tester);
      await tester.scrollUntilVisible(
        submitSignUp,
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(submitSignUp);
      await tester.pumpAndSettle();
      expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
