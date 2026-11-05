import 'package:latlong2/latlong.dart';

import 'place.dart';

abstract interface class PlaceRepository {
  /// Tempat satu Circle, urut menurut waktu dibuat. Melempar [PlaceError].
  Future<List<Place>> places(String circleId);

  /// Apakah pengguna admin di Circle ini. Melempar [PlaceError].
  Future<bool> isAdmin(String circleId);

  /// Mengembalikan id tempat baru. Melempar [PlaceError] (mis. limitReached).
  Future<String> createPlace({
    required String circleId,
    required String name,
    required LatLng center,
    required int radiusM,
  });

  /// Posisi tidak bisa diubah (hapus lalu buat ulang).
  Future<void> updatePlace({
    required String placeId,
    required String name,
    required int radiusM,
  });

  Future<void> deletePlace(String placeId);
}
