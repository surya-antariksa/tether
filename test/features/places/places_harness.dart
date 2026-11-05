import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/map/data/map_providers.dart';
import 'package:tether/features/places/data/place_providers.dart';
import 'package:tether/features/places/places_routes.dart';

import '../../support/fakes.dart';
import '../map/fake_map_repository.dart';
import '../map/map_harness.dart' show FakeTileProvider, FixedMapClock, fixedNow;
import 'fake_place_repository.dart';

class PlacesHarness {
  PlacesHarness(this.container, this.router, this.tiles);

  final ProviderContainer container;
  final GoRouter router;
  final FakeTileProvider tiles;
}

/// Menjalankan rute tempat saja (di atas halaman penanda '/'), tanpa jaringan
/// dan tanpa plugin. [open] menentukan rute awal yang didorong. Layar ponsel.
Future<PlacesHarness> pumpPlaces(
  WidgetTester tester, {
  required FakePlaceRepository repo,
  FakeMapRepository? mapRepo,
  String circleId = 'c1',
  String? open,
  bool settle = true,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final tiles = FakeTileProvider();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.map,
    routes: [
      GoRoute(
        path: AppRoutes.map,
        builder: (_, _) => const CupertinoPageScaffold(
          child: Center(child: Text('Halaman peta')),
        ),
        routes: placesRoutes,
      ),
    ],
  );
  addTearDown(router.dispose);

  final mapRepository = mapRepo ?? FakeMapRepository(selfId: repo.selfId);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(userId: repo.selfId),
      ),
      placeRepositoryProvider.overrideWithValue(repo),
      mapRepositoryProvider.overrideWithValue(mapRepository),
      mapTileProviderProvider.overrideWithValue(tiles),
      mapClockProvider.overrideWith(() => FixedMapClock(fixedNow)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(mapRepository.dispose);

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
  await tester.pump();
  router.push(open ?? PlacesRoutes.list(circleId));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return PlacesHarness(container, router, tiles);
}
