import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/core/selected_circle.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/circle/circle_routes.dart';
import 'package:tether/features/circle/data/circle_providers.dart';
import 'package:tether/features/circle/presentation/circle_tab_page.dart';

import 'fake_circle_repository.dart';
import 'fakes.dart';

/// Menjalankan tab Circle (dan rute gabung/buat) saja dengan repository
/// palsu, tanpa tab lain. Mengembalikan container untuk memeriksa provider.
/// Layar dibuat seukuran ponsel; [textScale] untuk uji aksesibilitas.
Future<ProviderContainer> pumpCircleApp(
  WidgetTester tester, {
  required FakeCircleRepository repo,
  FakeAuthRepository? auth,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.circle,
    routes: [
      GoRoute(
        path: AppRoutes.circle,
        builder: (_, _) => const CircleTabPage(),
        routes: circleRoutes,
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        auth ?? FakeAuthRepository(userId: repo.selfId),
      ),
      circleRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: CupertinoApp.router(
        theme: appTheme,
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: const [
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String? selectedCircle(ProviderContainer c) => c.read(selectedCircleIdProvider);
