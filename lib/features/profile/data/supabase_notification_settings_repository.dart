import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/notification_settings.dart';

class SupabaseNotificationSettingsRepository
    implements NotificationSettingsRepository {
  SupabaseNotificationSettingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<NotificationSettings> fetch() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const NotificationSettingsFailure(
          NotificationSettingsFailureKind.unauthenticated,
        );
      }
      final row = await _client
          .from('notification_settings')
          .select('arrive_leave, checkin, member_changes')
          .eq('user_id', uid)
          .maybeSingle();
      // Baris dibuat trigger on_profile_created; bila belum ada (istimewa),
      // pakai nilai bawaan semua nyala.
      return NotificationSettings(
        arriveLeave: row?['arrive_leave'] as bool? ?? true,
        checkin: row?['checkin'] as bool? ?? true,
        memberChanges: row?['member_changes'] as bool? ?? true,
      );
    } catch (e) {
      throw mapNotificationSettingsError(e);
    }
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const NotificationSettingsFailure(
          NotificationSettingsFailureKind.unauthenticated,
        );
      }
      await _client
          .from('notification_settings')
          .update({
            'arrive_leave': settings.arriveLeave,
            'checkin': settings.checkin,
            'member_changes': settings.memberChanges,
          })
          .eq('user_id', uid);
    } catch (e) {
      throw mapNotificationSettingsError(e);
    }
  }
}

/// Galat teknis -> [NotificationSettingsFailure]. Klien mengubah per baris
/// via kebijakan own (28000: tidak masuk).
NotificationSettingsFailure mapNotificationSettingsError(Object e) {
  if (e is NotificationSettingsFailure) return e;
  if (e is SocketException ||
      e is TimeoutException ||
      e is AuthRetryableFetchException ||
      // ClientException milik paket http (tidak diimpor langsung).
      e.runtimeType.toString() == 'ClientException') {
    return const NotificationSettingsFailure(
      NotificationSettingsFailureKind.network,
    );
  }
  if (e is PostgrestException &&
      (e.code == '28000' || e.code == 'PGRST301' || e.code == '42501')) {
    return const NotificationSettingsFailure(
      NotificationSettingsFailureKind.unauthenticated,
    );
  }
  return const NotificationSettingsFailure(
    NotificationSettingsFailureKind.unknown,
  );
}
