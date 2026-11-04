import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/activity/presentation/activity_tab_page.dart';
import 'package:tether/features/circle/presentation/circle_tab_page.dart';
import 'package:tether/features/map/presentation/map_tab_page.dart';
import 'package:tether/features/profile/presentation/profile_tab_page.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

Finder tabLabel(String label) => find.descendant(
  of: find.byType(CupertinoTabBar),
  matching: find.text(label),
);

void main() {
  testWidgets('tab bar punya 4 tab dengan label satu kata yang benar', (
    tester,
  ) async {
    await pumpTetherApp(tester, auth: FakeAuthRepository(userId: 'user-1'));

    final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(bar.items.map((i) => i.label), [
      'Peta',
      'Circle',
      'Aktivitas',
      'Profil',
    ]);
    for (final l in ['Peta', 'Circle', 'Aktivitas', 'Profil']) {
      expect(tabLabel(l), findsOneWidget);
    }
    // Tab awal: Peta.
    expect(find.byType(MapTabPage), findsOneWidget);
    expect(bar.currentIndex, 0);
  });

  testWidgets('mengetuk tab berpindah halaman', (tester) async {
    await pumpTetherApp(tester, auth: FakeAuthRepository(userId: 'user-1'));

    await tester.tap(tabLabel('Circle'));
    await tester.pumpAndSettle();
    expect(find.byType(CircleTabPage), findsOneWidget);

    await tester.tap(tabLabel('Aktivitas'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTabPage), findsOneWidget);

    await tester.tap(tabLabel('Profil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileTabPage), findsOneWidget);

    await tester.tap(tabLabel('Peta'));
    await tester.pumpAndSettle();
    expect(find.byType(MapTabPage), findsOneWidget);
    final bar = tester.widget<CupertinoTabBar>(find.byType(CupertinoTabBar));
    expect(bar.currentIndex, 0);
  });

  testWidgets('Semantics: tiap tab berlabel dan tab aktif ditandai terpilih', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTetherApp(tester, auth: FakeAuthRepository(userId: 'user-1'));

    for (final l in ['Peta', 'Circle', 'Aktivitas', 'Profil']) {
      expect(tester.getSemantics(tabLabel(l)).label, contains(l));
    }
    expect(
      tester.getSemantics(tabLabel('Peta')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(tabLabel('Circle')).flagsCollection.isSelected,
      isNot(Tristate.isTrue),
    );
    handle.dispose();
  });

  testWidgets('textScaler 2.0: tab bar dan halaman tab tanpa overflow', (
    tester,
  ) async {
    await pumpTetherApp(
      tester,
      auth: FakeAuthRepository(userId: 'user-1'),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    for (final l in ['Circle', 'Aktivitas', 'Profil']) {
      await tester.tap(tabLabel(l));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: l);
    }
  });
}
