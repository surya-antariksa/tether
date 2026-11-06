import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/activity/data/activity_providers.dart';
import 'package:tether/features/activity/presentation/activity_tab_icon.dart';
import 'package:tether/features/activity/presentation/activity_tab_page.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/circle/data/circle_providers.dart';
import 'package:tether/features/circle/domain/circle.dart';

import '../../support/fake_circle_repository.dart';
import '../../support/fakes.dart';
import 'fake_activity.dart';

class ActivityHarness {
  ActivityHarness(
    this.container,
    this.router,
    this.gateway,
    this.store,
    this.tabEnabled,
  );

  final ProviderContainer container;
  final GoRouter router;
  final FakeNotificationGateway gateway;
  final MemoryReadMarkerStore store;

  /// False meniru tab Aktivitas tersembunyi (ticker cabang tab mati).
  final ValueNotifier<bool> tabEnabled;
}

const keluarga = Circle(id: 'c1', name: 'Keluarga');
const kantor = Circle(id: 'c2', name: 'Kantor');

/// Menjalankan tab Aktivitas (rute '/activity') dengan repository palsu;
/// '/' hanya penanda tab Peta. Ikon tab dipasang di bilah bawah sederhana
/// untuk menguji lencana. Tanpa jaringan dan tanpa plugin.
Future<ActivityHarness> pumpActivityApp(
  WidgetTester tester, {
  required FakeActivityRepository repo,
  List<Circle> circles = const [keluarga],
  bool settle = true,
  double textScale = 1.0,
  DateTime? marker,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final tabEnabled = ValueNotifier<bool>(true);
  addTearDown(tabEnabled.dispose);
  final gateway = FakeNotificationGateway();
  final store = MemoryReadMarkerStore(
    marker ?? fixedNow.subtract(const Duration(hours: 1)),
  );
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.activity,
    routes: [
      GoRoute(
        path: AppRoutes.map,
        builder: (_, _) => const CupertinoPageScaffold(
          child: Center(child: Text('Halaman tab Peta')),
        ),
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (_, _) => Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: tabEnabled,
                builder: (_, enabled, _) => TickerMode(
                  enabled: enabled,
                  child: const ActivityTabPage(),
                ),
              ),
            ),
            const SizedBox(height: 48, child: Center(child: ActivityTabIcon())),
          ],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(userId: 'u1'),
      ),
      circleRepositoryProvider.overrideWithValue(
        FakeCircleRepository(selfId: 'u1', circles: circles),
      ),
      activityRepositoryProvider.overrideWithValue(repo),
      notificationGatewayProvider.overrideWithValue(gateway),
      readMarkerStoreProvider.overrideWithValue(store),
      activityClockProvider.overrideWith(FixedActivityClock.new),
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return ActivityHarness(container, router, gateway, store, tabEnabled);
}
