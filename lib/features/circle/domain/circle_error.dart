enum CircleErrorKind {
  /// Kode kosong/salah/kedaluwarsa/dicabut/habis (tidak dibedakan).
  invalidCode,
  tooManyAttempts,
  circleFull,
  circleLimit,
  notAdmin,
  notMember,
  notFound,
  invalidArgument,
  notSignedIn,
  network,
  unknown,
}

/// Galat Circle yang sudah dipetakan dari kode galat database. UI tidak
/// pernah melihat PostgrestException.
class CircleError implements Exception {
  const CircleError(this.kind);

  final CircleErrorKind kind;

  @override
  String toString() => 'CircleError($kind)';
}
