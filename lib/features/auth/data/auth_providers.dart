import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/auth_repository.dart';
import 'supabase_auth_repository.dart';

/// Override di tes dengan repository palsu.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// Auth gate: id pengguna saat ini (null = belum masuk). Nilai awal dari sesi
/// yang dipulihkan, lalu mengikuti aliran status auth.
final currentUserIdProvider = NotifierProvider<CurrentUserIdNotifier, String?>(
  CurrentUserIdNotifier.new,
);

class CurrentUserIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.userIdChanges.listen(
      (id) => state = id,
      // Galat aliran (mis. refresh token gagal) tidak boleh menjatuhkan app.
      onError: (Object _) {},
    );
    ref.onDispose(sub.cancel);
    return repo.currentUserId;
  }
}
