import '../domain/account_repository.dart';

/// Teks UI halaman hapus akun (bahasa Indonesia).
abstract final class DeleteAccountStrings {
  static const title = 'Hapus akun';

  static const heading = 'Hapus akun Tether Anda?';
  static const intro =
      'Akun Anda dinonaktifkan sekarang dan Anda tidak bisa masuk lagi dengan '
      'akun ini.';
  static const whatSection = 'Yang dihapus';
  static const permanent = 'Permanen';
  static const items = [
    'Riwayat lokasi dan posisi terakhir Anda.',
    'Check-in dan SOS yang pernah Anda kirim.',
    'Perangkat terdaftar dan antrean notifikasi Anda.',
    'Keanggotaan di semua Circle. Bila Anda anggota terakhir, Circle ikut '
        'dihapus; bila Anda admin, peran dialihkan ke anggota lain.',
  ];
  static const grace =
      'Profil dan akun Anda dihapus tuntas dalam 30 hari. Selama itu akun '
      'tidak bisa dipakai masuk.';

  static const button = 'Hapus akun saya';
  static const busyLabel = 'Menghapus akun';

  static const step1Title = 'Hapus akun?';
  static const step1Message =
      'Semua data lokasi Anda dihapus, Anda keluar dari semua Circle, dan '
      'akun tidak bisa dipakai masuk lagi. Tindakan ini tidak bisa dibatalkan.';
  static const next = 'Lanjutkan';

  /// Kata yang harus diketik pada konfirmasi kedua.
  static const confirmWord = 'HAPUS';
  static const step2Title = 'Konfirmasi terakhir';
  static const step2Message = 'Ketik $confirmWord untuk menghapus akun.';
  static const fieldPlaceholder = confirmWord;
  static const fieldLabel = 'Ketik $confirmWord untuk konfirmasi';
  static const confirm = 'Hapus akun';
  static const cancel = 'Batal';

  static const errorTitle = 'Gagal menghapus akun';
  static const ok = 'Tutup';
  static const signOutFailed =
      'Akun sudah dihapus, tetapi keluar dari aplikasi gagal. Pilih Keluar di '
      'tab Profil.';

  static String failure(AccountFailureKind k) => switch (k) {
    AccountFailureKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda lalu coba lagi.',
    AccountFailureKind.unauthorized =>
      'Sesi Anda berakhir. Masuk lagi lalu coba hapus akun.',
    AccountFailureKind.notFound => 'Akun tidak ditemukan.',
    AccountFailureKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };
}
