import '../domain/circle.dart';
import '../domain/circle_error.dart';

/// Teks UI fitur Circle (bahasa Indonesia).
abstract final class CircleStrings {
  static const title = 'Circle';

  // Keadaan kosong
  static const emptyTitle = 'Belum ada Circle';
  static const emptyBody =
      'Circle adalah kelompok keluarga yang saling berbagi lokasi. '
      'Buat satu, atau gabung dengan kode dari keluargamu.';
  static const create = 'Buat Circle';
  static const joinWithCode = 'Gabung dengan kode';

  // Header dan daftar
  static const add = 'Tambah Circle';
  static const createNew = 'Buat Circle baru';
  static const switchCircle = 'Ganti Circle';
  static const switchLabel = 'Circle aktif';
  static const membersSection = 'Anggota';
  static String memberCount(int n) => '$n anggota';
  static const roleAdmin = 'Admin';
  static const roleMember = 'Anggota';
  static String role(CircleRole r) =>
      r == CircleRole.admin ? roleAdmin : roleMember;
  static const you = '(Kamu)';

  static const statusSharing = 'Berbagi lokasi';
  static const statusPaused = 'Menjeda berbagi lokasi';
  static const statusOff = 'Berbagi lokasi dimatikan';
  static String status(SharingStatus s) => switch (s) {
    SharingStatus.sharing => statusSharing,
    SharingStatus.paused => statusPaused,
    SharingStatus.off => statusOff,
  };

  static String memberLabel(String name, CircleRole r, SharingStatus s) =>
      '$name, ${role(r)}, ${status(s)}';

  // Undang
  static const invite = 'Undang';
  static const inviting = 'Membuat undangan';
  static const inviteTitle = 'Kode undangan';
  static String inviteCodeLabel(String code) =>
      'Kode undangan: ${code.split('').join(' ')}';
  static String inviteExpires(String when) => 'Berlaku sampai $when';
  static const inviteNote =
      'Kode berlaku 48 jam dan menggantikan kode sebelumnya.';
  static const copy = 'Salin kode';
  static const copied = 'Kode tersalin';
  static const done = 'Selesai';

  // Keluar dan keluarkan
  static const leave = 'Keluar dari Circle';
  static String leaveTitle(String name) => 'Keluar dari $name?';
  static const leaveMessage =
      'Kamu tidak akan melihat lokasi anggota lagi. Untuk bergabung lagi, '
      'kamu perlu kode undangan baru.';
  static const leaveLastMessage =
      'Kamu anggota terakhir, jadi Circle ini akan dihapus.';
  static const leaveAction = 'Keluar';
  static const remove = 'Keluarkan';
  static String removeLabel(String name) => 'Keluarkan $name';
  static String removeTitle(String name) => 'Keluarkan $name?';
  static const removeMessage =
      'Dia tidak akan lagi melihat atau dilihat di Circle ini.';

  // Gabung
  static const joinTitle = 'Gabung dengan kode';
  static const joinHint = 'Masukkan kode 6 karakter dari keluargamu.';
  static const codeLabel = 'Kode undangan';
  static const codePlaceholder = 'Kode 6 karakter';
  static const codeIncomplete = 'Kode terdiri dari 6 karakter.';
  static const next = 'Lanjut';
  static const processing = 'Memproses';
  static String joinConfirm(String name, int n) =>
      'Gabung ke $name? ($n anggota)';
  static const joinAction = 'Gabung';

  // Buat
  static const createTitle = 'Buat Circle';
  static const nameLabel = 'Nama Circle';
  static const namePlaceholder = 'Mis. Keluarga';
  static const nameEmpty = 'Nama tidak boleh kosong.';
  static const nameTooLong = 'Nama maksimal 40 karakter.';
  static const createAction = 'Buat';

  // Umum
  static const cancel = 'Batal';
  static const retry = 'Coba lagi';
  static const loadFailed = 'Circle tidak bisa dimuat.';
  static const membersLoadFailed = 'Anggota tidak bisa dimuat.';
  static const errorTitle = 'Gagal';
  static const ok = 'Tutup';

  static String error(CircleErrorKind k) => switch (k) {
    CircleErrorKind.invalidCode => 'Kode tidak valid atau kedaluwarsa',
    CircleErrorKind.tooManyAttempts =>
      'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.',
    CircleErrorKind.circleFull => 'Circle ini sudah penuh.',
    CircleErrorKind.circleLimit => 'Kamu sudah mencapai batas jumlah Circle.',
    CircleErrorKind.notAdmin => 'Hanya admin yang bisa melakukan ini.',
    CircleErrorKind.notMember => 'Kamu bukan anggota Circle ini.',
    CircleErrorKind.notFound => 'Data tidak ditemukan.',
    CircleErrorKind.invalidArgument => 'Data yang dimasukkan tidak valid.',
    CircleErrorKind.notSignedIn =>
      'Sesi berakhir. Masuk lagi untuk melanjutkan.',
    CircleErrorKind.network =>
      'Tidak bisa terhubung. Periksa koneksi internet kamu.',
    CircleErrorKind.unknown => 'Terjadi masalah. Coba lagi nanti.',
  };

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Mis. '6 Nov 2026, 14.30' (waktu lokal).
  static String formatWhen(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.day} ${_months[l.month - 1]} ${l.year}, ${two(l.hour)}.${two(l.minute)}';
  }
}
