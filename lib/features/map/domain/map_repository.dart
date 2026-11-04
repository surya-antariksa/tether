import 'map_circle.dart';
import 'map_member.dart';

enum MapFailureKind { network, unauthenticated, notMember, invalid, unknown }

/// Galat peta yang sudah dipetakan, tanpa detail teknis.
class MapFailure implements Exception {
  const MapFailure(this.kind);

  final MapFailureKind kind;

  @override
  String toString() => 'MapFailure($kind)';
}

/// Kejadian realtime yang sudah dinormalisasi.
sealed class MapRealtimeEvent {
  const MapRealtimeEvent();
}

/// Baris member_status berubah (INSERT/UPDATE). Klien menyaring ke anggota
/// Circle terpilih.
class StatusChanged extends MapRealtimeEvent {
  const StatusChanged(this.userId, this.location);

  final String userId;

  /// Null bila titik belum valid.
  final MemberLocation? location;
}

/// Ada perubahan yang tidak bisa diturunkan dari satu baris (jeda, lanjut,
/// anggota keluar/masuk, DELETE): muat ulang daftar.
class RefreshNeeded extends MapRealtimeEvent {
  const RefreshNeeded();
}

class ConnectionChanged extends MapRealtimeEvent {
  const ConnectionChanged({required this.connected});

  final bool connected;
}

abstract interface class MapRepository {
  /// Circle milik pengguna, yang paling lama bergabung lebih dulu.
  Future<List<MapCircle>> fetchCircles();

  /// Anggota Circle beserta lokasi terakhir yang boleh dilihat.
  Future<List<MapMember>> fetchMembers(String circleId);

  /// Langganan realtime untuk Circle. Berhenti saat langganan stream dibatalkan.
  Stream<MapRealtimeEvent> realtimeEvents(String circleId);

  /// [minutes] null = sampai dinyalakan lagi. Melempar [MapFailure].
  Future<void> pauseSharing(String circleId, {int? minutes});

  Future<void> resumeSharing(String circleId);
}
