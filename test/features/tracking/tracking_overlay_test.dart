import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tether/app/routes.dart';
import 'package:tether/app/theme/app_colors.dart';
import 'package:tether/features/tracking/data/tracking_providers.dart';
import 'package:tether/features/tracking/data/tracking_service.dart';
import 'package:tether/features/tracking/domain/permission_gateway.dart';
import 'package:tether/features/tracking/domain/tracking_platform.dart';
import 'package:tether/features/tracking/domain/tracking_status.dart';
import 'package:tether/features/tracking/presentation/tracking_overlay.dart';
import 'package:tether/features/tracking/presentation/tracking_strings.dart';
import 'package:tether/features/tracking/tracking_routes.dart';

import 'tracking_fakes.dart';

const _inUse = TrackingPermission.locationWhenInUse;
const _always = TrackingPermission.locationAlways;
const _notif = TrackingPermission.notification;

const _granted = AppPermissionStatus.granted;
const _denied = AppPermissionStatus.denied;
const _permanent = AppPermissionStatus.permanentlyDenied;

/// Layanan palsu dengan potret tetap, untuk menguji tampilan murni.
class _StaticService extends TrackingService {
  _StaticService(this.snapshot);

  final TrackingSnapshot snapshot;

  @override
  TrackingSnapshot build() => snapshot;
}

