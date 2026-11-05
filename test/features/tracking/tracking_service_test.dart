import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/tracking/data/tracking_providers.dart';
import 'package:tether/features/tracking/data/tracking_service.dart';
import 'package:tether/features/tracking/domain/permission_gateway.dart';
import 'package:tether/features/tracking/domain/tracking_platform.dart';
import 'package:tether/features/tracking/domain/tracking_status.dart';

import 'tracking_fakes.dart';

const _whenInUse = TrackingPermission.locationWhenInUse;

void main() {
  group('blockingStatus', () {
    TrackingStatus? blocking({
      bool signedIn = true,
      LocationSourceKind kind = LocationSourceKind.geolocator,
      AppPermissionStatus? permission = AppPermissionStatus.granted,
      bool? hasCircle = true,
    }) => blockingStatus(
      signedIn: signedIn,
      kind: kind,
      permission: permission,
      hasCircle: hasCircle,
    );

    test('semua syarat terpenuhi: tidak diblokir', () {
      expect(blocking(), isNull);
    });

    test('belum masuk: idle, mengalahkan syarat lain', () {
      expect(
        blocking(
          signedIn: false,
          kind: LocationSourceKind.unavailable,
          permission: AppPermissionStatus.denied,
        ),
        TrackingStatus.idle,
      );
    });

    test('tanpa sumber lokasi: unavailable', () {
      expect(
        blocking(kind: LocationSourceKind.unavailable, hasCircle: false),
        TrackingStatus.unavailable,
      );
    });

    test('GPS: izin belum diketahui menunggu (idle)', () {
      expect(blocking(permission: null), TrackingStatus.idle);
    });

    test('GPS: izin ditolak atau ditolak permanen: needsPermission', () {
      for (final p in [
        AppPermissionStatus.denied,
        AppPermissionStatus.permanentlyDenied,
      ]) {
        expect(blocking(permission: p), TrackingStatus.needsPermission);
      }
    });

    test('simulasi tidak butuh izin', () {
      expect(
        blocking(kind: LocationSourceKind.simulated, permission: null),
        isNull,
      );
      expect(
        blocking(
          kind: LocationSourceKind.simulated,
          permission: AppPermissionStatus.denied,
        ),
        isNull,
      );
    });

    test('keanggotaan Circle: belum diketahui idle, tidak ada needsCircle', () {
      expect(blocking(hasCircle: null), TrackingStatus.idle);
      expect(blocking(hasCircle: false), TrackingStatus.needsCircle);
    });

    test('izin diperiksa sebelum Circle', () {
      expect(
        blocking(permission: AppPermissionStatus.denied, hasCircle: false),
        TrackingStatus.needsPermission,
      );
    });
  });

  group('TrackingService', () {
    late TrackingHarness h;
    late ProviderContainer container;
    late List<TrackingStatus> history;

    /// Membuat container dari [h], mulai mendengarkan layanan, dan menunggu
    /// pekerjaan asinkron selesai.
    Future<void> boot() async {
      container = ProviderContainer(overrides: h.overrides);
      addTearDown(container.dispose);
      history = [];
      container.listen(
        trackingServiceProvider,
        (_, next) => history.add(next.status),
        fireImmediately: true,
      );
      await pumpEventQueue();
    }

    TrackingSnapshot snap() => container.read(trackingServiceProvider);

    Future<void> setPermission(AppPermissionStatus s) async {
      h.gateway.statuses[_whenInUse] = s;
      await container.read(locationPermissionProvider.notifier).refresh();
      await pumpEventQueue();
    }

    group('start dan stop', () {
      test('syarat lengkap: berjalan dan sumber dimulai sekali', () async {
        h = TrackingHarness();
        await boot();
        expect(snap().status, TrackingStatus.running);
        expect(h.source.starts, 1);
        expect(h.source.stops, 0);
      });

      test('awalnya idle selagi izin dan Circle belum diketahui', () async {
        h = TrackingHarness();
        container = ProviderContainer(overrides: h.overrides);
        addTearDown(container.dispose);
        container.listen(trackingServiceProvider, (_, _) {});
        expect(
          container.read(trackingServiceProvider).status,
          TrackingStatus.idle,
        );
        await pumpEventQueue();
        expect(
          container.read(trackingServiceProvider).status,
          TrackingStatus.running,
        );
      });

      test('titik dari sumber diantre lalu terkirim, hitungan naik', () async {
        h = TrackingHarness();
        await boot();
        h.source.emit(pointAt(1));
        h.source.emit(pointAt(2));
        await pumpEventQueue();

        expect(h.api.received, hasLength(2));
        expect(snap().status, TrackingStatus.running);
        expect(snap().sent, 2);
        expect(snap().queued, 0);
        expect(snap().lastError, isNull);
      });

      test('unggah gagal: offlineWithQueue dengan titik tertahan', () async {
        h = TrackingHarness();
        h.api.failing = true;
        await boot();
        h.source.emit(pointAt(1));
        await pumpEventQueue();

        expect(snap().status, TrackingStatus.offlineWithQueue);
        expect(snap().queued, 1);
        expect(snap().lastError, isNotNull);
        // Pesan galat tidak boleh membawa koordinat ke UI.
        expect(snap().lastError, isNot(contains('-6.2')));
      });

      test('dispose container menghentikan sumber', () async {
        h = TrackingHarness();
        await boot();
        container.dispose();
        await pumpEventQueue();
        expect(h.source.stops, 1);
      });

      test('sisa antrean sesi lalu ikut terkirim saat mulai', () async {
        h = TrackingHarness();
        await h.queue.enqueue(pointAt(7));
        await boot();
        expect(h.api.received, hasLength(1));
        expect(snap().sent, 1);
      });

      test('keluar akun menghentikan sumber dan kembali idle', () async {
        h = TrackingHarness();
        await boot();
        (container.read(currentUserIdProvider.notifier) as FakeUserId).set(
          null,
        );
        await pumpEventQueue();

        expect(snap().status, TrackingStatus.idle);
        expect(h.source.stops, 1);
        expect(h.source.starts, 1);
      });

      test('belum masuk dari awal: idle, sumber tidak disentuh', () async {
        h = TrackingHarness(userId: null);
        await boot();
        expect(snap().status, TrackingStatus.idle);
        expect(h.source.starts, 0);
      });

      test('titik pengguna lama dibuang saat pengguna berganti', () async {
        h = TrackingHarness();
        await h.queue.enqueue(pointAt(1));
        h.api.failing = true; // titik tetap tertahan di antrean
        await boot();
        expect(snap().queued, 1);
        h.api.failing = false;

        (container.read(currentUserIdProvider.notifier) as FakeUserId).set(
          'user-2',
        );
        await pumpEventQueue();

        expect(
          h.api.received,
          isEmpty,
          reason: 'tidak terkirim atas nama baru',
        );
        expect(await h.queue.length(), 0);
        expect(snap().status, TrackingStatus.running);
        expect(h.source.starts, 2);
      });
    });

    group('izin', () {
      test(
        'belum diminta (denied): needsPermission, sumber tidak dimulai',
        () async {
          h = TrackingHarness(gateway: FakePermissionGateway());
          await boot();
          expect(snap().status, TrackingStatus.needsPermission);
          expect(h.source.starts, 0);
          expect(h.api.calls, 0);
        },
      );

      test('ditolak permanen: needsPermission', () async {
        h = TrackingHarness(
          gateway: FakePermissionGateway(
            statuses: {_whenInUse: AppPermissionStatus.permanentlyDenied},
          ),
        );
        await boot();
        expect(snap().status, TrackingStatus.needsPermission);
        expect(h.source.starts, 0);
      });

      test('gateway melempar saat membaca status: dianggap ditolak', () async {
        h = TrackingHarness(gateway: FakePermissionGateway());
        h.gateway.throwOnStatus = true;
        await boot();
        expect(
          container.read(locationPermissionProvider),
          AppPermissionStatus.denied,
        );
        expect(snap().status, TrackingStatus.needsPermission);
        expect(h.source.starts, 0);
      });

      test(
        'izin diberikan kemudian: needsPermission berubah ke running',
        () async {
          h = TrackingHarness(gateway: FakePermissionGateway());
          await boot();
          expect(snap().status, TrackingStatus.needsPermission);

          await setPermission(AppPermissionStatus.granted);
          expect(snap().status, TrackingStatus.running);
          expect(h.source.starts, 1);
          expect(
            history,
            containsAllInOrder([
              TrackingStatus.idle,
              TrackingStatus.needsPermission,
              TrackingStatus.running,
            ]),
          );
        },
      );

      test(
        'izin dicabut saat berjalan: sumber dihentikan, needsPermission',
        () async {
          h = TrackingHarness();
          await boot();
          expect(snap().status, TrackingStatus.running);

          await setPermission(AppPermissionStatus.denied);
          expect(snap().status, TrackingStatus.needsPermission);
          expect(h.source.stops, 1);

          // Titik yang masih datang dari sumber lama tidak diproses.
          h.source.emit(pointAt(1));
          await pumpEventQueue();
          expect(h.api.received, isEmpty);
        },
      );

      test('dicabut permanen saat berjalan: sama seperti ditolak', () async {
        h = TrackingHarness();
        await boot();
        await setPermission(AppPermissionStatus.permanentlyDenied);
        expect(snap().status, TrackingStatus.needsPermission);
        expect(h.source.stops, 1);
      });

      test('dicabut lalu diberikan lagi: sumber dimulai ulang', () async {
        h = TrackingHarness();
        await boot();
        await setPermission(AppPermissionStatus.denied);
        await setPermission(AppPermissionStatus.granted);
        expect(snap().status, TrackingStatus.running);
        expect(h.source.starts, 2);
        expect(h.source.stops, 1);
      });

      test(
        'izin selalu (background) ditolak tidak menghalangi pelacakan',
        () async {
          h = TrackingHarness(
            gateway: FakePermissionGateway(
              statuses: {
                _whenInUse: AppPermissionStatus.granted,
                TrackingPermission.locationAlways: AppPermissionStatus.denied,
                TrackingPermission.notification: AppPermissionStatus.denied,
              },
            ),
          );
          await boot();
          expect(snap().status, TrackingStatus.running);
          expect(h.source.starts, 1);
        },
      );

      test('simulasi tetap berjalan tanpa izin', () async {
        h = TrackingHarness(
          gateway: FakePermissionGateway(),
          simulationAllowed: true,
        );
        await boot();
        expect(snap().status, TrackingStatus.needsPermission);

        container.read(simulationActiveProvider.notifier).start();
        await pumpEventQueue();
        expect(snap().status, TrackingStatus.running);
        expect(h.source.starts, 1);
      });

      test(
        'desktop tanpa simulasi: unavailable, sumber tidak dimulai',
        () async {
          h = TrackingHarness(platform: TrackingPlatform.desktop);
          await boot();
          expect(snap().status, TrackingStatus.unavailable);
          expect(h.source.starts, 0);
          expect(h.circleChecks, isNonZero);
        },
      );
    });

    group('Circle', () {
      test('tanpa keanggotaan: needsCircle, sumber tidak dimulai', () async {
        h = TrackingHarness(hasCircle: false);
        await boot();
        expect(snap().status, TrackingStatus.needsCircle);
        expect(h.source.starts, 0);
      });

      test('query keanggotaan gagal: tetap idle (bukan needsCircle)', () async {
        h = TrackingHarness();
        h.circleError = StateError('jaringan');
        await boot();
        expect(snap().status, TrackingStatus.idle);
        expect(h.source.starts, 0);
      });

      test('cek ulang tiap 30 detik; mulai berjalan setelah bergabung', () {
        FakeAsync().run((async) {
          h = TrackingHarness(hasCircle: false);
          container = ProviderContainer(overrides: h.overrides);
          container.listen(trackingServiceProvider, (_, _) {});
          async.flushMicrotasks();
          expect(
            container.read(trackingServiceProvider).status,
            TrackingStatus.needsCircle,
          );
          expect(h.circleChecks, 1);

          async.elapse(circleRecheckInterval - const Duration(seconds: 1));
          expect(h.circleChecks, 1);

          h.hasCircle = true;
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(h.circleChecks, 2);
          expect(
            container.read(trackingServiceProvider).status,
            TrackingStatus.running,
          );
          expect(h.source.starts, 1);

          container.dispose();
          async.flushMicrotasks();
        });
      });

      test('dispose membatalkan cek ulang', () {
        FakeAsync().run((async) {
          h = TrackingHarness(hasCircle: false);
          container = ProviderContainer(overrides: h.overrides);
          container.listen(trackingServiceProvider, (_, _) {});
          async.flushMicrotasks();
          container.dispose();
          async.elapse(circleRecheckInterval * 3);
          expect(h.circleChecks, 1);
        });
      });
    });

    group('galat sumber', () {
      test(
        'sumber gagal dimulai: error dengan penjelasan tanpa koordinat',
        () async {
          h = TrackingHarness();
          h.source.startError = const LocationServiceDisabledException();
          await boot();
          expect(snap().status, TrackingStatus.error);
          expect(snap().detail, 'Layanan lokasi perangkat mati.');
        },
      );

      test('galat dilaporkan sumber saat berjalan, lalu pulih', () async {
        h = TrackingHarness();
        await boot();
        expect(snap().status, TrackingStatus.running);

        container
            .read(sourceProblemProvider.notifier)
            .report(const PermissionDeniedException('x'));
        await pumpEventQueue();
        expect(snap().status, TrackingStatus.error);
        expect(snap().detail, 'Izin lokasi ditolak.');

        container.read(sourceProblemProvider.notifier).report(null);
        await pumpEventQueue();
        expect(snap().status, TrackingStatus.running);
        expect(snap().detail, isNull);
      });

      test('galat sumber menang atas antrean offline', () async {
        h = TrackingHarness();
        h.api.failing = true;
        await boot();
        h.source.emit(pointAt(1));
        await pumpEventQueue();
        expect(snap().status, TrackingStatus.offlineWithQueue);

        container
            .read(sourceProblemProvider.notifier)
            .report(TimeoutException('x'));
        await pumpEventQueue();
        expect(snap().status, TrackingStatus.error);
        expect(snap().queued, 1);
      });

      test('galat lama dihapus saat layanan dimulai ulang', () async {
        h = TrackingHarness();
        await boot();
        container
            .read(sourceProblemProvider.notifier)
            .report(TimeoutException('x'));
        await pumpEventQueue();
        expect(snap().status, TrackingStatus.error);

        await setPermission(AppPermissionStatus.denied);
        await setPermission(AppPermissionStatus.granted);
        expect(snap().status, TrackingStatus.running);
        expect(container.read(sourceProblemProvider), isNull);
      });
    });
  });
}
