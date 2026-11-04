import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/app.dart';
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/profile/data/profile_providers.dart';

import 'fakes.dart';

/// Menjalankan TetherApp penuh dengan repository palsu (tanpa server).
/// [textScale] mengatur skala teks sistem untuk tes aksesibilitas.
Future<void> pumpTetherApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeProfileRepository? profile,
  double textScale = 1.0,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          profile ?? FakeProfileRepository(),
        ),
      ],
      child: const TetherApp(),
    ),
  );
  await tester.pumpAndSettle();
}
