import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/theme/app_colors.dart';
import 'package:tether/app/theme/app_text_styles.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/core/contrast.dart';

/// Appearance tampilan sistem yang diuji.
enum Appearance {
  light(false, false),
  dark(true, false),
  lightHighContrast(false, true),
  darkHighContrast(true, true);

  const Appearance(this.isDark, this.isHighContrast);
  final bool isDark;
  final bool isHighContrast;
}

/// Memilih varian warna dinamis tanpa widget (sama dengan resolve di app).
Color pick(CupertinoDynamicColor c, Appearance m) =>
    switch ((m.isDark, m.isHighContrast)) {
      (false, false) => c.color,
      (true, false) => c.darkColor,
      (false, true) => c.highContrastColor,
      (true, true) => c.darkHighContrastColor,
    };

double ratio(
  CupertinoDynamicColor fg,
  CupertinoDynamicColor bg,
  Appearance m,
) => contrastRatio(pick(fg, m), pick(bg, m));

void main() {
  const textBackgrounds = {
    'background': AppColors.background,
    'groupedBackground': AppColors.groupedBackground,
    'groupedItemBackground': AppColors.groupedItemBackground,
  };

  group('kontras WCAG >= 4,5:1', () {
    for (final m in Appearance.values) {
      group(m.name, () {
        test('label di semua latar', () {
          for (final e in textBackgrounds.entries) {
            expect(
              ratio(AppColors.textPrimary, e.value, m),
              greaterThanOrEqualTo(4.5),
              reason: 'label di ${e.key}',
            );
          }
        });

        test('tint sebagai teks/ikon di latar polos dan kartu', () {
          for (final e in textBackgrounds.entries) {
            expect(
              ratio(AppColors.tint, e.value, m),
              greaterThanOrEqualTo(4.5),
              reason: 'tint di ${e.key}',
            );
          }
        });

        test('teks di atas tint, success, dan warning (onX di atas X)', () {
          expect(
            ratio(AppColors.onTint, AppColors.tint, m),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            ratio(AppColors.onSuccess, AppColors.success, m),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            ratio(AppColors.onWarning, AppColors.warning, m),
            greaterThanOrEqualTo(4.5),
          );
        });

        test('success dan warning sebagai teks di latar polos dan kartu', () {
          for (final key in ['background', 'groupedItemBackground']) {
            final bg = textBackgrounds[key]!;
            expect(
              ratio(AppColors.success, bg, m),
              greaterThanOrEqualTo(4.5),
              reason: 'success di $key',
            );
            expect(
              ratio(AppColors.warning, bg, m),
              greaterThanOrEqualTo(4.5),
              reason: 'warning di $key',
            );
          }
        });
      });
    }
  });

  test('putih di atas tint dan success: lulus di mode terang', () {
    const white = Color(0xFFFFFFFF);
    for (final m in [Appearance.light, Appearance.lightHighContrast]) {
      expect(
        contrastRatio(white, pick(AppColors.tint, m)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(white, pick(AppColors.success, m)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('kontras tinggi terang mencapai >= 7:1 untuk tint di latar putih', () {
    expect(
      ratio(AppColors.tint, AppColors.background, Appearance.lightHighContrast),
      greaterThanOrEqualTo(7),
    );
    expect(
      ratio(AppColors.tint, AppColors.background, Appearance.darkHighContrast),
      greaterThanOrEqualTo(7),
    );
  });

  // Pasangan yang TIDAK memenuhi 4,5:1. Dicatat agar perubahan tidak diam-diam
  // memburuk. Lihat laporan: ini nilai sistem Apple atau akibat warna yang
  // ditetapkan, bukan token merek.
  group('pengecualian terdokumentasi (lantai 3:1)', () {
    test(
      'putih di atas tint gelap (cyan) gagal, maka onTint gelap = #00373A',
      () {
        const white = Color(0xFFFFFFFF);
        expect(
          contrastRatio(white, pick(AppColors.tint, Appearance.dark)),
          lessThan(4.5),
        );
        expect(
          pick(AppColors.onTint, Appearance.dark),
          const Color(0xFF00373A),
        );
        expect(
          ratio(AppColors.onTint, AppColors.tint, Appearance.dark),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('secondaryLabel (sistem) di latar polos', () {
      for (final m in Appearance.values) {
        final r = ratio(AppColors.textSecondary, AppColors.background, m);
        expect(r, greaterThanOrEqualTo(3.0), reason: '${m.name}: $r');
      }
    });

    test('danger (systemRed) sebagai teks di latar polos', () {
      for (final m in Appearance.values) {
        final r = ratio(AppColors.danger, AppColors.background, m);
        expect(r, greaterThanOrEqualTo(3.0), reason: '${m.name}: $r');
      }
    });

    test('success dan warning terang di systemGroupedBackground', () {
      // Selisih sangat tipis di bawah 4,5 (sekitar 4,49 dan 4,50).
      for (final c in [AppColors.success, AppColors.warning]) {
        final r = ratio(c, AppColors.groupedBackground, Appearance.light);
        expect(r, greaterThanOrEqualTo(4.4), reason: '$r');
      }
    });
  });

  testWidgets('tint mengikuti brightness dan kontras sistem', (tester) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    late BuildContext ctx;
    Future<Color> resolved() async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: appTheme,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      return Color(CupertinoTheme.of(ctx).primaryColor.toARGB32());
    }

    expect(await resolved(), const Color(0xFF00696F));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    expect(await resolved(), const Color(0xFF00F2FE));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(highContrast: true);
    expect(await resolved(), const Color(0xFF6FF6FF));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    expect(await resolved(), const Color(0xFF004F53));
  });

  testWidgets('gaya teks sesuai tabel iOS dan mengikuti textScaler', (
    tester,
  ) async {
    late TextStyle largeTitle;
    late TextStyle caption2;
    late TextStyle body;
    late TextStyle bodyBold;
    late TextStyle headline;
    await tester.pumpWidget(
      CupertinoApp(
        theme: appTheme,
        home: Builder(
          builder: (c) {
            largeTitle = AppTextStyles.largeTitle(c);
            caption2 = AppTextStyles.caption2(c, emphasized: true);
            body = AppTextStyles.body(c);
            bodyBold = AppTextStyles.body(c, emphasized: true);
            headline = AppTextStyles.headline(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(largeTitle.fontSize, 28);
    expect(largeTitle.height! * largeTitle.fontSize!, closeTo(34, 0.001));
    expect(largeTitle.fontWeight, FontWeight.w700);
    expect(largeTitle.fontFamily, 'PlusJakartaSans');
    expect(caption2.fontSize, 10);
    expect(caption2.height! * 10, closeTo(12, 0.001));
    expect(caption2.fontWeight, FontWeight.w700);
    expect(caption2.fontFamily, 'Inter');
    expect(body.fontSize, 16);
    expect(body.height! * 16, closeTo(24, 0.001));
    expect(bodyBold.fontWeight, FontWeight.w600);
    expect(headline.fontWeight, FontWeight.w600);
  });

  testWidgets('skala teks sistem tidak di-clamp oleh aplikasi', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    late TextScaler scaler;
    await tester.pumpWidget(
      CupertinoApp(
        theme: appTheme,
        home: Builder(
          builder: (c) {
            scaler = MediaQuery.textScalerOf(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(scaler.scale(10), 20);
  });
}
