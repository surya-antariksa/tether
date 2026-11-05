enum NotificationUrgency { normal, high }

/// Notifikasi lokal yang akan ditampilkan.
class LocalNotification {
  const LocalNotification({
    required this.id,
    required this.title,
    required this.body,
    this.urgency = NotificationUrgency.normal,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final NotificationUrgency urgency;

  /// Id Circle; dikirim balik lewat [NotificationGateway.taps].
  final String? payload;
}

/// Abstraksi layanan notifikasi lokal. Implementasi nyata tidak boleh
/// melempar bila plugin tidak tersedia (tes, web).
abstract interface class NotificationGateway {
  /// Aman dipanggil berulang. Tidak melempar.
  Future<void> initialize();

  /// Minta izin notifikasi. False bila ditolak atau tidak tersedia.
  Future<bool> requestPermission();

  /// Tidak melempar. Tidak melakukan apa pun bila tidak tersedia.
  Future<void> show(LocalNotification notification);

  /// Payload notifikasi yang diketuk pengguna.
  Stream<String> get taps;
}
