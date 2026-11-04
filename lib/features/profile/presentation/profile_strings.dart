import '../domain/profile_repository.dart';

/// Teks UI fitur profil (bahasa Indonesia).
abstract final class ProfileStrings {
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
  static const signOutMessage =
      'Anda perlu masuk lagi untuk melihat lokasi keluarga.';

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
