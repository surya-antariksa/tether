import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import 'supabase_profile_repository.dart';

/// Override di tes dengan repository palsu.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

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
