import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/profile/data/supabase_notification_settings_repository.dart';
import 'package:tether/features/profile/domain/notification_settings.dart';
import 'package:tether/features/profile/presentation/profile_strings.dart';

import 'profile_harness.dart';

/// Meniru ClientException milik paket http (dipetakan menurut nama tipe).
class ClientException implements Exception {}

Finder sw({bool? value}) => find.byWidgetPredicate(
  (w) => w is CupertinoSwitch && (value == null || w.value == value),
);

void main() {
  group('NotificationSettingsPage', () {
    testWidgets('tiga sakelar tampil dengan nilai dari server', (tester) async {
      final h = await pumpProfile(
        tester,
        settings: FakeNotificationSettingsRepository(
          initial: const NotificationSettings(
            arriveLeave: true,
            checkin: false,
            memberChanges: true,
          ),
        ),
      );
      await tester.tap(find.text(ProfileStrings.notificationRow));
      await tester.pumpAndSettle();
      expect(h.location, '/profile/notifications');
      expect(find.text(ProfileStrings.notifArriveLeave), findsOneWidget);
      expect(find.text(ProfileStrings.notifCheckin), findsOneWidget);
      expect(find.text(ProfileStrings.notifMemberChanges), findsOneWidget);
      expect(sw(value: true), findsNWidgets(2));
      expect(sw(value: false), findsOneWidget);
      expect(find.text(ProfileStrings.notifSosNote), findsOneWidget);
    });

    testWidgets('menggeser sakelar menyimpan ke server', (tester) async {
      final settings = FakeNotificationSettingsRepository();
      await pumpProfile(tester, settings: settings);
      await tester.tap(find.text(ProfileStrings.notificationRow));
      await tester.pumpAndSettle();
      await tester.tap(sw(value: true).first);
      await tester.pumpAndSettle();
      expect(settings.saved.single.arriveLeave, false);
      expect(sw(value: false), findsOneWidget);
    });

    testWidgets('gagal simpan: sakelar kembali dan dialog galat', (
      tester,
    ) async {
      final settings = FakeNotificationSettingsRepository()
        ..saveFailure = const NotificationSettingsFailure(
          NotificationSettingsFailureKind.unknown,
        );
      await pumpProfile(tester, settings: settings);
      await tester.tap(find.text(ProfileStrings.notificationRow));
      await tester.pumpAndSettle();
      await tester.tap(sw(value: true).first);
      await tester.pumpAndSettle();
      expect(settings.saved, isEmpty);
      expect(sw(value: true), findsNWidgets(3)); // kembali ke nilai awal
      expect(find.text('Gagal menyimpan'), findsOneWidget);
    });

    testWidgets('gagal memuat: pesan dan tombol coba lagi', (tester) async {
      final settings = FakeNotificationSettingsRepository()
        ..failure = const NotificationSettingsFailure(
          NotificationSettingsFailureKind.network,
        );
      await pumpProfile(tester, settings: settings);
      await tester.tap(find.text(ProfileStrings.notificationRow));
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.notifLoadFailed), findsOneWidget);
      expect(find.text(ProfileStrings.retry), findsOneWidget);
    });
  });

  group('mapNotificationSettingsError', () {
    test('galat jaringan di nama tipe -> network', () {
      expect(
        mapNotificationSettingsError(const SocketException('x')).kind,
        NotificationSettingsFailureKind.network,
      );
      expect(
        mapNotificationSettingsError(TimeoutException('x')).kind,
        NotificationSettingsFailureKind.network,
      );
      expect(
        mapNotificationSettingsError(ClientException()).kind,
        NotificationSettingsFailureKind.network,
      );
    });

    test('PostgrestException sesi -> unauthenticated, lain -> unknown', () {
      expect(
        mapNotificationSettingsError(
          const PostgrestException(message: 'm', code: '28000'),
        ).kind,
        NotificationSettingsFailureKind.unauthenticated,
      );
      expect(
        mapNotificationSettingsError(
          const PostgrestException(message: 'm', code: '42501'),
        ).kind,
        NotificationSettingsFailureKind.unauthenticated,
      );
      expect(
        mapNotificationSettingsError(Exception('x')).kind,
        NotificationSettingsFailureKind.unknown,
      );
    });
  });
}
