import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/auth/presentation/auth_strings.dart';
import 'package:tether/features/auth/presentation/forgot_password_sheet.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHost({
    required Future<void> Function(String email) onReset,
    double textScale = 1.0,
  }) {
    return CupertinoApp(
      theme: appTheme,
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              child: const Text('Buka Modal Lupa Sandi'),
              onPressed: () =>
                  showForgotPasswordSheet(context, onReset: onReset),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester, {
    required Future<void> Function(String email) onReset,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(buildHost(onReset: onReset, textScale: textScale));
    await tester.tap(find.text('Buka Modal Lupa Sandi'));
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan header, input email, dan tombol submit', (
    tester,
  ) async {
    await openSheet(tester, onReset: (_) async {});

    expect(find.text(AuthStrings.forgotPasswordTitle), findsOneWidget);
    expect(find.text(AuthStrings.forgotPasswordSubtitle), findsOneWidget);
    expect(find.byType(CupertinoTextFormFieldRow), findsOneWidget);
    expect(find.text(AuthStrings.sendResetLink), findsOneWidget);
    expect(find.byIcon(Symbols.shield), findsOneWidget);
  });

  testWidgets('validasi: email kosong atau salah tidak memanggil onReset', (
    tester,
  ) async {
    var called = false;
    await openSheet(tester, onReset: (_) async => called = true);

    // Tekan kirim saat input kosong
    await tester.tap(find.text(AuthStrings.sendResetLink));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(called, isFalse);

    // Masukkan email salah
    await tester.enterText(find.byType(CupertinoTextField), 'bukan-email');
    await tester.tap(find.text(AuthStrings.sendResetLink));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets(
    'sukses: mengirim email, menampilkan info sukses dan tombol tutup',
    (tester) async {
      String? submittedEmail;
      await openSheet(
        tester,
        onReset: (email) async {
          submittedEmail = email;
        },
      );

      await tester.enterText(
        find.byType(CupertinoTextField),
        'user@contoh.com',
      );
      await tester.tap(find.text(AuthStrings.sendResetLink));
      await tester.pumpAndSettle();

      expect(submittedEmail, 'user@contoh.com');
      expect(find.text(AuthStrings.resetEmailSent), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Tekan tombol Tutup menutup sheet
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordSheet), findsNothing);
    },
  );

  testWidgets('galat: menampilkan pesan ramah ketika server gagal', (
    tester,
  ) async {
    await openSheet(
      tester,
      onReset: (_) async {
        throw Exception('Network error');
      },
    );

    await tester.enterText(find.byType(CupertinoTextField), 'user@contoh.com');
    await tester.tap(find.text(AuthStrings.sendResetLink));
    await tester.pumpAndSettle();

    expect(
      find.text('Gagal mengirim tautan. Periksa koneksi internet Anda.'),
      findsOneWidget,
    );
    expect(find.byIcon(Symbols.error), findsOneWidget);
  });

  testWidgets('tombol silang (xmark) menutup modal sheet', (tester) async {
    await openSheet(tester, onReset: (_) async {});

    expect(find.byIcon(Symbols.close), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.close));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordSheet), findsNothing);
  });

  testWidgets('textScaler 2.0: modal render dengan rapi tanpa overflow', (
    tester,
  ) async {
    await openSheet(tester, onReset: (_) async {}, textScale: 2.0);

    expect(tester.takeException(), isNull);
    expect(find.text(AuthStrings.forgotPasswordTitle), findsOneWidget);
    expect(find.text(AuthStrings.sendResetLink), findsOneWidget);
  });
}
