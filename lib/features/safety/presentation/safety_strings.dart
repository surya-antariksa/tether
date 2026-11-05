import '../domain/safety_error.dart';
import '../domain/safety_repository.dart';

/// Teks UI check-in dan SOS (bahasa Indonesia).
abstract final class SafetyStrings {
  static const entryLabel = 'Keselamatan: check-in dan SOS';
  static const sheetTitle = 'Keselamatan';
  static const close = 'Tutup';

  // Check-in
  static const checkinHeader = 'Check-in';
  static const checkinHint = 'Beri tahu Circle bahwa kamu baik-baik saja.';
  static const arrived = 'Saya sudah sampai';
  static const safe = 'Saya aman';
  static const checkinSending = 'Mengirim check-in';
  static const noCircleSelected = 'Pilih Circle dulu untuk check-in.';

  static String label(CheckinKind kind) => switch (kind) {
    CheckinKind.arrived => arrived,
    CheckinKind.safe => safe,
  };

  static String checkinDone(CheckinKind kind) =>
      'Terkirim ke Circle: ${label(kind)}.';

  static String checkinError(SafetyErrorKind kind) => switch (kind) {
    SafetyErrorKind.rateLimited =>
      'Check-in terlalu sering. Coba lagi dalam 30 detik.',
    SafetyErrorKind.notMember ||
    SafetyErrorKind.noCircle => 'Kamu bukan anggota Circle ini.',
    SafetyErrorKind.notSignedIn => 'Sesi berakhir. Masuk lagi lalu coba.',
    SafetyErrorKind.network =>
      'Tidak ada koneksi. Check-in belum terkirim, coba lagi.',
    _ => 'Check-in gagal. Coba lagi.',
  };

  // SOS
  static const sosHeader = 'SOS';
  static const sosDisclaimer =
      'SOS bukan pengganti layanan darurat. Dalam keadaan darurat, hubungi '
      'layanan darurat setempat (di Indonesia: 112).';
  static const sosExplain =
      'SOS mengirim lokasimu saat ini ke semua Circle-mu. Tahan tombol 3 '
      'detik, lalu ada hitung mundur 5 detik yang bisa dibatalkan.';
  static const holdIdle = 'Tahan 3 detik untuk SOS';
  static const holdActive = 'Terus tahan…';
  static const holdLabel = 'SOS';
  static const holdHint =
      'Tahan 3 detik untuk memulai hitung mundur SOS. Pengguna pembaca '
      'layar bisa memakai aksi Mulai SOS.';
  static const startActionLabel = 'Mulai SOS dengan hitung mundur 5 detik';
  static const startWithoutHold = 'Mulai SOS (hitung mundur 5 detik)';

  static String countdownTitle(int seconds) =>
      'SOS dikirim dalam $seconds detik';
  static const countdownBody =
      'Ketuk Batalkan bila ini tidak sengaja. Tidak ada yang terkirim '
      'sebelum hitungan selesai.';
  static String countdownAnnouncement(int seconds) =>
      'SOS dikirim dalam $seconds detik. Ketuk Batalkan untuk membatalkan.';
  static const cancel = 'Batalkan';
  static const sending = 'Mengirim SOS';
  static const sendingBody = 'Mengambil lokasi dan mengirim ke Circle-mu.';
  static const sentTitle = 'SOS terkirim';
  static String sentBody(int circles) => circles <= 1
      ? 'Circle-mu sudah diberi tahu lewat notifikasi beserta lokasimu.'
      : '$circles Circle sudah diberi tahu lewat notifikasi beserta lokasimu.';
  static const queuedTitle = 'SOS belum terkirim';
  static const queuedBody =
      'Tidak ada koneksi. SOS disimpan dan dicoba lagi otomatis sampai '
      'terkirim. Jika mendesak, hubungi layanan darurat setempat (112).';
  static const failedTitle = 'SOS tidak terkirim';
  static const done = 'Selesai';

  static const noLocation =
      'Lokasi tidak tersedia. Aktifkan GPS dan izin lokasi untuk Tether, '
      'lalu coba lagi.';

  static String sosError(SafetyErrorKind kind) => switch (kind) {
    SafetyErrorKind.rateLimited =>
      'Terlalu sering memicu SOS (maksimal 3 kali per 10 menit). SOS '
          'sebelumnya sudah terkirim ke Circle-mu.',
    SafetyErrorKind.noCircle =>
      'Kamu belum punya Circle, jadi tidak ada yang bisa diberi tahu. Buat '
          'atau gabung Circle dulu.',
    SafetyErrorKind.notMember => 'Kamu bukan anggota Circle ini.',
    SafetyErrorKind.notSignedIn => 'Sesi berakhir. Masuk lagi lalu coba.',
    SafetyErrorKind.invalidArgument =>
      'Lokasi ditolak server karena tidak valid. Coba lagi.',
    SafetyErrorKind.expired =>
      'SOS tertunda terlalu lama dan dibatalkan. Picu SOS lagi bila masih '
          'perlu.',
    SafetyErrorKind.notSaved =>
      'SOS belum terkirim dan tidak tersimpan, coba lagi atau hubungi '
          'layanan darurat.',
    SafetyErrorKind.network =>
      'SOS belum terkirim karena koneksi bermasalah. Coba lagi.',
    _ => 'SOS gagal terkirim. Coba lagi.',
  };

  static const sosRejectedNotificationTitle = 'SOS tidak terkirim';

  static const emergencyHint =
      'Jika mendesak, hubungi layanan darurat setempat (112).';
}
