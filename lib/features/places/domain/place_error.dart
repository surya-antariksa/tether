enum PlaceErrorKind {
  /// TH005: Circle sudah punya 5 tempat.
  limitReached,

  /// 42501 saat membuat: bukan anggota Circle.
  notMember,

  /// 42501 saat ubah/hapus: bukan pembuat dan bukan admin.
  notAllowed,

  /// P0002: tempat tidak ada (atau pemanggil bukan anggota).
  notFound,

  /// 22023: nama, radius, atau titik tidak valid.
  invalid,
  notSignedIn,
  network,
  unknown,
}

/// Galat tempat yang sudah dipetakan dari kode galat database. UI tidak
/// pernah melihat PostgrestException, dan galat tidak memuat koordinat.
class PlaceError implements Exception {
  const PlaceError(this.kind);

  final PlaceErrorKind kind;

  @override
  String toString() => 'PlaceError($kind)';
}
