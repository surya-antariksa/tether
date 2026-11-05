enum AuthFieldError { emailInvalid, passwordTooShort, nameEmpty, nameTooLong }

/// Validasi form auth. Mengembalikan null bila valid.
abstract final class AuthValidators {
  static const minPasswordLength = 8;
  static const maxNameLength = 40;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static AuthFieldError? email(String? value) =>
      _email.hasMatch((value ?? '').trim())
      ? null
      : AuthFieldError.emailInvalid;

  static AuthFieldError? password(String? value) =>
      (value ?? '').length >= minPasswordLength
      ? null
      : AuthFieldError.passwordTooShort;

  /// Nama tampilan 1..40 karakter setelah dipangkas.
  static AuthFieldError? displayName(String? value) {
    final length = (value ?? '').trim().length;
    if (length == 0) return AuthFieldError.nameEmpty;
    if (length > maxNameLength) return AuthFieldError.nameTooLong;
    return null;
  }
}
