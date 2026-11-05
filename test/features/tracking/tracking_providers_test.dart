import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/tracking/data/geolocator_location_source.dart';
import 'package:tether/features/tracking/data/looping_simulated_source.dart';
import 'package:tether/features/tracking/data/permission_gateways.dart';
import 'package:tether/features/tracking/data/tracking_providers.dart';
import 'package:tether/features/tracking/domain/permission_gateway.dart';
import 'package:tether/features/tracking/domain/tracking_platform.dart';

import 'tracking_fakes.dart';

ProviderContainer _container(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('chooseLocationSourceKind', () {
    LocationSourceKind kind(
      TrackingPlatform p, {
      required bool allowed,
      required bool active,
    }) => chooseLocationSourceKind(
      platform: p,
      simulationAllowed: allowed,
      simulationActive: active,
    );

    test('simulasi menang di semua platform bila diizinkan dan aktif', () {
      for (final p in TrackingPlatform.values) {
        expect(
          kind(p, allowed: true, active: true),
          LocationSourceKind.simulated,
        );
      }
    });

    test('simulasi aktif tapi tidak diizinkan build: diabaikan', () {
      expect(
        kind(TrackingPlatform.android, allowed: false, active: true),
        LocationSourceKind.geolocator,
      );
      expect(
        kind(TrackingPlatform.desktop, allowed: false, active: true),
        LocationSourceKind.unavailable,
      );
    });

    test('tanpa simulasi: GPS di Android dan iOS, tidak ada di desktop', () {
      for (final allowed in [true, false]) {
        expect(
          kind(TrackingPlatform.android, allowed: allowed, active: false),
          LocationSourceKind.geolocator,
        );
        expect(
          kind(TrackingPlatform.ios, allowed: allowed, active: false),
          LocationSourceKind.geolocator,
        );
        expect(
          kind(TrackingPlatform.desktop, allowed: allowed, active: false),
          LocationSourceKind.unavailable,
        );
      }
    });
  });

  group('currentTrackingPlatform', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('memetakan platform target', () {
      final expected = {
        TargetPlatform.android: TrackingPlatform.android,
        TargetPlatform.iOS: TrackingPlatform.ios,
        TargetPlatform.linux: TrackingPlatform.desktop,
        TargetPlatform.macOS: TrackingPlatform.desktop,
        TargetPlatform.windows: TrackingPlatform.desktop,
        TargetPlatform.fuchsia: TrackingPlatform.desktop,
      };
      expected.forEach((target, platform) {
        debugDefaultTargetPlatformOverride = target;
        expect(currentTrackingPlatform(), platform, reason: '$target');
      });
    });
  });

  group('SimulationActive', () {
    test('tidak diizinkan: tetap mati dan start diabaikan', () {
      final c = _container([
        simulationAllowedProvider.overrideWithValue(false),
      ]);
      expect(c.read(simulationActiveProvider), isFalse);
      c.read(simulationActiveProvider.notifier).start();
      expect(c.read(simulationActiveProvider), isFalse);
    });

    test('diizinkan: start menghidupkan, stop mematikan', () {
      final c = _container([simulationAllowedProvider.overrideWithValue(true)]);
      // Awal mengikuti flag SIMULATE_LOCATION (mati bila tidak diberikan).
      expect(c.read(simulationActiveProvider), simulateLocationFlag);
      c.read(simulationActiveProvider.notifier).start();
      expect(c.read(simulationActiveProvider), isTrue);
      c.read(simulationActiveProvider.notifier).stop();
      expect(c.read(simulationActiveProvider), isFalse);
    });
  });

  group('locationSourceKindProvider', () {
    test('mengikuti platform dan simulasi', () {
      final c = _container([
        trackingPlatformProvider.overrideWithValue(TrackingPlatform.desktop),
        simulationAllowedProvider.overrideWithValue(true),
      ]);
      expect(
        c.read(locationSourceKindProvider),
        simulateLocationFlag
            ? LocationSourceKind.simulated
            : LocationSourceKind.unavailable,
      );
      c.read(simulationActiveProvider.notifier).start();
      expect(c.read(locationSourceKindProvider), LocationSourceKind.simulated);
      c.read(simulationActiveProvider.notifier).stop();
      expect(
        c.read(locationSourceKindProvider),
        LocationSourceKind.unavailable,
      );
    });

    test('Android tanpa simulasi: geolocator', () {
      final c = _container([
        trackingPlatformProvider.overrideWithValue(TrackingPlatform.android),
        simulationAllowedProvider.overrideWithValue(false),
      ]);
      expect(c.read(locationSourceKindProvider), LocationSourceKind.geolocator);
    });
  });

  group('SourceProblem', () {
    test(
      'awalnya null, report menyimpan teks aman, report(null) menghapus',
      () {
        final c = _container([]);
        expect(c.read(sourceProblemProvider), isNull);

        c
            .read(sourceProblemProvider.notifier)
            .report(const LocationServiceDisabledException());
        expect(c.read(sourceProblemProvider), 'Layanan lokasi perangkat mati.');

        c.read(sourceProblemProvider.notifier).report(StateError('-6.2,106.8'));
        expect(
          c.read(sourceProblemProvider),
          'Sumber lokasi gagal (StateError).',
        );

        c.read(sourceProblemProvider.notifier).report(null);
        expect(c.read(sourceProblemProvider), isNull);
      },
    );
  });

  group('locationSourceProvider', () {
    List<Override> forKind(TrackingPlatform p, {bool sim = false}) => [
      trackingPlatformProvider.overrideWithValue(p),
      simulationAllowedProvider.overrideWithValue(sim),
    ];

    test('unavailable: sumber kosong yang aman dijalankan', () async {
      final c = _container(forKind(TrackingPlatform.desktop));
      final source = c.read(locationSourceProvider);
      expect(await source.points.isEmpty, isTrue);
      await source.start();
      await source.stop();
    });

    test('geolocator di Android (tidak dimulai, plugin tidak dipanggil)', () {
      final c = _container(forKind(TrackingPlatform.android));
      expect(c.read(locationSourceProvider), isA<GeolocatorLocationSource>());
    });

    test('simulasi: sumber berulang', () {
      final c = _container(forKind(TrackingPlatform.desktop, sim: true));
      c.read(simulationActiveProvider.notifier).start();
      expect(c.read(locationSourceProvider), isA<LoopingSimulatedSource>());
    });

    test('jenis sumber berganti saat simulasi dihidupkan', () {
      final c = _container(forKind(TrackingPlatform.desktop, sim: true));
      c.listen(locationSourceProvider, (_, _) {});
      final before = c.read(locationSourceProvider);
      c.read(simulationActiveProvider.notifier).start();
      expect(c.read(locationSourceProvider), isNot(same(before)));
    });
  });

  group('permissionGatewayProvider', () {
    test('desktop memakai gateway desktop, Android dan iOS memakai plugin', () {
      Type gatewayFor(TrackingPlatform p) {
        final c = _container([trackingPlatformProvider.overrideWithValue(p)]);
        return c.read(permissionGatewayProvider).runtimeType;
      }

      expect(gatewayFor(TrackingPlatform.desktop), DesktopPermissionGateway);
      expect(gatewayFor(TrackingPlatform.android), PermissionHandlerGateway);
      expect(gatewayFor(TrackingPlatform.ios), PermissionHandlerGateway);
    });
  });

  group('DesktopPermissionGateway', () {
    test('semua izin dianggap diberikan, tanpa efek samping', () async {
      const g = DesktopPermissionGateway();
      for (final p in TrackingPermission.values) {
        expect(await g.status(p), AppPermissionStatus.granted);
        expect(await g.request(p), AppPermissionStatus.granted);
      }
      await g.openSettings();
    });
  });

  group('AppPermissionStatus', () {
    test('hanya granted yang isGranted', () {
      expect(AppPermissionStatus.granted.isGranted, isTrue);
      expect(AppPermissionStatus.denied.isGranted, isFalse);
      expect(AppPermissionStatus.permanentlyDenied.isGranted, isFalse);
    });
  });

  group('locationPermissionProvider', () {
    test('null dulu, lalu status dari gateway', () async {
      final gateway = FakePermissionGateway(
        statuses: {
          TrackingPermission.locationWhenInUse: AppPermissionStatus.granted,
        },
      );
      final c = _container([
        permissionGatewayProvider.overrideWithValue(gateway),
      ]);
      c.listen(locationPermissionProvider, (_, _) {});
      expect(c.read(locationPermissionProvider), isNull);
      await pumpEventQueue();
      expect(c.read(locationPermissionProvider), AppPermissionStatus.granted);
      expect(gateway.statusCalls, [TrackingPermission.locationWhenInUse]);
    });

    test('refresh membaca ulang (mis. kembali dari pengaturan)', () async {
      final gateway = FakePermissionGateway();
      final c = _container([
        permissionGatewayProvider.overrideWithValue(gateway),
      ]);
      c.listen(locationPermissionProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(locationPermissionProvider), AppPermissionStatus.denied);

      gateway.statuses[TrackingPermission.locationWhenInUse] =
          AppPermissionStatus.permanentlyDenied;
      await c.read(locationPermissionProvider.notifier).refresh();
      expect(
        c.read(locationPermissionProvider),
        AppPermissionStatus.permanentlyDenied,
      );
    });

    test('gateway melempar: dianggap ditolak', () async {
      final gateway = FakePermissionGateway()..throwOnStatus = true;
      final c = _container([
        permissionGatewayProvider.overrideWithValue(gateway),
      ]);
      c.listen(locationPermissionProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(locationPermissionProvider), AppPermissionStatus.denied);
    });

    test('refresh yang selesai setelah dispose tidak melempar', () async {
      final gateway = FakePermissionGateway();
      final c = ProviderContainer(
        overrides: [permissionGatewayProvider.overrideWithValue(gateway)],
      );
      c.read(locationPermissionProvider);
      c.dispose();
      await pumpEventQueue(); // tidak ada pengecualian "disposed"
    });
  });

  group('hasCircleMembershipProvider', () {
    test('belum masuk: false tanpa menyentuh klien Supabase', () async {
      final c = _container([
        currentUserIdProvider.overrideWith(() => FakeUserId(null)),
      ]);
      expect(await c.read(hasCircleMembershipProvider.future), isFalse);
    });
  });
}
