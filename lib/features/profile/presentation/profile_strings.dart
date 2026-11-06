import '../domain/profile_repository.dart';
import '../domain/notification_settings.dart'
    show NotificationSettingsFailureKind;

/// Teks UI fitur profil (bahasa Indonesia).
abstract final class ProfileStrings {
  static const subtitle =
      'Kelola visibilitas, warna penanda, dan privasi akun Anda';
  static const settingsSection = 'Pengaturan & riwayat';
  static const appearanceSection = 'Tampilan';
  static const appearanceTitle = 'Tema aplikasi';
  static const appearanceHint =
      'Pilih terang, gelap, atau ikuti pengaturan perangkat.';
  static const themeSystem = 'Sistem';
  static const themeLight = 'Terang';
  static const themeDark = 'Gelap';
  static const title = 'Profil';

  static const nameSection = 'Nama tampilan';
  static const editName = 'Ubah nama';
  static const nameDialogTitle = 'Ubah nama';
  static const namePlaceholder = 'Nama yang dilihat keluarga';
  static const nameEmpty = 'Nama tidak boleh kosong.';
  static const nameTooLong = 'Nama maksimal 40 karakter.';

  static const colorSection = 'Warna penanda';
  static const colorFooter = 'Warna ini menandai Anda di peta keluarga.';

  /// Nama warna sesuai urutan MemberColors.hexes.
  static const colorNames = [
    'Teal',
    'Biru',
    'Oranye',
    'Pink',
    'Ungu',
    'Hijau',
    'Amber',
    'Abu-abu',
  ];
  static String colorLabel(String name) => 'Warna $name';
  static const colorSelected = 'Dipilih';

  static const save = 'Simpan';
  static const cancel = 'Batal';

  static const signOut = 'Keluar';
  static const signOutTitle = 'Keluar dari Tether?';
  static const signOutNote = 'Sesi di perangkat ini akan dinonaktifkan';
  static const signOutMessage =
      'Anda perlu masuk lagi untuk melihat lokasi keluarga.';

  static const accountSection = 'Akun';
  static String accountLabel(String email) => 'Akun $email';

  static const historyRow = 'Riwayat lokasi';
  static const historySubtitle = '30 hari terakhir, bisa dihapus';

  static const notificationRow = 'Notifikasi';
  static const notificationSubtitle = 'Pemberitahuan event keluarga';
  static const notificationTitle = 'Notifikasi';
  static const notifArriveLeave = 'Tiba dan pergi';
  static const notifArriveLeaveHint = 'Anggota tiba di atau pergi dari tempat';
  static const notifCheckin = 'Check-in';
  static const notifCheckinHint = 'Kabar "sudah sampai" dan "aman"';
  static const notifMemberChanges = 'Perubahan anggota';
  static const notifMemberChangesHint =
      'Bergabung, keluar, jeda, dan sakelar berbagi';
  static const notifSosNote = 'SOS selalu dikirim dan tidak bisa dimatikan.';
  static const notifLoadFailed = 'Pengaturan tidak bisa dimuat.';
  static String notifFailure(NotificationSettingsFailureKind k) => switch (k) {
    NotificationSettingsFailureKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda.',
    NotificationSettingsFailureKind.unauthenticated =>
      'Sesi berakhir. Keluar lalu masuk lagi.',
    NotificationSettingsFailureKind.unknown =>
      'Terjadi masalah. Coba lagi nanti.',
  };

  static const deleteAccount = 'Hapus akun';
  static const privacyNote =
      'Titik lokasi disimpan 30 hari lalu dihapus otomatis. Bila akun dihapus, '
      'data Anda dibuang tuntas dalam 30 hari.';

  static const retry = 'Coba lagi';
  static const loadFailed = 'Profil tidak bisa dimuat.';

  static String failure(ProfileFailureKind k) => switch (k) {
    ProfileFailureKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda.',
    ProfileFailureKind.notFound => 'Profil tidak ditemukan.',
    ProfileFailureKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };
  static const errorTitle = 'Gagal menyimpan';
  static const ok = 'Tutup';

  static String avatarLabel(String name) => 'Avatar $name';
}
