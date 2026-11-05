/// Tipe event Circle yang tampil di tab Aktivitas (kolom events.type).
enum ActivityType {
  arrive('arrive'),
  leave('leave'),
  memberJoined('member_joined'),
  memberLeft('member_left'),
  memberRemoved('member_removed'),
  paused('paused'),
  resumed('resumed'),
  checkin('checkin'),
  sos('sos'),
  sharingChanged('sharing_changed');

  const ActivityType(this.wire);

  /// Nilai di database.
  final String wire;

  static ActivityType? parse(Object? wire) {
    for (final t in values) {
      if (t.wire == wire) return t;
    }
    return null;
  }

  /// Nilai database untuk filter kueri.
  static List<String> get wireValues => [for (final t in values) t.wire];
}

/// Jenis check-in (payload.kind dari RPC checkin).
enum CheckinKind { arrived, safe }

/// Satu baris tabel events beserta payload yang sudah dipilah.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.circleId,
    required this.userId,
    required this.type,
    required this.createdAt,
    this.displayName,
    this.placeName,
    this.pausedMinutes,
    this.checkinKind,
    this.sharingEnabled,
    this.clientId,
    this.lat,
    this.lng,
    this.triggeredAt,
  });

  final String id;
  final String circleId;

  /// Pelaku. Untuk member_removed: anggota yang dikeluarkan.
  final String userId;
  final ActivityType type;
  final DateTime createdAt;

  /// payload.display_name (member_*, checkin, sos). Null bila tidak ada.
  final String? displayName;

  /// payload.place_name (arrive, leave).
  final String? placeName;

  /// payload.minutes (paused). Null = sampai dinyalakan lagi.
  final int? pausedMinutes;

  /// payload.kind (checkin).
  final CheckinKind? checkinKind;

  /// payload.enabled (sharing_changed: sakelar berbagi jangka panjang).
  final bool? sharingEnabled;

  /// payload.client_id (sos): id pemondok dari klien, untuk dedup notifikasi.
  final String? clientId;

  /// Koordinat SOS (payload.lat dan lng). Hilang setelah 48 jam.
  final double? lat;
  final double? lng;

  /// payload.triggered_at (sos).
  final DateTime? triggeredAt;

  bool get hasCoordinates => lat != null && lng != null;

  /// Waktu yang ditampilkan: saat SOS dipicu bila ada.
  DateTime get shownAt => triggeredAt ?? createdAt;
}
