import '../domain/auth_repository.dart';
import '../domain/auth_validators.dart';

/// Teks UI fitur auth (bahasa Indonesia). Pesan galat sengaja umum: tanpa
/// detail teknis dan tanpa menyebut email.
abstract final class AuthStrings {
  static const title = 'Tether';
  static const subtitle = 'Berbagi lokasi dengan keluarga, dengan tenang.';

  static const modeSignIn = 'Masuk';
  static const modeSignUp = 'Daftar';

  static const emailLabel = 'Email';
  static const emailPlaceholder = 'nama@contoh.com';
  static const passwordLabel = 'Kata sandi';
  static const passwordPlaceholder = 'Minimal 8 karakter';
  static const nameLabel = 'Nama tampilan';
  static const namePlaceholder = 'Nama yang dilihat keluarga';

  static const submitSignIn = 'Masuk';
  static const submitSignUp = 'Buat akun';
  static const processing = 'Memproses';

  static const confirmTitle = 'Verifikasi Sesi Akun';
  static const confirmSubtitle =
      'Menyinkronkan data lokasi dan menghubungkan perangkat Anda ke Circle keluarga.';
  static const confirmConnecting = 'Menghubungkan ke Circle...';
  static const confirmReady = 'Siap terhubung';
  static const verifying = 'Memverifikasi akun...';
  static const stepCredentials = 'Memeriksa kredensial';
  static const stepProfile = 'Menyinkronkan profil';
  static const stepCircles = 'Menghubungkan ke Circle';
  static const confirmFailed = 'Circle belum bisa dimuat';
  static const confirmYou = 'Kamu';
  static String confirmCircles(int n) => '$n Circle Aktif';
  static const confirmNoCircle = 'Belum ada Circle';
  static const confirmContinue = 'Lanjutkan ke Peta';
  static const confirmSwitch = 'Ganti Akun / Batal';
  static const confirmSecure = 'Koneksi terenkripsi (TLS)';
  static const forgotPasswordLink = 'Lupa kata sandi?';
  static const nameFieldLabel = 'Nama Panggilan';
  static const nameFieldHint = 'Tampil di peta keluarga';
  static const passwordFieldLabel = 'Kata Sandi';
  static const or = 'atau';
  static const continueWithGoogle = 'Lanjutkan dengan Google';
  static const termsPrefix = 'Dengan melanjutkan, Anda menyetujui ';
  static const termsOfService = 'Ketentuan Layanan';
  static const termsAnd = ' dan ';
  static const privacyPolicy = 'Kebijakan Privasi';
  static const termsSuffix = ' Tether.';
  static const forgotPasswordTitle = 'Lupa Kata Sandi';
  static const forgotPasswordSubtitle =
      'Masukkan email yang terdaftar untuk menerima tautan pemulihan kata sandi.';
  static const sendResetLink = 'Kirim Tautan Pemulihan';
  static const resetEmailSent =
      'Tautan pemulihan telah dikirim. Periksa kotak masuk atau spam email Anda.';
  static const e2eTrust = 'Terenkripsi E2E • Lokasi privat hanya dalam Circle';
  static const cancel = 'Batal';

  static const confirmationRequired =
      'Akun dibuat. Periksa kotak masuk Anda untuk verifikasi, lalu masuk.';

  static String fieldError(AuthFieldError e) => switch (e) {
    AuthFieldError.emailInvalid => 'Masukkan email yang valid.',
    AuthFieldError.passwordTooShort => 'Kata sandi minimal 8 karakter.',
    AuthFieldError.nameEmpty => 'Nama tidak boleh kosong.',
    AuthFieldError.nameTooLong => 'Nama maksimal 40 karakter.',
  };

  static String failure(AuthFailureKind k) => switch (k) {
    AuthFailureKind.invalidCredentials => 'Email atau kata sandi tidak cocok.',
    AuthFailureKind.emailNotConfirmed =>
      'Email belum diverifikasi. Periksa kotak masuk Anda.',
    AuthFailureKind.weakPassword =>
      'Kata sandi terlalu mudah ditebak. Coba yang lebih kuat.',
    AuthFailureKind.rateLimited =>
      'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.',
    AuthFailureKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda.',
    AuthFailureKind.signUpFailed =>
      'Akun tidak bisa dibuat. Periksa data Anda atau coba masuk.',
    AuthFailureKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };
}
