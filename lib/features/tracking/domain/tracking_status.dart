/// Status layanan pelacakan untuk UI.
enum TrackingStatus {
  /// Belum berjalan (belum masuk, sedang memulai, atau keanggotaan belum diketahui).
  idle,

  /// Izin lokasi belum diberikan.
  needsPermission,

  /// Pengguna belum punya keanggotaan Circle.
  needsCircle,

  /// Tidak ada sumber lokasi di perangkat ini (mis. Linux tanpa simulasi).
  unavailable,

  /// Berjalan. Bila server menjeda berbagi, klien tetap berjalan (server
  /// mengembalikan 0 dan titik dihitung sebagai dilewati).
  running,

  /// Ada titik tertahan di antrean dan unggah sedang gagal.
  offlineWithQueue,

  /// Sumber lokasi gagal (mis. GPS mati).
  error,
}

/// Potret layanan pelacakan. Tidak memuat koordinat.
class TrackingSnapshot {
  const TrackingSnapshot({
    this.status = TrackingStatus.idle,
    this.queued = 0,
    this.sent = 0,
    this.skippedByServer = 0,
    this.dropped = 0,
    this.droppedInvalid = 0,
    this.lastError,
    this.detail,
  });

  final TrackingStatus status;
  final int queued;
  final int sent;

  /// Dilewati server (duplikat, lebih tua dari 30 hari, atau berbagi dijeda).
  final int skippedByServer;

  /// Dibuang karena antrean penuh.
  final int dropped;

  /// Dibuang karena server menolaknya sebagai tidak valid.
  final int droppedInvalid;

  /// Galat unggah terakhir (tanpa koordinat).
  final String? lastError;

  /// Penjelasan singkat dari sumber lokasi (tanpa koordinat).
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is TrackingSnapshot &&
      other.status == status &&
      other.queued == queued &&
      other.sent == sent &&
      other.skippedByServer == skippedByServer &&
      other.dropped == dropped &&
      other.droppedInvalid == droppedInvalid &&
      other.lastError == lastError &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(
    status,
    queued,
    sent,
    skippedByServer,
    dropped,
    droppedInvalid,
    lastError,
    detail,
  );
}
