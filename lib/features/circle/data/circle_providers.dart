import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selected_circle.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/circle.dart';
import '../domain/circle_repository.dart';
import 'supabase_circle_repository.dart';

/// Override di tes dengan repository palsu.
final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => SupabaseCircleRepository(ref.watch(supabaseClientProvider)),
);

/// Circle milik pengguna yang sedang masuk. Dimuat ulang bila pengguna ganti.
final myCirclesProvider = FutureProvider<List<Circle>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.watch(circleRepositoryProvider).myCircles();
}, retry: (_, _) => null);

/// Anggota satu Circle. Diperbarui lewat langganan events (tanpa kilatan
/// loading), dan lewat [MembersNotifier.refresh] untuk tarik-untuk-muat.
final membersProvider =
    AsyncNotifierProvider.family<MembersNotifier, List<CircleMember>, String>(
      MembersNotifier.new,
      isAutoDispose: true,
      retry: (_, _) => null,
    );

class MembersNotifier extends AsyncNotifier<List<CircleMember>> {
  MembersNotifier(this.circleId);

  final String circleId;

  @override
  Future<List<CircleMember>> build() {
    final uid = ref.watch(currentUserIdProvider);
    final repo = ref.watch(circleRepositoryProvider);
    final sub = repo
        .memberChanges(circleId)
        .listen(
          (_) => unawaited(refresh().catchError((Object _) {})),
          onError: (Object _) {},
        );
    ref.onDispose(sub.cancel);
    return repo.members(circleId).then((members) {
      _checkStillMember(uid, members);
      return members;
    });
  }

  /// Ambil ulang anggota. Melempar CircleError bila gagal; data lama tetap.
  Future<void> refresh() async {
    final uid = ref.read(currentUserIdProvider);
    final members = await ref.read(circleRepositoryProvider).members(circleId);
    if (!ref.mounted) return;
    state = AsyncData(members);
    _checkStillMember(uid, members);
  }

  // Dikeluarkan admin: SELECT tidak galat, hanya mengembalikan daftar tanpa
  // kita. Muat ulang daftar Circle agar tab menyesuaikan.
  void _checkStillMember(String? uid, List<CircleMember> members) {
    if (uid != null && !members.any((m) => m.userId == uid)) {
      Future.microtask(() {
        if (ref.mounted) ref.invalidate(myCirclesProvider);
      });
    }
  }
}

/// Muat ulang daftar Circle lalu pilih [circleId] (setelah buat/gabung).
Future<void> refreshCirclesAndSelect(WidgetRef ref, String circleId) async {
  ref.invalidate(myCirclesProvider);
  await ref.read(myCirclesProvider.future);
  ref.read(selectedCircleIdProvider.notifier).select(circleId);
}
