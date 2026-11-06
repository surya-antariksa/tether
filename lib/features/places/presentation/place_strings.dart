import '../domain/place.dart';
import '../domain/place_error.dart';

/// Teks UI fitur Tempat (bahasa Indonesia).
abstract final class PlaceStrings {
  static const title = 'Tempat';
  static const openFromMap = 'Kelola tempat';
  static const close = 'Tutup';
  static const cancel = 'Batal';
  static const ok = 'OK';
  static const retry = 'Coba lagi';
  static const loadFailed = 'Daftar tempat tidak bisa dimuat.';

  // Daftar
  static const savedCountZero = '0 Tempat Disimpan';
  static const quickSuggestions = 'Rekomendasi cepat';
  static const tapToSet = 'Sentuh untuk set';
  static const suggestHome = 'Rumah';
  static const suggestHomeHint = 'Lokasi utama';
  static const suggestSchool = 'Sekolah';
  static const suggestSchoolHint = 'Rute rutin';
  static const suggestFav = 'Favorit';
  static const suggestFavHint = 'Kustom';
  static const geofenceNote =
      'Kabar tiba dan pergi otomatis saat anggota melewati tempat ini';
  static const emptyTitle = 'Belum ada tempat';
  static const emptyBody =
      'Tandai tempat penting seperti rumah atau sekolah. Anggota Circle '
      'mendapat kabar saat ada yang tiba atau pergi.';
  static String count(int n) => '$n dari ${PlaceLimits.maxPerCircle} tempat';
  static const add = 'Tambah';
  static const addPlace = 'Tambah tempat';
  static const limitNote =
      'Batas ${PlaceLimits.maxPerCircle} tempat per Circle tercapai. '
      'Hapus satu tempat untuk menambah yang baru.';
  static const manageHint = 'Ketuk untuk mengubah atau menghapus';
  static String radiusOf(int meters) => 'Radius ${formatRadius(meters)}';
  static String rowLabel(Place p, {required bool canManage}) =>
      '${p.name}, ${radiusOf(p.radiusM)}'
      '${canManage ? ', ketuk untuk mengubah' : ''}';

  // Pemilih titik
  static const pickTitle = 'Tambah tempat';
  static const pickHint =
      'Ketuk atau tahan peta untuk memilih titik tempat. Kamu juga bisa '
      'memakai tombol di pojok kanan atas untuk memilih titik tengah peta.';
  static const useMapCenter = 'Pilih titik tengah peta';
  static const draftPinLabel = 'Titik tempat yang dipilih';
  static const movePinHint = 'Ketuk peta lagi untuk memindahkan titik.';

  // Form
  static const nameLabel = 'Nama tempat';
  static const namePlaceholder = 'Mis. Rumah, Sekolah';
  static const radiusLabel = 'Radius';
  static String radiusValue(int meters) => formatRadius(meters);
  static String radiusSemantic(int meters) => formatRadius(
    meters,
  ).replaceAll(' m', ' meter').replaceAll(' km', ' kilometer');
  static const nameEmpty = 'Nama tempat tidak boleh kosong.';
  static const nameTooLong =
      'Nama tempat maksimal ${PlaceLimits.nameMaxLength} karakter.';
  static String nameIssue(PlaceNameIssue i) => switch (i) {
    PlaceNameIssue.empty => nameEmpty,
    PlaceNameIssue.tooLong => nameTooLong,
  };
  static const save = 'Simpan';
  static const saving = 'Menyimpan';

  // Ubah dan hapus
  static const editTitle = 'Ubah tempat';
  static const delete = 'Hapus tempat';
  static const deleting = 'Menghapus';
  static const deleteConfirmTitle = 'Hapus tempat?';
  static String deleteConfirmMessage(String name) =>
      '"$name" akan dihapus. Riwayat aktivitas lama tetap ada, tetapi '
      'anggota tidak lagi mendapat kabar tiba atau pergi di tempat ini.';

  // Peta
  static String mapLabel(Place p) => 'Tempat ${p.name}, ${radiusOf(p.radiusM)}';

  static const errorTitle = 'Gagal';

  static String error(PlaceErrorKind k) => switch (k) {
    PlaceErrorKind.limitReached =>
      'Circle ini sudah punya ${PlaceLimits.maxPerCircle} tempat. '
          'Hapus satu tempat sebelum menambah yang baru.',
    PlaceErrorKind.notMember => 'Kamu bukan anggota Circle ini lagi.',
    PlaceErrorKind.notAllowed =>
      'Hanya pembuat tempat atau admin Circle yang bisa mengubah atau '
          'menghapus tempat ini.',
    PlaceErrorKind.notFound => 'Tempat tidak ditemukan. Mungkin sudah dihapus.',
    PlaceErrorKind.invalid =>
      'Data tempat tidak valid. Nama harus 1 sampai '
          '${PlaceLimits.nameMaxLength} karakter dan radius '
          '${PlaceLimits.minRadiusM} sampai ${PlaceLimits.maxRadiusM} meter.',
    PlaceErrorKind.notSignedIn => 'Sesi berakhir. Masuk lagi untuk lanjut.',
    PlaceErrorKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet Anda.',
    PlaceErrorKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };
}
