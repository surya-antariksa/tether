import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:tether/app/router.dart' show authRedirect;
import 'package:tether/app/routes.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/history/data/history_providers.dart';
import 'package:tether/features/history/domain/history_point.dart';
import 'package:tether/features/history/domain/history_repository.dart';
import 'package:tether/features/map/data/map_providers.dart';
import 'package:tether/features/profile/data/profile_providers.dart';
import 'package:tether/features/profile/domain/account_repository.dart';
import 'package:tether/features/profile/domain/notification_settings.dart';
import 'package:tether/features/profile/presentation/profile_tab_page.dart';
import 'package:tether/features/profile/profile_routes.dart';
import 'package:tether/features/safety/data/safety_providers.dart';
import 'package:tether/features/safety/domain/sos_queue_store.dart';

import '../../support/fakes.dart';

/// Waktu tetap tes riwayat/akun: 5 Nov 2026 12.00 waktu lokal.
final fixedNow = DateTime(2026, 11, 5, 12);

class FakeAccountRepository implements AccountRepository {
  int deleteCalls = 0;
  AccountFailure? failure;
  Completer<void>? gate;

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
  }
}

class FakeNotificationSettingsRepository
    implements NotificationSettingsRepository {
  FakeNotificationSettingsRepository({this.initial = const NotificationSettings()});

  NotificationSettings initial;
  NotificationSettingsFailure? failure;
  /// Galat khusus simpan, agar fetch tetap berhasil ketika diuji alur galat
  /// simpan (fetch dan save tidak menggunakan galat yang sama).
  NotificationSettingsFailure? saveFailure;
  List<NotificationSettings> saved = [];

  @override
  Future<NotificationSettings> fetch() async {
    if (failure != null) throw failure!;
    return initial;
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    final f = saveFailure ?? failure;
    if (f != null) throw f;
    initial = settings;
    saved.add(settings);
  }
}

class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({List<HistoryPoint>? points})
    : points = points ?? <HistoryPoint>[];

  List<HistoryPoint> points;
  HistoryFailure? fetchFailure;
  HistoryFailure? deleteFailure;
  Completer<void>? gate;
  int fetchCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<HistoryPoint>> fetchLast48h() async {
    fetchCalls++;
    if (gate != null) await gate!.future;
    if (fetchFailure != null) throw fetchFailure!;
    return List.of(points);
  }

  @override
  Future<int> deleteAll() async {
    deleteCalls++;
    if (deleteFailure != null) throw deleteFailure!;
    final n = points.length;
    points = [];
    return n;
  }
}

HistoryPoint historyPoint(
  DateTime at, {
  double lat = -6.2,
  double lng = 106.8167,
  double? accuracyM = 12,
  bool isMoving = false,
}) => HistoryPoint(
  point: LatLng(lat, lng),
  recordedAt: at,
  accuracyM: accuracyM,
  isMoving: isMoving,
);

/// Terbaru dulu: 2 titik hari ini dan 1 kemarin.
List<HistoryPoint> sampleHistory() => [
  historyPoint(DateTime(2026, 11, 5, 11, 45), isMoving: true, lat: -6.19),
  historyPoint(DateTime(2026, 11, 5, 9, 5), lat: -6.2),
  historyPoint(DateTime(2026, 11, 4, 22, 30), accuracyM: null, lat: -6.21),
];

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

/// Penyedia tile palsu: tidak pernah mengakses jaringan.
class FakeTileProvider extends TileProvider {
  int requests = 0;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    return _NeverImage();
  }
}

class ProfileHarness {
  ProfileHarness({
    required this.router,
    required this.auth,
    required this.account,
    required this.history,
    required this.tiles,
    required this.sosStore,
    required this.settings,
  });

  final GoRouter router;
  final FakeAuthRepository auth;
  final FakeAccountRepository account;
  final FakeHistoryRepository history;
  final FakeTileProvider tiles;
  final InMemorySosQueueStore sosStore;
  final FakeNotificationSettingsRepository settings;

  String get location => router.state.uri.path;
}

/// Menjalankan tab Profil (dan anak rutenya) dengan router mini beraturan
/// auth gate yang sama dengan aplikasi; '/auth' hanya penanda. Tanpa server,
/// tanpa jaringan.
Future<ProfileHarness> pumpProfile(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeProfileRepository? profile,
  FakeAccountRepository? account,
  FakeHistoryRepository? history,
  FakeNotificationSettingsRepository? settings,
  String initial = AppRoutes.profile,
  bool settle = true,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final authRepo = auth ?? FakeAuthRepository(userId: 'user-1');
  final accountRepo = account ?? FakeAccountRepository();
  final historyRepo = history ?? FakeHistoryRepository();
  final settingsRepo =
      settings ?? FakeNotificationSettingsRepository();
  final tiles = FakeTileProvider();
  final sosStore = InMemorySosQueueStore();

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      profileRepositoryProvider.overrideWithValue(
        profile ?? FakeProfileRepository(),
      ),
      accountRepositoryProvider.overrideWithValue(accountRepo),
      historyRepositoryProvider.overrideWithValue(historyRepo),
      notificationSettingsRepositoryProvider.overrideWithValue(
        settingsRepo,
      ),
      historyClockProvider.overrideWithValue(() => fixedNow),
      mapTileProviderProvider.overrideWithValue(tiles),
      sosQueueStoreProvider.overrideWith((ref) async => sosStore),
    ],
  );
  addTearDown(container.dispose);

  final refresh = ValueNotifier<int>(0);
  addTearDown(refresh.dispose);
  container.listen(currentUserIdProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initial,
    refreshListenable: refresh,
    redirect: (_, state) => authRedirect(
      signedIn: container.read(currentUserIdProvider) != null,
      path: state.uri.path,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, _) => const CupertinoPageScaffold(
          child: Center(child: Text('Halaman masuk')),
        ),
      ),
      GoRoute(
        path: AppRoutes.map,
        builder: (_, _) => const CupertinoPageScaffold(
          child: Center(child: Text('Halaman peta')),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileTabPage(),
        routes: profileRoutes,
      ),
    ],
  );
  addTearDown(router.dispose);

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
  return ProfileHarness(
    router: router,
    auth: authRepo,
    account: accountRepo,
    history: historyRepo,
    tiles: tiles,
    sosStore: sosStore,
    settings: settingsRepo,
  );
}
