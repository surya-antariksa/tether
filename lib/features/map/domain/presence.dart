import 'map_member.dart';

/// Status kehadiran anggota di peta (docs/07 bagian 5.1). `NoPermission`
/// tidak dimodelkan di klien: tidak ada kolom yang membedakannya dari
/// "belum ada lokasi".
enum PresenceState { active, paused, stale, noLocation }

/// Batas titik terakhir dianggap basi. Detak diam dikirim tiap 15 menit, jadi
/// 30 menit = dua detak terlewat. Nilai awal, perlu kalibrasi di Sprint 0B.
const Duration staleThreshold = Duration(minutes: 30);

/// Fungsi murni. Urutan prioritas: dijeda, belum ada lokasi, basi, aktif.
PresenceState presenceOf(
  MapMember member,
  DateTime now, {
  Duration staleAfter = staleThreshold,
}) {
  if (member.isPausedAt(now)) return PresenceState.paused;
  final loc = member.location;
  if (loc == null) return PresenceState.noLocation;
  if (now.difference(loc.lastSeenAt) > staleAfter) return PresenceState.stale;
  return PresenceState.active;
}

/// Hanya anggota aktif dan basi yang punya marker.
bool hasMarker(PresenceState s) =>
    s == PresenceState.active || s == PresenceState.stale;
