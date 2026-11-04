enum CircleRole { admin, member }

/// Status berbagi lokasi seorang anggota di satu Circle.
enum SharingStatus { sharing, paused, off }

/// Circle milik pengguna (public.circles).
class Circle {
  const Circle({required this.id, required this.name});

  final String id;
  final String name;
}

/// Satu baris circle_members beserta profil anggota.
class CircleMember {
  const CircleMember({
    required this.userId,
    required this.displayName,
    required this.color,
    required this.role,
    required this.joinedAt,
    this.sharingEnabled = true,
    this.pausedUntil,
    this.pausedIndefinitely = false,
  });

  final String userId;
  final String displayName;

  /// '#RRGGBB'.
  final String color;
  final CircleRole role;
  final DateTime joinedAt;
  final bool sharingEnabled;

  /// Akhir jeda. Null bila tidak dijeda atau dijeda tanpa batas.
  final DateTime? pausedUntil;

  /// paused_until = 'infinity' (dijeda sampai dinyalakan lagi).
  final bool pausedIndefinitely;

  bool get isAdmin => role == CircleRole.admin;

  /// Jeda yang sudah lewat tidak mengubah baris, jadi dihitung dari waktu.
  bool isPausedAt(DateTime now) =>
      pausedIndefinitely || (pausedUntil != null && pausedUntil!.isAfter(now));

  SharingStatus statusAt(DateTime now) {
    if (!sharingEnabled) return SharingStatus.off;
    if (isPausedAt(now)) return SharingStatus.paused;
    return SharingStatus.sharing;
  }
}

/// Hasil create_invite. Kode asli hanya ada di sini (server hanya menyimpan hash).
class CircleInvite {
  const CircleInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Hasil preview_invite untuk kode yang valid.
class InvitePreview {
  const InvitePreview({required this.circleName, required this.memberCount});

  final String circleName;
  final int memberCount;
}
