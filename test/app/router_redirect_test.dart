import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/app/router.dart';
import 'package:tether/features/auth/presentation/auth_page.dart';
import 'package:tether/features/location_tracking/presentation/spike_page.dart';
import 'package:tether/features/map/presentation/map_tab_page.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  group('konfirmasi sesi', () {
    test('baru masuk: tetap di /auth selama pop-up verifikasi terbuka', () {
      expect(
        authRedirect(
          signedIn: true,
          path: AppRoutes.auth,
          confirmPending: true,
        ),
        isNull,
      );
    });

    test('tanpa penanda: sudah masuk di /auth kembali ke peta', () {
      expect(authRedirect(signedIn: true, path: AppRoutes.auth), AppRoutes.map);
    });

    test('belum masuk: penanda diabaikan, tetap ke /auth', () {
      expect(
        authRedirect(signedIn: false, path: '/', confirmPending: true),
        AppRoutes.auth,
      );
    });
  });

  group('authRedirect', () {
    test('belum masuk -> /auth, kecuali sudah di /auth', () {
      expect(authRedirect(signedIn: false, path: '/'), '/auth');
      expect(authRedirect(signedIn: false, path: '/profile'), '/auth');
      expect(authRedirect(signedIn: false, path: '/auth'), isNull);
    });

    test('sudah masuk -> / dari /auth, rute lain dibiarkan', () {
      expect(authRedirect(signedIn: true, path: '/auth'), '/');
      expect(authRedirect(signedIn: true, path: '/circle'), isNull);
    });

    test('/dev/spike tidak dipaksa ke /auth (mode debug)', () {
      expect(authRedirect(signedIn: false, path: '/dev/spike'), isNull);
    });
  });

  testWidgets('belum masuk: aplikasi membuka halaman auth', (tester) async {
    await pumpTetherApp(tester, auth: FakeAuthRepository());
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(MapTabPage), findsNothing);
    expect(find.byType(CupertinoTabBar), findsNothing);
  });

  testWidgets('sesi dipulihkan: langsung ke tab Peta', (tester) async {
    await pumpTetherApp(tester, auth: FakeAuthRepository(userId: 'user-1'));
    expect(find.byType(MapTabPage), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
  });

  testWidgets('masuk memindahkan ke /, keluar memindahkan ke /auth', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpTetherApp(tester, auth: auth);
    expect(find.byType(AuthPage), findsOneWidget);

    auth.emit('user-1');
    await tester.pumpAndSettle();
    expect(find.byType(MapTabPage), findsOneWidget);

    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(MapTabPage), findsNothing);
  });

  testWidgets('/dev/spike dapat dibuka di mode debug tanpa masuk', (
    tester,
  ) async {
    await pumpTetherApp(tester, auth: FakeAuthRepository());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AuthPage)),
    );
    container.read(routerProvider).go(AppRoutes.devSpike);
    await tester.pumpAndSettle();
    expect(find.byType(SpikePage), findsOneWidget);
  });
}
