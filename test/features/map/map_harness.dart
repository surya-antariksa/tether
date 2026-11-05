import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/map/data/map_providers.dart';
import 'package:tether/features/map/map_routes.dart';
import 'package:tether/features/map/presentation/map_tab_page.dart';
import 'package:tether/features/places/data/place_providers.dart';
import 'package:tether/features/places/domain/place_repository.dart';
import 'package:tether/features/tracking/data/tracking_service.dart';
import 'package:tether/features/tracking/domain/tracking_status.dart';

import '../../support/fakes.dart';
import '../places/fake_place_repository.dart';
import 'fake_map_repository.dart';

/// Jam tetap semua tes peta.
final fixedNow = DateTime.utc(2026, 11, 5, 12);

/// Jam peta yang tidak berdetak; [advance] memajukan waktu secara manual.
class FixedMapClock extends MapClock {
  FixedMapClock(this._now);

  final DateTime _now;

  @override
  DateTime build() => _now;

  void advance(Duration d) => state = state.add(d);
}

/// Layanan pelacakan palsu agar overlay peta tidak menyentuh izin, GPS, atau
/// SQLite.
class FakeTrackingService extends TrackingService {
  @override
  TrackingSnapshot build() =>
      const TrackingSnapshot(status: TrackingStatus.running);
}

/// Gambar yang tidak pernah selesai dimuat: tidak ada jaringan, tidak ada
/// decode.
class _NeverImage extends ImageProvider<_NeverImage> {
  @override
  Future<_NeverImage> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(
    _NeverImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

/// Penyedia tile palsu: mencatat permintaan, tidak pernah mengakses jaringan.
class FakeTileProvider extends TileProvider {
  int requests = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    return _NeverImage();
  }
}

class MapHarness {
  MapHarness(this.container, this.router, this.tiles);

  final ProviderContainer container;
  final GoRouter router;
  final FakeTileProvider tiles;

  FixedMapClock get clock =>
      container.read(mapClockProvider.notifier) as FixedMapClock;
}

/// Menjalankan tab Peta saja (rute '/') dengan repository palsu; '/circle'
/// hanya penanda. Layar seukuran ponsel. Tidak memanggil pumpAndSettle bila
/// [settle] false (untuk keadaan memuat, indikator berputar tanpa henti).
Future<MapHarness> pumpMapApp(
  WidgetTester tester, {
  required FakeMapRepository repo,
  PlaceRepository? placeRepo,
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
        builder: (_, _) => const MapTabPage(),
        routes: mapRoutes,
      ),
      GoRoute(
        path: AppRoutes.circle,
        builder: (_, _) => const CupertinoPageScaffold(
          child: Center(child: Text('Halaman tab Circle')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(userId: repo.selfId),
      ),
      mapRepositoryProvider.overrideWithValue(repo),
      placeRepositoryProvider.overrideWithValue(
        placeRepo ?? FakePlaceRepository(),
      ),
      mapTileProviderProvider.overrideWithValue(tiles),
      mapClockProvider.overrideWith(() => FixedMapClock(fixedNow)),
      trackingServiceProvider.overrideWith(FakeTrackingService.new),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(repo.dispose);

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
  return MapHarness(container, router, tiles);
}
