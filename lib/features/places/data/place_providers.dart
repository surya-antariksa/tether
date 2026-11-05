import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/place.dart';
import '../domain/place_repository.dart';
import 'supabase_place_repository.dart';

/// Override di tes dengan repository palsu.
final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => SupabasePlaceRepository(ref.watch(supabaseClientProvider)),
);

/// Tempat satu Circle. Mutasi memuat ulang daftar dari server (sumber
/// kebenaran) tanpa kilatan loading. Melempar PlaceError dari repository.
final placesProvider =
    AsyncNotifierProvider.family<PlacesNotifier, List<Place>, String>(
      PlacesNotifier.new,
      isAutoDispose: true,
      retry: (_, _) => null, // pengguna memicu ulang lewat tombol
    );

class PlacesNotifier extends AsyncNotifier<List<Place>> {
  PlacesNotifier(this.circleId);

  final String circleId;

  @override
  Future<List<Place>> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(placeRepositoryProvider).places(circleId);
  }

  /// Ambil ulang tanpa loading. Galat diabaikan (data lama tetap).
  Future<void> refresh() async {
    try {
      final places = await ref.read(placeRepositoryProvider).places(circleId);
      if (ref.mounted) state = AsyncData(places);
    } catch (_) {
      // data lama tetap
    }
  }

  Future<String> create({
    required String name,
    required LatLng center,
    required int radiusM,
  }) async {
    final repo = ref.read(placeRepositoryProvider);
    try {
      final id = await repo.createPlace(
        circleId: circleId,
        name: name,
        center: center,
        radiusM: radiusM,
      );
      await refresh();
      return id;
    } catch (_) {
      // Daftar lokal bisa basi (mis. batas penuh oleh anggota lain).
      await refresh();
      rethrow;
    }
  }

  Future<void> edit(
    String placeId, {
    required String name,
    required int radiusM,
  }) async {
    try {
      await ref
          .read(placeRepositoryProvider)
          .updatePlace(placeId: placeId, name: name, radiusM: radiusM);
    } finally {
      await refresh();
    }
  }

  Future<void> delete(String placeId) async {
    try {
      await ref.read(placeRepositoryProvider).deletePlace(placeId);
    } finally {
      await refresh();
    }
  }
}

/// Apakah pengguna admin di Circle ini. Galat dianggap bukan admin (server
/// tetap memutuskan; hanya menyembunyikan aksi).
final isCircleAdminProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  circleId,
) async {
  ref.watch(currentUserIdProvider);
  try {
    return await ref.watch(placeRepositoryProvider).isAdmin(circleId);
  } catch (_) {
    return false;
  }
});
