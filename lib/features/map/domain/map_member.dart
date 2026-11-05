import 'package:latlong2/latlong.dart';

import 'paused_until.dart';

/// Baris `member_status` yang terlihat (RLS: hanya anggota yang berbagi dan
/// tidak dijeda, ditambah milik sendiri).
class MemberLocation {
  const MemberLocation({
    required this.point,
    required this.lastSeenAt,
    this.batteryPct,
    this.isMoving,
  });

  final LatLng point;
  final DateTime lastSeenAt;
  final int? batteryPct;
  final bool? isMoving;
}

/// Anggota satu Circle: profil + pengaturan berbagi + lokasi terakhir (bila
/// terlihat). [location] null berarti belum ada lokasi atau disembunyikan RLS
/// karena dijeda.
class MapMember {
  const MapMember({
    required this.userId,
    required this.displayName,
    required this.colorHex,
    this.sharingEnabled = true,
    this.pause = PausedUntil.none,
    this.location,
  });

  final String userId;
  final String displayName;

  /// '#RRGGBB'.
  final String colorHex;
  final bool sharingEnabled;
  final PausedUntil pause;
  final MemberLocation? location;

  /// Dijeda bila berbagi dimatikan atau jeda masih berlaku pada [now].
  bool isPausedAt(DateTime now) => !sharingEnabled || pause.activeAt(now);

  MapMember copyWith({
    PausedUntil? pause,
    bool? sharingEnabled,
    MemberLocation? location,
  }) => MapMember(
    userId: userId,
    displayName: displayName,
    colorHex: colorHex,
    sharingEnabled: sharingEnabled ?? this.sharingEnabled,
    pause: pause ?? this.pause,
    location: location ?? this.location,
  );
}
