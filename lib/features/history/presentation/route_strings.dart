/// Teks UI putar rute, detail titik, dan perbandingan rute (bahasa Indonesia).
abstract final class RouteStrings {
  // Entri di halaman riwayat
  static const play = 'Putar Rute';
  static const compare = 'Bandingkan';
  static const compareNeedTwoDays =
      'Perlu data dari dua hari berbeda untuk membandingkan.';

  // Putar rute
  static const playbackTitle = 'Putar Rute';
  static const playbackBadge = 'Dari riwayat Anda';
  static const pause = 'Jeda';
  static const resume = 'Putar';
  static const restart = 'Ulang dari awal';
  static const speedLabel = 'Kecepatan putar';
  static const progressLabel = 'Posisi putar rute';
  static const timeNow = 'Waktu';
  static const speedNow = 'Kecepatan';
  static const stillLabel = 'Diam';
  static const movingLabel = 'Bergerak';
  static const stopsTitle = 'Perhentian';
  static const stopsNone = 'Tidak ada perhentian lebih dari 5 menit.';
  static String stopsCount(int n) => '$n perhentian';
  static String stopLine(String clock, int minutes) =>
      'Berhenti sejak $clock, $minutes menit';
  static const exitPlayback = 'Keluar dari Mode Putar';
  static const statsTitle = 'Ringkasan Perjalanan';
  static const distance = 'Jarak';
  static const duration = 'Durasi';
  static const movingTime = 'Waktu bergerak';
  static const avgSpeed = 'Rata-rata';
  static const maxSpeed = 'Maksimum';
  static const points = 'Titik';
  static const noData = 'Belum ada titik untuk diputar.';
  static const kmh = 'km/jam';

  // Detail titik
  static const detailTitle = 'Detail Titik';
  static const coordinates = 'Koordinat';
  static const copyCoordinates = 'Salin koordinat';
  static const copied = 'Tersalin';
  static const time = 'Waktu tercatat';
  static const status = 'Status';
  static const accuracy = 'Akurasi';
  static const battery = 'Baterai';
  static const speed = 'Kecepatan';
  static const unavailable = 'Tidak tercatat';
  static const movementTitle = 'Urutan Pergerakan';
  static const previousPoint = 'Titik sebelumnya';
  static const thisPoint = 'Titik ini';
  static const noPrevious = 'Ini titik terawal dalam daftar.';
  static const makePlace = 'Jadikan Tempat Tersimpan';
  static const showOnMap = 'Lihat di Peta';
  static String sincePrevious(int meters, String gap) =>
      '$meters m dalam $gap dari titik sebelumnya';

  // Perbandingan
  static const compareTitle = 'Perbandingan Rute';
  static const dayA = 'Hari A';
  static const dayB = 'Hari B';
  static const chooseDay = 'Pilih hari';
  static const cancel = 'Batal';
  static const tracksLegend = 'Jejak dua hari di peta';
  static const deltaTitle = 'Selisih (B dibanding A)';
  static const moreThan = 'lebih';
  static const lessThan = 'kurang';
  static const same = 'sama';
}
