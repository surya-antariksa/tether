import '../domain/activity_event.dart';

/// Teks UI fitur aktivitas (bahasa Indonesia).
abstract final class ActivityStrings {
  static const title = 'Aktivitas';
  static const you = 'Anda';
  static const subtitle =
      'Pemberitahuan lokasi, status keamanan, dan riwayat lingkaran Anda.';
  static const realtimeBadge = 'Realtime';
  static const statusTitle = 'Status Anda';
  static const statusNone = 'Belum ada kabar dari Anda';
  static String statusUpdated(String ago) => 'Terakhir diperbarui $ago';
  static const checkinButton = 'Kabar Aman';
  static const filterAll = 'Semua';
  static const filterSafety = 'Keamanan';
  static const filterPlaces = 'Tempat';
  static const filterCircle = 'Circle';
  static const filterEmpty = 'Tidak ada aktivitas di kategori ini.';
  static const today = 'Hari ini';
  static const yesterday = 'Kemarin';
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

  /// Judul kelompok hari: Hari ini, Kemarin, atau "6 Nov".
  static String dayLabel(DateTime day, DateTime now) {
    final d = DateTime(day.year, day.month, day.day);
    final n = DateTime(now.year, now.month, now.day);
    final diff = n.difference(d).inDays;
    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    return '${d.day} ${_months[d.month - 1]}';
  }

  static const someone = 'Seorang anggota';
  static const unknownPlace = 'sebuah tempat';

  static const loadFailed = 'Aktivitas tidak bisa dimuat.';
  static const retry = 'Coba lagi';
  static const loadMore = 'Muat yang lebih lama';
  static const loadMoreFailed = 'Gagal memuat. Ketuk untuk coba lagi.';
  static const end = 'Tidak ada aktivitas yang lebih lama';

  static const emptyTitle = 'Belum ada aktivitas';
  static const emptyBody =
      'Kabar tiba dan pergi, perubahan anggota, dan check-in Circle akan muncul di sini.';

  static const noCircleTitle = 'Belum ada Circle';
  static const noCircleBody =
      'Buat Circle atau gabung dengan kode undangan untuk melihat aktivitasnya.';

  static const circlePickerTitle = 'Pilih Circle';
  static const circlePickerCancel = 'Batal';
  static String circleLabel(String name, {required bool canSwitch}) =>
      canSwitch ? 'Circle $name, ketuk untuk ganti Circle' : 'Circle $name';

  static const realtimeOffline = 'Menyambung ulang';
  static const realtimeOfflineLabel =
      'Koneksi langsung terputus, mencoba menyambung ulang';

  static const sosBadge = 'SOS';
  static const showOnMap = 'Lihat di peta';
  static String showOnMapLabel(String who) => 'Lihat lokasi SOS $who di peta';
  static const sosNoLocation = 'Lokasi sudah tidak tersimpan.';

  // Lencana tab
  static const tabBadgeMax = '99+';
  static String unreadLabel(int n) =>
      n >= 100 ? 'lebih dari 99 belum dibaca' : '$n belum dibaca';

  // Notifikasi
  static const notificationDefaultTitle = 'Tether';
  static String sosNotificationTitle(String who) => 'SOS dari $who';
  static String sosNotificationBody(String? circleName) => circleName == null
      ? 'Buka Tether untuk melihat lokasi.'
      : 'Circle $circleName. Buka Tether untuk melihat lokasi.';

  /// Kalimat lengkap satu event, mis. "Sinta tiba di Rumah". [who] sudah
  /// berupa nama atau "Anda".
  static String sentence(ActivityEvent e, String who) {
    final place = e.placeName ?? unknownPlace;
    return switch (e.type) {
      ActivityType.arrive => '$who tiba di $place',
      ActivityType.leave => '$who meninggalkan $place',
      ActivityType.memberJoined => '$who bergabung ke Circle',
      ActivityType.memberLeft => '$who keluar dari Circle',
      ActivityType.memberRemoved => '$who dikeluarkan dari Circle',
      ActivityType.paused =>
        e.pausedMinutes == null
            ? '$who menjeda berbagi lokasi sampai dinyalakan lagi'
            : '$who menjeda berbagi lokasi selama ${_duration(e.pausedMinutes!)}',
      ActivityType.resumed => '$who melanjutkan berbagi lokasi',
      ActivityType.sharingChanged =>
        e.sharingEnabled == false
            ? '$who mematikan berbagi lokasi untuk Circle ini'
            : '$who menyalakan berbagi lokasi Circle ini',
      ActivityType.checkin => switch (e.checkinKind) {
        CheckinKind.arrived => '$who memberi kabar: sudah sampai',
        CheckinKind.safe => '$who memberi kabar: aman',
        null => '$who memberi kabar',
      },
      ActivityType.sos => 'SOS dari $who',
    };
  }

  static String _duration(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60} jam';
    return '$minutes menit';
  }
}
