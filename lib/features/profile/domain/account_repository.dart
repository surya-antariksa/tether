enum AccountFailureKind { network, unauthorized, notFound, unknown }

/// Galat akun yang sudah dipetakan, tanpa detail teknis.
class AccountFailure implements Exception {
  const AccountFailure(this.kind);

  final AccountFailureKind kind;

  @override
  String toString() => 'AccountFailure($kind)';
}

abstract interface class AccountRepository {
  /// Hapus akun (RPC delete_account): akun dinonaktifkan segera, data lokasi
  /// dan perangkat dihapus, sesi dicabut; penghapusan tuntas setelah 30 hari.
  /// Melempar [AccountFailure].
  Future<void> deleteAccount();
}
