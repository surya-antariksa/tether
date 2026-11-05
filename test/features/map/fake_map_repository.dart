import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:tether/features/map/domain/map_circle.dart';
import 'package:tether/features/map/domain/map_member.dart';
import 'package:tether/features/map/domain/map_repository.dart';
import 'package:tether/features/map/domain/paused_until.dart';

/// Repository peta palsu: data di memori, galat dan penahan (gate) yang bisa
/// diatur, serta aliran realtime yang digerakkan tes.
class FakeMapRepository implements MapRepository {
  FakeMapRepository({
    this.selfId = 'u1',
    List<MapCircle> circles = const [],
    Map<String, List<MapMember>> members = const {},
  }) : circles = [...circles],
       members = {
         for (final e in members.entries) e.key: [...e.value],
       };

  final String selfId;

  /// Jam server untuk menghitung akhir jeda (sama dengan jam tetap tes).
  DateTime now = DateTime.utc(2026, 11, 5, 12);
  final List<MapCircle> circles;
  final Map<String, List<MapMember>> members;

  /// Bila diisi, pemanggilan terkait melempar ini.
  Object? circlesFailure;
  Object? membersFailure;
  Object? pauseFailure;

  /// Bila diisi, pemanggilan menunggu completer ini.
  Completer<void>? circlesGate;
  Completer<void>? membersGate;

  int fetchCirclesCalls = 0;
  final fetchMembersCalls = <String>[];
  final pauseCalls = <({String circleId, int? minutes})>[];
  final resumeCalls = <String>[];

  final events = StreamController<MapRealtimeEvent>.broadcast();
  int realtimeSubscriptions = 0;
  int realtimeCancels = 0;

  @override
  Future<List<MapCircle>> fetchCircles() async {
    fetchCirclesCalls++;
    await circlesGate?.future;
    if (circlesFailure != null) throw circlesFailure!;
    return [...circles];
  }

  @override
  Future<List<MapMember>> fetchMembers(String circleId) async {
    fetchMembersCalls.add(circleId);
    await membersGate?.future;
    if (membersFailure != null) throw membersFailure!;
    return [...?members[circleId]];
  }

  @override
  Stream<MapRealtimeEvent> realtimeEvents(String circleId) {
    late StreamController<MapRealtimeEvent> c;
    c = StreamController<MapRealtimeEvent>(
      onListen: () {
        realtimeSubscriptions++;
        events.stream.listen(c.add);
      },
      onCancel: () => realtimeCancels++,
    );
    return c.stream;
  }

  void _updateSelf(String circleId, MapMember Function(MapMember) f) {
    final list = members[circleId];
    if (list == null) return;
    members[circleId] = [for (final m in list) m.userId == selfId ? f(m) : m];
  }

  @override
  Future<void> pauseSharing(String circleId, {int? minutes}) async {
    pauseCalls.add((circleId: circleId, minutes: minutes));
    if (pauseFailure != null) throw pauseFailure!;
    _updateSelf(
      circleId,
      (m) => MapMember(
        userId: m.userId,
        displayName: m.displayName,
        colorHex: m.colorHex,
        sharingEnabled: m.sharingEnabled,
        pause: minutes == null
            ? PausedUntil.indefinitely
            : PausedUntil.at(now.add(Duration(minutes: minutes))),
        location: m.location,
      ),
    );
  }

  @override
  Future<void> resumeSharing(String circleId) async {
    resumeCalls.add(circleId);
    if (pauseFailure != null) throw pauseFailure!;
    _updateSelf(
      circleId,
      (m) => MapMember(
        userId: m.userId,
        displayName: m.displayName,
        colorHex: m.colorHex,
        sharingEnabled: true,
        location: m.location,
      ),
    );
  }

  Future<void> dispose() => events.close();
}

/// Lokasi uji di sekitar Jakarta.
MemberLocation locationAt(
  DateTime lastSeenAt, {
  LatLng point = const LatLng(-6.2088, 106.8456),
  int? battery,
  bool? moving,
  double? speedMps,
}) => MemberLocation(
  point: point,
  lastSeenAt: lastSeenAt,
  batteryPct: battery,
  isMoving: moving,
  speedMps: speedMps,
);
