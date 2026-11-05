import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/features/tracking/data/tracking_providers.dart';
import 'package:tether/features/tracking/domain/permission_gateway.dart';
import 'package:tether/features/tracking/presentation/location_onboarding_page.dart';
import 'package:tether/features/tracking/presentation/tracking_strings.dart';
import 'package:tether/features/tracking/tracking_routes.dart';

import 'tracking_fakes.dart';

const _inUse = TrackingPermission.locationWhenInUse;
const _always = TrackingPermission.locationAlways;
const _notif = TrackingPermission.notification;

const _granted = AppPermissionStatus.granted;
const _denied = AppPermissionStatus.denied;
const _permanent = AppPermissionStatus.permanentlyDenied;

late FakePermissionGateway _gateway;
late ProviderContainer _container;

/// Memasang halaman langsung (tanpa GoRouter).
Future<void> _pumpPage(WidgetTester tester, {double textScale = 1}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  _container = ProviderContainer(
    overrides: [permissionGatewayProvider.overrideWithValue(_gateway)],
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: const CupertinoApp(home: LocationOnboardingPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Memasang halaman lewat GoRouter dengan rute tracking asli.
Future<GoRouter> _pumpRouted(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  _container = ProviderContainer(
    overrides: [permissionGatewayProvider.overrideWithValue(_gateway)],
  );
  addTearDown(_container.dispose);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.map,
        builder: (_, _) => const CupertinoPageScaffold(child: Text('PETA')),
      ),
      ...trackingRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: CupertinoApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

bool _canPop(WidgetTester tester) =>
    tester.widget<PopScope>(find.byType(PopScope)).canPop;

void main() {
  setUp(() => _gateway = FakePermissionGateway());

  group('langkah awal mengikuti izin yang sudah ada', () {
    testWidgets('belum ada izin: mulai dari lokasi saat dipakai', (t) async {
      await _pumpPage(t);
      expect(find.text(TrackingStrings.whenInUseTitle), findsOneWidget);
      expect(find.text(TrackingStrings.reasonWhenInUse), findsOneWidget);
      for (final p in TrackingStrings.whenInUsePoints) {
        expect(find.text(p), findsOneWidget);
      }
    });

    testWidgets('sempat menampilkan indikator saat status dibaca', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      _container = ProviderContainer(
        overrides: [permissionGatewayProvider.overrideWithValue(_gateway)],
      );
      addTearDown(_container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: _container,
          child: const CupertinoApp(home: LocationOnboardingPage()),
        ),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text(TrackingStrings.next), findsNothing);
      await t.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('foreground sudah diberikan: lompat ke lokasi selalu', (
      t,
    ) async {
      _gateway.statuses[_inUse] = _granted;
      await _pumpPage(t);
      expect(find.text(TrackingStrings.alwaysTitle), findsOneWidget);
      expect(find.text(TrackingStrings.reasonAlways), findsOneWidget);
      expect(find.text(TrackingStrings.alwaysHint), findsOneWidget);
    });

    testWidgets('background sudah diberikan: lompat ke notifikasi', (t) async {
      _gateway.statuses[_inUse] = _granted;
      _gateway.statuses[_always] = _granted;
      await _pumpPage(t);
      expect(find.text(TrackingStrings.notificationTitle), findsOneWidget);
      expect(find.text(TrackingStrings.reasonNotification), findsOneWidget);
    });

    testWidgets('semua izin diberikan: langsung panduan baterai', (t) async {
      _gateway.statuses.addAll({
        _inUse: _granted,
        _always: _granted,
        _notif: _granted,
      });
      await _pumpPage(t);
      expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);
    });

    testWidgets(
      'lokasi ditolak permanen di awal: tetap mulai dari langkah pertama',
      (t) async {
        _gateway.statuses[_inUse] = _permanent;
        await _pumpPage(t);
        expect(find.text(TrackingStrings.whenInUseTitle), findsOneWidget);
      },
    );

    testWidgets('status gagal dibaca: dianggap ditolak, mulai dari awal', (
      t,
    ) async {
      _gateway.throwOnStatus = true;
      await _pumpPage(t);
      expect(find.text(TrackingStrings.whenInUseTitle), findsOneWidget);
    });
  });

  group('layar penjelasan', () {
    testWidgets('satu tombol Lanjut, tanpa pengaturan, tanpa jalan keluar', (
      t,
    ) async {
      for (final setup in <Map<TrackingPermission, AppPermissionStatus>>[
        {},
        {_inUse: _granted},
        {_inUse: _granted, _always: _granted},
      ]) {
        _gateway = FakePermissionGateway(statuses: setup);
        await _pumpPage(t);
        expect(find.text(TrackingStrings.next), findsOneWidget);
        expect(find.text(TrackingStrings.openSettings), findsNothing);
        expect(find.text(TrackingStrings.done), findsNothing);
        expect(find.byType(CupertinoButton), findsOneWidget);
        expect(_canPop(t), isFalse);
      }
    });
  });

  group('lokasi saat dipakai (foreground)', () {
    testWidgets('diberikan: meminta izin, menyegarkan provider, lanjut', (
      t,
    ) async {
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);

      expect(_gateway.requestCalls, [_inUse]);
      expect(_container.read(locationPermissionProvider), _granted);
      expect(find.text(TrackingStrings.alwaysTitle), findsOneWidget);
    });

    testWidgets('ditolak: layar lokasi belum diizinkan dengan jalan keluar', (
      t,
    ) async {
      _gateway.requestResults[_inUse] = _denied;
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);

      expect(find.text(TrackingStrings.locationDeniedTitle), findsOneWidget);
      expect(find.text(TrackingStrings.locationDeniedBody), findsOneWidget);
      expect(find.text(TrackingStrings.done), findsOneWidget);
      expect(find.text(TrackingStrings.openSettings), findsOneWidget);
      expect(_container.read(locationPermissionProvider), _denied);
      expect(_canPop(t), isTrue);
    });

    testWidgets('ditolak permanen: layar yang sama, status provider permanen', (
      t,
    ) async {
      _gateway.requestResults[_inUse] = _permanent;
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);

      expect(find.text(TrackingStrings.locationDeniedTitle), findsOneWidget);
      expect(_container.read(locationPermissionProvider), _permanent);
    });

    testWidgets('request melempar: dianggap ditolak', (t) async {
      _gateway.throwOnRequest = true;
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      expect(find.text(TrackingStrings.locationDeniedTitle), findsOneWidget);
    });

    testWidgets('tombol pengaturan membuka pengaturan aplikasi', (t) async {
      _gateway.requestResults[_inUse] = _permanent;
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      await _tap(t, TrackingStrings.openSettings);
      expect(_gateway.openSettingsCalls, 1);
      expect(find.text(TrackingStrings.locationDeniedTitle), findsOneWidget);
    });

    testWidgets('openSettings melempar: layar tetap, tanpa galat', (t) async {
      _gateway.requestResults[_inUse] = _denied;
      _gateway.throwOnOpenSettings = true;
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      await _tap(t, TrackingStrings.openSettings);
      expect(t.takeException(), isNull);
      expect(find.text(TrackingStrings.locationDeniedTitle), findsOneWidget);
    });

    testWidgets(
      'selagi memproses: indikator tampil dan ketukan kedua diabaikan',
      (t) async {
        _gateway.requestGate = Completer<void>();
        await _pumpPage(t);

        await t.tap(find.text(TrackingStrings.next));
        await t.pump();
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        await t.tap(find.text(TrackingStrings.next), warnIfMissed: false);
        await t.pump();
        expect(_gateway.requestCalls, hasLength(1));

        _gateway.requestGate!.complete();
        await t.pumpAndSettle();
        expect(find.text(TrackingStrings.alwaysTitle), findsOneWidget);
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
      },
    );
  });

  group('lokasi selalu (background)', () {
    setUp(() => _gateway = FakePermissionGateway(statuses: {_inUse: _granted}));

    testWidgets('diberikan: lanjut ke notifikasi', (t) async {
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      expect(_gateway.requestCalls, [_always]);
      expect(find.text(TrackingStrings.notificationTitle), findsOneWidget);
    });

    for (final denial in [_denied, _permanent]) {
      testWidgets('$denial: mode terbatas, Lanjut menuju notifikasi', (
        t,
      ) async {
        _gateway.requestResults[_always] = denial;
        await _pumpPage(t);
        await _tap(t, TrackingStrings.next);

        expect(find.text(TrackingStrings.alwaysDeniedTitle), findsOneWidget);
        expect(find.text(TrackingStrings.alwaysDeniedBody), findsOneWidget);
        expect(find.text(TrackingStrings.openSettings), findsOneWidget);
        expect(_canPop(t), isTrue);
        // Penolakan background tidak mencabut izin foreground.
        await _container.read(locationPermissionProvider.notifier).refresh();
        expect(_container.read(locationPermissionProvider), _granted);

        await _tap(t, TrackingStrings.next);
        expect(find.text(TrackingStrings.notificationTitle), findsOneWidget);
      });
    }

    testWidgets('mode terbatas: tombol pengaturan membuka pengaturan', (
      t,
    ) async {
      _gateway.requestResults[_always] = _denied;
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      await _tap(t, TrackingStrings.openSettings);
      expect(_gateway.openSettingsCalls, 1);
    });
  });

  group('notifikasi', () {
    setUp(() {
      _gateway = FakePermissionGateway(
        statuses: {_inUse: _granted, _always: _granted},
      );
    });

    testWidgets('diberikan: lanjut ke panduan baterai', (t) async {
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      expect(_gateway.requestCalls, [_notif]);
      expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);
    });

    for (final denial in [_denied, _permanent]) {
      testWidgets('$denial: pemberitahuan dimatikan, Lanjut menuju baterai', (
        t,
      ) async {
        _gateway.requestResults[_notif] = denial;
        await _pumpPage(t);
        await _tap(t, TrackingStrings.next);

        expect(
          find.text(TrackingStrings.notificationDeniedTitle),
          findsOneWidget,
        );
        expect(
          find.text(TrackingStrings.notificationDeniedBody),
          findsOneWidget,
        );
        expect(find.text(TrackingStrings.openSettings), findsOneWidget);

        await _tap(t, TrackingStrings.next);
        expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);
      });
    }
  });

  group('panduan baterai (hemat baterai)', () {
    setUp(() {
      _gateway = FakePermissionGateway(
        statuses: {_inUse: _granted, _always: _granted, _notif: _granted},
      );
    });

    testWidgets('memuat intro, semua merek, catatan, Selesai dan pengaturan', (
      t,
    ) async {
      await _pumpPage(t);
      expect(find.text(TrackingStrings.batteryIntro), findsOneWidget);
      for (final g in TrackingStrings.batteryBrands) {
        expect(find.text(g.brand), findsOneWidget);
        expect(find.text(g.steps), findsOneWidget);
      }
      expect(find.text(TrackingStrings.batteryFootnote), findsOneWidget);
      expect(find.text(TrackingStrings.done), findsOneWidget);
      expect(find.text(TrackingStrings.openSettings), findsOneWidget);
      expect(_canPop(t), isTrue);
    });

    testWidgets('pengaturan membuka pengaturan aplikasi', (t) async {
      await _pumpPage(t);
      await _tap(t, TrackingStrings.openSettings);
      expect(_gateway.openSettingsCalls, 1);
    });

    testWidgets('skala teks 200 persen tidak overflow', (t) async {
      await _pumpPage(t, textScale: 2);
      expect(t.takeException(), isNull);
      expect(find.text(TrackingStrings.done), findsOneWidget);
    });

    testWidgets('judul langkah ditandai sebagai header semantik', (t) async {
      final handle = t.ensureSemantics();
      await _pumpPage(t);
      expect(
        t.getSemantics(find.text(TrackingStrings.batteryTitle)),
        matchesSemantics(label: TrackingStrings.batteryTitle, isHeader: true),
      );
      handle.dispose();
    });
  });

  group('alur penuh', () {
    testWidgets('semua diberikan dari awal sampai baterai', (t) async {
      await _pumpPage(t);
      await _tap(t, TrackingStrings.next);
      await _tap(t, TrackingStrings.next);
      await _tap(t, TrackingStrings.next);
      expect(_gateway.requestCalls, [_inUse, _always, _notif]);
      expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);
    });

    testWidgets(
      'foreground ditolak: berhenti di layar penolakan, izin lain tidak diminta',
      (t) async {
        _gateway.requestResults.addAll({
          _inUse: _denied,
          _always: _denied,
          _notif: _denied,
        });
        await _pumpPage(t);
        await _tap(t, TrackingStrings.next);
        // Foreground ditolak berhenti di layar penolakan, bukan lanjut.
        expect(find.text(TrackingStrings.locationDeniedTitle), findsOneWidget);
        expect(_gateway.requestCalls, [_inUse]);
      },
    );
  });

  group('selesai dan navigasi', () {
    testWidgets(
      'dibuka dari peta (bisa pop): Selesai kembali ke halaman asal',
      (t) async {
        _gateway.statuses.addAll({
          _inUse: _granted,
          _always: _granted,
          _notif: _granted,
        });
        final router = await _pumpRouted(t, initialLocation: AppRoutes.map);
        expect(find.text('PETA'), findsOneWidget);

        unawaited(router.push(locationOnboardingPath));
        await t.pumpAndSettle();
        expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);

        await _tap(t, TrackingStrings.done);
        expect(find.text(TrackingStrings.batteryTitle), findsNothing);
        expect(find.text('PETA'), findsOneWidget);
      },
    );

    testWidgets('dibuka langsung (tidak bisa pop): Selesai menuju peta', (
      t,
    ) async {
      _gateway.statuses.addAll({
        _inUse: _granted,
        _always: _granted,
        _notif: _granted,
      });
      await _pumpRouted(t, initialLocation: locationOnboardingPath);
      expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);

      await _tap(t, TrackingStrings.done);
      expect(find.text('PETA'), findsOneWidget);
    });

    testWidgets('Selesai menyegarkan status izin lokasi', (t) async {
      _gateway.statuses.addAll({
        _inUse: _granted,
        _always: _granted,
        _notif: _granted,
      });
      await _pumpRouted(t, initialLocation: locationOnboardingPath);
      final before = _gateway.statusCalls.where((p) => p == _inUse).length;

      await _tap(t, TrackingStrings.done);
      expect(
        _gateway.statusCalls.where((p) => p == _inUse).length,
        greaterThan(before),
      );
      expect(_container.read(locationPermissionProvider), _granted);
    });

    testWidgets('layar lokasi ditolak: Selesai keluar dan status tersegarkan', (
      t,
    ) async {
      _gateway.requestResults[_inUse] = _denied;
      await _pumpRouted(t, initialLocation: locationOnboardingPath);
      await _tap(t, TrackingStrings.next);
      await _tap(t, TrackingStrings.done);
      expect(find.text('PETA'), findsOneWidget);
      expect(_container.read(locationPermissionProvider), _denied);
    });

    testWidgets('tanpa GoRouter: Selesai memakai Navigator', (t) async {
      _gateway.statuses.addAll({
        _inUse: _granted,
        _always: _granted,
        _notif: _granted,
      });
      _container = ProviderContainer(
        overrides: [permissionGatewayProvider.overrideWithValue(_gateway)],
      );
      addTearDown(_container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: _container,
          child: CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const LocationOnboardingPage(),
                  ),
                ),
                child: const Text('BUKA'),
              ),
            ),
          ),
        ),
      );
      await _tap(t, 'BUKA');
      expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);
      await _tap(t, TrackingStrings.done);
      expect(find.text(TrackingStrings.batteryTitle), findsNothing);
      expect(find.text('BUKA'), findsOneWidget);
    });
  });
}
