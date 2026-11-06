/// Hasil pendaftaran: langsung masuk, atau perlu verifikasi email dulu.
enum SignUpOutcome { signedIn, confirmationRequired }

enum AuthFailureKind {
  invalidCredentials,
  emailNotConfirmed,
  weakPassword,
  rateLimited,
  network,

  /// Gagal daftar tanpa membocorkan alasan (mis. email sudah terpakai).
  signUpFailed,
  unknown,
}

/// Galat auth yang sudah dipetakan, tanpa detail teknis atau email.
class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  @override
  String toString() => 'AuthFailure($kind)';
}

abstract interface class AuthRepository {
  /// Id pengguna dari sesi yang dipulihkan, atau null bila belum masuk.
  String? get currentUserId;

  /// Id pengguna tiap status auth berubah (null = keluar).
  Stream<String?> get userIdChanges;

  /// Daftar dengan email, kata sandi, dan nama tampilan.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signIn({required String email, required String password});

  /// Mengirim tautan pemulihan kata sandi ke email pengguna.
  Future<void> resetPassword({required String email});

  Future<void> signOut();
}
