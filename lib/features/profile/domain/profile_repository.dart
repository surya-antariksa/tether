import 'profile.dart';

enum ProfileFailureKind { notFound, network, unknown }

/// Galat profil yang sudah dipetakan, tanpa detail teknis.
class ProfileFailure implements Exception {
  const ProfileFailure(this.kind);

  final ProfileFailureKind kind;

  @override
  String toString() => 'ProfileFailure($kind)';
}

abstract interface class ProfileRepository {
  /// Baca baris profil milik pengguna yang sedang masuk.
  Future<Profile> fetchOwn();

  /// Ubah nama (1..40 karakter) dan/atau warna ('#RRGGBB') profil sendiri.
  /// Mengembalikan baris terbaru. Tidak ada INSERT: baris dibuat trigger.
  Future<Profile> updateOwn({String? displayName, String? color});
}
