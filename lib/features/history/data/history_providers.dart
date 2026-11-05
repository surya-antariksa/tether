import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/history_point.dart';
import '../domain/history_repository.dart';
import 'supabase_history_repository.dart';

/// Override di tes dengan repository palsu.
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => SupabaseHistoryRepository(ref.watch(supabaseClientProvider)),
);

/// Jam untuk label hari ("Hari ini", "Kemarin"). Override di tes.
final historyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Riwayat 48 jam milik pengguna yang sedang masuk, terbaru dulu. Dimuat ulang
/// tiap halaman dibuka dan bila pengguna ganti.
final locationHistoryProvider = FutureProvider.autoDispose<List<HistoryPoint>>((
  ref,
) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(historyRepositoryProvider).fetchLast48h();
}, retry: (_, _) => null);
