/// Teks UI fitur tracking (bahasa Indonesia). Tidak ada teks yang memuat
/// koordinat. Teks alasan izin: satu kalimat, huruf besar hanya di awal,
/// diakhiri titik (docs/08 bagian 7).
abstract final class TrackingStrings {
  // Teks alasan izin.
  static const reasonWhenInUse =
      'Tether menampilkan posisimu di peta Circle keluarga.';
  static const reasonAlways =
      'Tether membagikan lokasimu ke Circle keluarga saat aplikasi ditutup, '
      'supaya keluarga tahu kamu sampai dengan selamat.';
  static const reasonNotification =
      'Tether mengirim pemberitahuan saat anggota keluarga tiba, pergi, atau '
      'mengirim SOS.';

  // Onboarding.
  static const next = 'Lanjut';
  static const done = 'Selesai';
  static const openSettings = 'Buka pengaturan aplikasi';
  static const processing = 'Memproses';

  static const whenInUseTitle = 'Bagikan lokasimu ke keluarga';
  static const whenInUsePoints = [
    'Hanya anggota Circle kamu yang bisa melihat lokasimu.',
    'Kamu bisa menjeda berbagi lokasi kapan saja.',
    'Titik lokasi dihapus otomatis setelah 30 hari.',
  ];

  static const alwaysTitle = 'Tetap berbagi saat aplikasi ditutup';
  static const alwaysHint =
      'Sistem akan menanyakan izin lokasi sepanjang waktu. Pilih opsi yang '
      'mengizinkan lokasi sepanjang waktu agar berbagi tetap berjalan.';

  static const notificationTitle = 'Kabar dari keluarga';

  static const locationDeniedTitle = 'Lokasi belum diizinkan';
  static const locationDeniedBody =
      'Tanpa izin lokasi, Tether tidak bisa membagikan lokasimu ke Circle '
      'keluarga. Kamu tetap bisa memakai aplikasi, dan bisa mengizinkannya '
      'kapan saja di pengaturan.';

  static const alwaysDeniedTitle = 'Mode terbatas';
  static const alwaysDeniedBody =
      'Lokasimu hanya dibagikan saat aplikasi terbuka, jadi keluarga mungkin '
      'tidak melihat posisimu saat aplikasi ditutup. Kamu bisa mengubahnya '
      'kapan saja di pengaturan.';

  static const notificationDeniedTitle = 'Pemberitahuan dimatikan';
  static const notificationDeniedBody =
      'Kamu tidak akan menerima pemberitahuan saat anggota tiba, pergi, atau '
      'mengirim SOS. Kamu bisa menyalakannya kapan saja di pengaturan.';

  static const batteryTitle = 'Agar berbagi tetap berjalan';
  static const batteryIntro =
      'Beberapa ponsel menghentikan aplikasi di latar belakang untuk '
      'menghemat baterai. Atur Tether agar tidak dibatasi dan boleh mulai '
      'otomatis.';
  static const batteryBrands = [
    BatteryGuide(
      'Xiaomi, Redmi, POCO',
      'Buka info aplikasi Tether, pilih Hemat baterai, lalu Tanpa batasan. '
          'Aktifkan juga Mulai otomatis.',
    ),
    BatteryGuide(
      'Oppo, Realme',
      'Buka info aplikasi Tether, pilih Penggunaan baterai, lalu izinkan '
          'aktivitas latar belakang. Aktifkan juga Mulai otomatis.',
    ),
    BatteryGuide(
      'Vivo',
      'Buka pengaturan Baterai, pilih Konsumsi daya latar belakang, lalu '
          'izinkan Tether. Aktifkan juga Mulai otomatis.',
    ),
    BatteryGuide(
      'Samsung',
      'Buka pengaturan Baterai, pilih Batas penggunaan di latar belakang, '
          'lalu keluarkan Tether dari Aplikasi tidur. Pilih Tidak dibatasi di '
          'info aplikasi.',
    ),
    BatteryGuide(
      'Ponsel lain',
      'Buka info aplikasi Tether, pilih Baterai, lalu Tanpa batasan atau '
          'Tidak dioptimalkan.',
    ),
  ];
  static const batteryFootnote = 'Nama menu bisa berbeda di tiap versi sistem.';

  // Overlay peta.
  static const overlayRunning = 'Berbagi lokasi aktif';
  static const overlayNeedsPermission = 'Perlu izin lokasi';
  static const overlayNeedsCircle = 'Gabung Circle dulu';
  static const overlayUnavailable = 'Lokasi tidak tersedia';
  static const overlayIdle = 'Berbagi lokasi belum aktif';
  static const overlayError = 'Lokasi bermasalah';
  static String overlayOffline(int queued) => 'Offline, $queued titik tertahan';

  static const hintOpenDetail = 'Buka detail berbagi lokasi';
  static const hintOpenPermission = 'Buka pengaturan izin lokasi';

  // Sheet detail.
  static const sheetTitle = 'Status berbagi lokasi';
  static const sheetIdle =
      'Berbagi lokasi akan mulai setelah semua syarat terpenuhi.';
  static const sheetNeedsPermission =
      'Izinkan lokasi agar keluarga bisa melihat posisimu.';
  static const sheetNeedsCircle =
      'Buat atau gabung Circle agar lokasimu bisa dibagikan.';
  static const sheetUnavailable = 'Lokasi tidak tersedia di perangkat ini.';
  static const sheetRunning = 'Lokasimu sedang dibagikan ke Circle keluarga.';
  static const sheetOffline =
      'Titik lokasi tertahan di perangkat dan dikirim saat koneksi kembali.';
  static const sheetErrorFallback = 'Sumber lokasi bermasalah.';

  static const sent = 'Terkirim';
  static const queued = 'Antrean';
  static const dropped = 'Dibuang';
  static const skipped = 'Dilewati';
  static const lastError = 'Kesalahan terakhir';
  static const none = 'Tidak ada';
  static const close = 'Selesai';

  // Simulasi (hanya debug atau SIMULATE_LOCATION).
  static const simulationTitle = 'Simulasi lokasi';
  static const simulationNote =
      'Simulasi memutar rute uji di sekitar Monas, Jakarta, bukan lokasimu '
      'yang sebenarnya.';
  static const simulationStart = 'Mulai simulasi';
  static const simulationStop = 'Berhenti';
}

class BatteryGuide {
  const BatteryGuide(this.brand, this.steps);

  final String brand;
  final String steps;
}
