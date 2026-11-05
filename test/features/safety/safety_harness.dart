import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/core/selected_circle.dart';
import 'package:tether/features/activity/data/activity_providers.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/safety/data/safety_providers.dart';
import 'package:tether/features/safety/domain/sos_queue_store.dart';
import 'package:tether/features/safety/presentation/safety_sheet.dart';
import 'package:tether/features/safety/presentation/sos_hold_button.dart';

import '../../support/fakes.dart';
import '../activity/fake_activity.dart' show FakeNotificationGateway;
import 'safety_fakes.dart';

final _containers = <ProviderContainer>[];

/// Seperti testWidgets, tetapi menutup pohon widget dan container (timer
/// hitung mundur, antrean) SEBELUM pemeriksaan timer tertunda milik tes.
void testSafety(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    try {
      await body(t);
    } finally {
      await t.pumpWidget(const SizedBox());
      for (final c in _containers) {
        c.dispose();
      }
      _containers.clear();
      await t.pump();
    }
  });
}

class SafetyHarness {
  SafetyHarness(
    this.container,
    this.repo,
    this.location,
    this.haptics,
    this.store,
    this.gateway,
  );

  final ProviderContainer container;
  final FakeSafetyRepository repo;
  final FakeSosLocation location;
  final FakeHaptics haptics;
  final InMemorySosQueueStore store;
  final FakeNotificationGateway gateway;

  SosState get sos => container.read(sosControllerProvider);
}

/// Halaman dengan tombol Keselamatan (seperti di peta), semuanya palsu: tanpa
/// jaringan, GPS, haptic, atau berkas.
Future<SafetyHarness> pumpSafety(
  WidgetTester tester, {
  FakeSafetyRepository? repo,
  FakeSosLocation? location,
  InMemorySosQueueStore? store,
  String? selectedCircle = 'c1',
  double textScale = 1.0,
  bool reduceMotion = false,
  bool screenReader = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduceMotion,
        accessibleNavigation: screenReader,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final r = repo ?? FakeSafetyRepository();
  final loc = location ?? FakeSosLocation(currentFix: jakarta);
  final haptics = FakeHaptics();
  final queue = store ?? InMemorySosQueueStore();
  final gateway = FakeNotificationGateway();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(userId: 'u1'),
      ),
      safetyRepositoryProvider.overrideWithValue(r),
      sosLocationProvider.overrideWithValue(loc),
      sosHapticsProvider.overrideWithValue(haptics),
      sosQueueStoreProvider.overrideWith((ref) async => queue),
      notificationGatewayProvider.overrideWithValue(gateway),
    ],
  );
  _containers.add(container);
  container.read(selectedCircleIdProvider.notifier).select(selectedCircle);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: CupertinoApp(
        theme: appTheme,
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: const [
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topRight,
            child: SafeArea(child: SafetyActionsButton()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return SafetyHarness(container, r, loc, haptics, queue, gateway);
}

/// Membuka lembar Keselamatan.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(SafetyActionsButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

final holdButton = find.byType(SosHoldButton);
final holdProgress = find.byKey(const ValueKey('sos-hold-progress'));

/// Lebar relatif progres tahan (0 sampai 1).
double progressFraction(WidgetTester tester) {
  final box = tester.widget<FractionallySizedBox>(
    find.ancestor(
      of: holdProgress,
      matching: find.byType(FractionallySizedBox),
    ),
  );
  return box.widthFactor!;
}

/// Menahan tombol SOS selama [d] dan mengembalikan gestur (belum dilepas).
Future<TestGesture> holdSos(WidgetTester tester, Duration d) async {
  final g = await tester.startGesture(tester.getCenter(holdButton));
  // Tap baru "turun" setelah kPressTimeout (100 ms); pompa kecil dulu agar
  // ticker animasi mulai sebelum waktu uji dimajukan.
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(d);
  return g;
}