late ProviderContainer _container;

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides, {
  GoRouter? router,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  _container = ProviderContainer(overrides: overrides);
  addTearDown(_container.dispose);
  final r =
      router ??
      GoRouter(
        navigatorKey: rootNavigatorKey,
        routes: [
          GoRoute(
            path: AppRoutes.map,
            builder: (_, _) => const CupertinoPageScaffold(
              child: Align(
                alignment: Alignment.topCenter,
                child: TrackingOverlay(),
              ),
            ),
          ),
          ...trackingRoutes,
        ],
      );
  addTearDown(r.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: CupertinoApp.router(routerConfig: r),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _static(TrackingSnapshot s, {bool simulationAllowed = false}) =>
    [
      trackingServiceProvider.overrideWith(() => _StaticService(s)),
      simulationAllowedProvider.overrideWithValue(simulationAllowed),
    ];

Color _dotColor(WidgetTester tester) {
  final box = tester.widgetList<Container>(find.byType(Container)).firstWhere((
    c,
  ) {
    final d = c.decoration;
    return d is BoxDecoration && d.shape == BoxShape.circle;
  });
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  group('overlayText', () {
    test('satu teks per status', () {
      String text(TrackingStatus s, {int queued = 0}) =>
          overlayText(TrackingSnapshot(status: s, queued: queued));
      expect(text(TrackingStatus.running), TrackingStrings.overlayRunning);
      expect(
        text(TrackingStatus.needsPermission),
        TrackingStrings.overlayNeedsPermission,
      );
      expect(
        text(TrackingStatus.needsCircle),
        TrackingStrings.overlayNeedsCircle,
      );
      expect(
        text(TrackingStatus.unavailable),
        TrackingStrings.overlayUnavailable,
      );
      expect(text(TrackingStatus.error), TrackingStrings.overlayError);
      expect(text(TrackingStatus.idle), TrackingStrings.overlayIdle);
      expect(
        text(TrackingStatus.offlineWithQueue, queued: 3),
        'Offline, 3 titik tertahan',
      );
    });

    test('setiap status punya teks berbeda', () {
      final texts = {
        for (final s in TrackingStatus.values)
          overlayText(TrackingSnapshot(status: s, queued: 1)),
      };
      expect(texts, hasLength(TrackingStatus.values.length));
    });
  });

  group('statusColor', () {
    test('hijau berjalan, kuning perlu tindakan, merah galat, abu netral', () {
      expect(statusColor(TrackingStatus.running), AppColors.success);
      expect(statusColor(TrackingStatus.needsPermission), AppColors.warning);
      expect(statusColor(TrackingStatus.needsCircle), AppColors.warning);
      expect(statusColor(TrackingStatus.offlineWithQueue), AppColors.warning);
      expect(statusColor(TrackingStatus.error), AppColors.danger);
      expect(statusColor(TrackingStatus.unavailable), AppColors.textSecondary);
      expect(statusColor(TrackingStatus.idle), AppColors.textSecondary);
    });
  });

  group('statusExplanation', () {
    test('penjelasan per status; error memakai detail bila ada', () {
      String ex(TrackingSnapshot s) => statusExplanation(s);
      expect(ex(const TrackingSnapshot()), TrackingStrings.sheetIdle);
      expect(
        ex(const TrackingSnapshot(status: TrackingStatus.needsPermission)),
        TrackingStrings.sheetNeedsPermission,
      );
      expect(
        ex(const TrackingSnapshot(status: TrackingStatus.needsCircle)),
        TrackingStrings.sheetNeedsCircle,
      );
      expect(
        ex(const TrackingSnapshot(status: TrackingStatus.unavailable)),
        TrackingStrings.sheetUnavailable,
      );
      expect(
        ex(const TrackingSnapshot(status: TrackingStatus.running)),
        TrackingStrings.sheetRunning,
      );
      expect(
        ex(const TrackingSnapshot(status: TrackingStatus.offlineWithQueue)),
        TrackingStrings.sheetOffline,
      );
      expect(
        ex(const TrackingSnapshot(status: TrackingStatus.error)),
        TrackingStrings.sheetErrorFallback,
      );
      expect(
        ex(
          const TrackingSnapshot(
            status: TrackingStatus.error,
            detail: 'Izin lokasi ditolak.',
          ),
        ),
        'Izin lokasi ditolak.',
      );
    });
  });

  group('pil per status (layanan statis)', () {
    final cases = <TrackingSnapshot, String>{
      const TrackingSnapshot(): TrackingStrings.overlayIdle,
      const TrackingSnapshot(status: TrackingStatus.needsPermission):
          TrackingStrings.overlayNeedsPermission,
      const TrackingSnapshot(status: TrackingStatus.needsCircle):
          TrackingStrings.overlayNeedsCircle,
      const TrackingSnapshot(status: TrackingStatus.unavailable):
          TrackingStrings.overlayUnavailable,
      const TrackingSnapshot(status: TrackingStatus.running):
          TrackingStrings.overlayRunning,
      const TrackingSnapshot(
        status: TrackingStatus.offlineWithQueue,
        queued: 4,
      ): 'Offline, 4 titik tertahan',
      const TrackingSnapshot(status: TrackingStatus.error):
          TrackingStrings.overlayError,
    };

    cases.forEach((snapshot, text) {
      testWidgets('${snapshot.status.name}: "$text" dan titik berwarna', (
        t,
      ) async {
        await _pump(t, _static(snapshot));
        expect(find.text(text), findsOneWidget);
        expect(
          CupertinoDynamicColor.resolve(
            _dotColor(t),
            t.element(find.text(text)),
          ),
          CupertinoDynamicColor.resolve(
            statusColor(snapshot.status),
            t.element(find.text(text)),
          ),
        );
      });
    });

    testWidgets('semantik: label teks, hint buka detail, sebagai tombol', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _pump(
        t,
        _static(const TrackingSnapshot(status: TrackingStatus.running)),
      );
      final node = t.getSemantics(
        find.bySemanticsLabel(TrackingStrings.overlayRunning),
      );
      expect(
        node,
        isSemantics(
          isButton: true,
          label: TrackingStrings.overlayRunning,
          hint: TrackingStrings.hintOpenDetail,
        ),
      );
      handle.dispose();
    });

    testWidgets('perlu izin: hint mengarah ke pengaturan izin', (t) async {
      final handle = t.ensureSemantics();
      await _pump(
        t,
        _static(const TrackingSnapshot(status: TrackingStatus.needsPermission)),
      );
      final node = t.getSemantics(
        find.bySemanticsLabel(TrackingStrings.overlayNeedsPermission),
      );
      expect(node.hint, TrackingStrings.hintOpenPermission);
      handle.dispose();
    });

    testWidgets('tinggi minimal 44 dan tidak overflow pada teks 200 persen', (
      t,
    ) async {
      await _pump(
        t,
        _static(
          const TrackingSnapshot(
            status: TrackingStatus.offlineWithQueue,
            queued: 120,
          ),
        ),
        textScale: 2,
      );
      expect(t.takeException(), isNull);
      expect(
        t.getSize(find.byType(TrackingOverlay)).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        t.getSize(find.byType(TrackingOverlay)).width,
        lessThanOrEqualTo(360),
      );
    });
  });

  group('keadaan izin lewat layanan nyata (gateway palsu)', () {
    late TrackingHarness h;

    Future<void> pumpWith(
      WidgetTester t,
      Map<TrackingPermission, AppPermissionStatus> statuses, {
      bool hasCircle = true,
    }) async {
      h = TrackingHarness(
        hasCircle: hasCircle,
        gateway: FakePermissionGateway(statuses: statuses),
      );
      await _pump(t, h.overrides);
    }

    testWidgets('belum diminta (denied): Perlu izin lokasi', (t) async {
      await pumpWith(t, {});
      expect(find.text(TrackingStrings.overlayNeedsPermission), findsOneWidget);
      expect(h.source.starts, 0);
    });

    testWidgets('ditolak permanen: Perlu izin lokasi', (t) async {
      await pumpWith(t, {_inUse: _permanent});
      expect(find.text(TrackingStrings.overlayNeedsPermission), findsOneWidget);
      expect(h.source.starts, 0);
    });

    testWidgets('foreground diberikan: Berbagi lokasi aktif', (t) async {
      await pumpWith(t, {_inUse: _granted});
      expect(find.text(TrackingStrings.overlayRunning), findsOneWidget);
      expect(h.source.starts, 1);
    });

    testWidgets('foreground dan background diberikan: aktif', (t) async {
      await pumpWith(t, {
        _inUse: _granted,
        _always: _granted,
        _notif: _granted,
      });
      expect(find.text(TrackingStrings.overlayRunning), findsOneWidget);
    });

    testWidgets('background ditolak (mode terbatas): tetap aktif', (t) async {
      await pumpWith(t, {_inUse: _granted, _always: _denied, _notif: _denied});
      expect(find.text(TrackingStrings.overlayRunning), findsOneWidget);
    });

    testWidgets('izin diberikan tapi belum punya Circle: Gabung Circle dulu', (
      t,
    ) async {
      await pumpWith(t, {_inUse: _granted}, hasCircle: false);
      expect(find.text(TrackingStrings.overlayNeedsCircle), findsOneWidget);
      // Timer cek ulang Circle dibatalkan saat container ditutup.
      _container.dispose();
    });

    testWidgets('kembali dari pengaturan (resumed) menyegarkan izin', (
      t,
    ) async {
      await pumpWith(t, {});
      expect(find.text(TrackingStrings.overlayNeedsPermission), findsOneWidget);
      final before = h.gateway.statusCalls.length;

      h.gateway.statuses[_inUse] = _granted;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();

      expect(h.gateway.statusCalls.length, greaterThan(before));
      expect(find.text(TrackingStrings.overlayRunning), findsOneWidget);
    });

    testWidgets(
      'izin dicabut di pengaturan lalu kembali: berubah ke Perlu izin',
      (t) async {
        await pumpWith(t, {_inUse: _granted});
        expect(find.text(TrackingStrings.overlayRunning), findsOneWidget);

        h.gateway.statuses[_inUse] = _denied;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();

        expect(
          find.text(TrackingStrings.overlayNeedsPermission),
          findsOneWidget,
        );
        // stop() sumber berjalan di zona asli (future dari stream cancel).
        await t.runAsync(() => pumpEventQueue());
        expect(h.source.stops, 1);
      },
    );

    testWidgets('keadaan lain (paused) tidak menyegarkan izin', (t) async {
      await pumpWith(t, {_inUse: _granted});
      final before = h.gateway.statusCalls.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pumpAndSettle();
      expect(h.gateway.statusCalls.length, before);
      // Kembalikan agar binding bersih untuk tes berikutnya.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
    });
  });

  group('ketukan', () {
    testWidgets('Perlu izin lokasi membuka onboarding izin', (t) async {
      final h = TrackingHarness(gateway: FakePermissionGateway());
      await _pump(t, h.overrides);

      await t.tap(find.text(TrackingStrings.overlayNeedsPermission));
      await t.pumpAndSettle();

      expect(find.text(TrackingStrings.whenInUseTitle), findsOneWidget);
      expect(find.text(TrackingStrings.sheetTitle), findsNothing);
    });

    testWidgets('onboarding lalu Selesai kembali ke pil dengan izin terbarui', (
      t,
    ) async {
      final h = TrackingHarness(gateway: FakePermissionGateway());
      await _pump(t, h.overrides);

      await t.tap(find.text(TrackingStrings.overlayNeedsPermission));
      await t.pumpAndSettle();
      // Foreground, background, notifikasi diberikan, lalu panduan baterai.
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text(TrackingStrings.next));
        await t.pumpAndSettle();
      }
      expect(find.text(TrackingStrings.batteryTitle), findsOneWidget);
      await t.tap(find.text(TrackingStrings.done));
      await t.pumpAndSettle();

      expect(find.text(TrackingStrings.overlayRunning), findsOneWidget);
      expect(h.gateway.requestCalls, [_inUse, _always, _notif]);
    });

    testWidgets('status lain membuka sheet detail', (t) async {
      await _pump(
        t,
        _static(
          const TrackingSnapshot(
            status: TrackingStatus.offlineWithQueue,
            queued: 2,
            sent: 5,
            skippedByServer: 1,
            dropped: 3,
            droppedInvalid: 4,
            lastError: 'timeout',
          ),
        ),
      );
      await t.tap(find.text('Offline, 2 titik tertahan'));
      await t.pumpAndSettle();

      expect(find.text(TrackingStrings.sheetTitle), findsOneWidget);
      expect(find.text(TrackingStrings.sheetOffline), findsOneWidget);
      // Baris: label dan nilai. Dibuang = dropped + droppedInvalid.
      final rows = <String, String>{
        TrackingStrings.sent: '5',
        TrackingStrings.queued: '2',
        TrackingStrings.dropped: '7',
        TrackingStrings.skipped: '1',
        TrackingStrings.lastError: 'timeout',
      };
      final handle = t.ensureSemantics();
      rows.forEach((label, value) {
        expect(find.bySemanticsLabel('$label: $value'), findsOneWidget);
      });
      handle.dispose();
    });

    testWidgets('sheet tanpa galat menampilkan "Tidak ada"', (t) async {
      await _pump(
        t,
        _static(const TrackingSnapshot(status: TrackingStatus.running)),
      );
      await t.tap(find.text(TrackingStrings.overlayRunning));
      await t.pumpAndSettle();
      expect(find.text(TrackingStrings.sheetRunning), findsOneWidget);
      expect(find.text(TrackingStrings.none), findsOneWidget);
    });

    testWidgets('sheet galat sumber memakai detail dari layanan', (t) async {
      await _pump(
        t,
        _static(
          const TrackingSnapshot(
            status: TrackingStatus.error,
            detail: 'Layanan lokasi perangkat mati.',
          ),
        ),
      );
      await t.tap(find.text(TrackingStrings.overlayError));
      await t.pumpAndSettle();
      expect(find.text('Layanan lokasi perangkat mati.'), findsOneWidget);
    });

    testWidgets('Selesai menutup sheet', (t) async {
      await _pump(
        t,
        _static(const TrackingSnapshot(status: TrackingStatus.running)),
      );
      await t.tap(find.text(TrackingStrings.overlayRunning));
      await t.pumpAndSettle();
      expect(find.text(TrackingStrings.sheetTitle), findsOneWidget);

      await t.tap(find.text(TrackingStrings.close));
      await t.pumpAndSettle();
      expect(find.text(TrackingStrings.sheetTitle), findsNothing);
    });

    testWidgets('sheet bisa digulir pada teks 200 persen tanpa overflow', (
      t,
    ) async {
      await _pump(
        t,
        _static(
          const TrackingSnapshot(status: TrackingStatus.running),
          simulationAllowed: true,
        ),
        textScale: 2,
      );
      await t.tap(find.text(TrackingStrings.overlayRunning));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('simulasi di sheet', () {
    testWidgets('tidak diizinkan build: bagian simulasi tidak tampil', (
      t,
    ) async {
      await _pump(
        t,
        _static(const TrackingSnapshot(status: TrackingStatus.running)),
      );
      await t.tap(find.text(TrackingStrings.overlayRunning));
      await t.pumpAndSettle();
      expect(find.text(TrackingStrings.simulationTitle), findsNothing);
      expect(find.text(TrackingStrings.simulationStart), findsNothing);
    });

    testWidgets('diizinkan: tombol memulai dan menghentikan simulasi', (
      t,
    ) async {
      await _pump(
        t,
        _static(
          const TrackingSnapshot(status: TrackingStatus.running),
          simulationAllowed: true,
        ),
      );
      await t.tap(find.text(TrackingStrings.overlayRunning));
      await t.pumpAndSettle();
      expect(find.text(TrackingStrings.simulationTitle), findsOneWidget);
      expect(find.text(TrackingStrings.simulationNote), findsOneWidget);
      expect(_container.read(simulationActiveProvider), simulateLocationFlag);

      if (simulateLocationFlag) {
        await t.tap(find.text(TrackingStrings.simulationStop));
        await t.pumpAndSettle();
        expect(_container.read(simulationActiveProvider), isFalse);
      }
      await t.tap(find.text(TrackingStrings.simulationStart));
      await t.pumpAndSettle();
      expect(_container.read(simulationActiveProvider), isTrue);
      expect(find.text(TrackingStrings.simulationStop), findsOneWidget);

      await t.tap(find.text(TrackingStrings.simulationStop));
      await t.pumpAndSettle();
      expect(_container.read(simulationActiveProvider), isFalse);
      expect(find.text(TrackingStrings.simulationStart), findsOneWidget);
    });
  });

  testWidgets('pelepasan: tidak ada pengamat lifecycle tersisa', (t) async {
    await _pump(
      t,
      _static(const TrackingSnapshot(status: TrackingStatus.running)),
    );
    await t.pumpWidget(const SizedBox());
    // Tidak boleh melempar walau ProviderScope sudah hilang.
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
