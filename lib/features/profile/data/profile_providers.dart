import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/account_repository.dart';
import '../domain/notification_settings.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import 'supabase_account_repository.dart';
import 'supabase_notification_settings_repository.dart';
import 'supabase_profile_repository.dart';

/// Override di tes dengan repository palsu.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

/// Override di tes dengan repository palsu.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

/// Override di tes dengan repository palsu.
final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>(
      (ref) => SupabaseNotificationSettingsRepository(
        ref.watch(supabaseClientProvider),
      ),
    );

/// Pengaturan notifikasi (tiga sakelar di tabel notification_settings). SOS
/// tidak punya sakelar: selalu dikirim, keputusan itu di sisi server.
final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
      isAutoDispose: true,
      retry: (_, _) => null, // pengguna memicu ulang lewat tombol
    );

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(notificationSettingsRepositoryProvider).fetch();
  }

  /// Simpan nilai sakelar: optimistik, bila server gagal sakelar kembali ke
  /// nilai lama dan galat dilempar (pemanggil UI menampilkannya).
  Future<void> set(NotificationSettings next) async {
    final cur = state.value ?? const NotificationSettings();
    final repo = ref.read(notificationSettingsRepositoryProvider);
    state = AsyncData(next);
    try {
      await repo.save(next);
    } catch (_) {
      if (ref.mounted) state = AsyncData(cur); // kembalikan sakelar
      rethrow;
    }
  }
}

/// Profil milik pengguna yang sedang masuk. Dimuat ulang bila pengguna ganti.
final ownProfileProvider = AsyncNotifierProvider<OwnProfileNotifier, Profile>(
  OwnProfileNotifier.new,
  isAutoDispose: true,
  retry: (_, _) => null, // pengguna memicu ulang lewat tombol
);

class OwnProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(profileRepositoryProvider).fetchOwn();
  }

  /// Melempar ProfileFailure bila gagal; state profil lama tetap.
  Future<void> updateProfile({String? displayName, String? color}) async {
    final next = await ref
        .read(profileRepositoryProvider)
        .updateOwn(displayName: displayName, color: color);
    state = AsyncData(next);
  }
}
