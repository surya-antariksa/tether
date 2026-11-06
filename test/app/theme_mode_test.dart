import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tether/app/theme/theme_mode_provider.dart';

import '../features/profile/profile_harness.dart';
import 'package:tether/features/profile/presentation/profile_tab_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fromWire: nilai tak dikenal jatuh ke sistem', () {
    expect(AppThemeMode.fromWire('dark'), AppThemeMode.dark);
    expect(AppThemeMode.fromWire('light'), AppThemeMode.light);
    expect(AppThemeMode.fromWire('aneh'), AppThemeMode.system);
    expect(AppThemeMode.fromWire(null), AppThemeMode.system);
  });

  test('tema: sistem tanpa brightness tetap, terang/gelap dikunci', () {
    expect(AppThemeMode.system.theme.brightness, isNull);
    expect(AppThemeMode.light.theme.brightness, Brightness.light);
    expect(AppThemeMode.dark.theme.brightness, Brightness.dark);
  });

  test('pilihan disimpan dan dibaca ulang', () async {
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    expect(c1.read(themeModeProvider), AppThemeMode.system);
    await c1.read(themeModeProvider.notifier).select(AppThemeMode.dark);
    expect(c1.read(themeModeProvider), AppThemeMode.dark);

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(themeModeProvider), AppThemeMode.dark);
  });

  testWidgets('Profil: pemilih tema memilih Gelap lalu Terang', (tester) async {
    await pumpProfile(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileTabPage)),
    );
    expect(container.read(themeModeProvider), AppThemeMode.system);

    await tester.ensureVisible(find.text('Gelap'));
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.dark);

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.light);
  });
}
