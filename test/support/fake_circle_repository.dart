import 'dart:async';

import 'package:tether/features/circle/domain/circle.dart';
import 'package:tether/features/circle/domain/circle_repository.dart';

CircleMember fakeMember(
  String userId,
  String name, {
  CircleRole role = CircleRole.member,
  String color = '#2563EB',
  bool sharingEnabled = true,
  DateTime? pausedUntil,
  bool pausedIndefinitely = false,
  int joinedDay = 1,
}) => CircleMember(
  userId: userId,
  displayName: name,
  color: color,
  role: role,
  joinedAt: DateTime.utc(2026, 11, joinedDay),
  sharingEnabled: sharingEnabled,
  pausedUntil: pausedUntil,
  pausedIndefinitely: pausedIndefinitely,
);

/// Repository Circle palsu di memori. Pengguna sendiri: [selfId] dan [selfName].
class FakeCircleRepository implements CircleRepository {
  FakeCircleRepository({
    this.selfId = 'user-1',
    this.selfName = 'Rina Wati',
    List<Circle>? circles,
    Map<String, List<CircleMember>>? members,
  }) : circles = [...?circles],
       membersByCircle = {...?members};

  final String selfId;
  final String selfName;
  final List<Circle> circles;
  final Map<String, List<CircleMember>> membersByCircle;

  /// Kode -> pratinjau (kode lain dianggap tidak valid).
  final Map<String, InvitePreview> previews = {};

  /// Kode -> id Circle tujuan saat join berhasil.
  final Map<String, String> joinTargets = {};

  /// Bila diisi, metode bernama itu melempar galat ini (mis. 'joinCircle').
  final Map<String, CircleError> failures = {};
  Completer<void>? gate;

  final calls = <String>[];
  int membersFetches = 0;
  int circlesFetches = 0;
  int _seq = 0;
  CircleInvite nextInvite = CircleInvite(
    code: 'ABC234',
    expiresAt: DateTime.utc(2026, 11, 6, 7, 30),
  );

  final _changes = <String, StreamController<void>>{};

  /// Simulasi event realtime di Circle ini.
  void emitChange(String circleId) => _changes[circleId]?.add(null);

  Future<void> _enter(String name) async {
    calls.add(name);
    if (gate != null) await gate!.future;
    final f = failures[name];
    if (f != null) throw f;
  }

  @override
  Future<List<Circle>> myCircles() async {
    await _enter('myCircles');
    circlesFetches++;
    return [...circles];
  }

  @override
  Future<List<CircleMember>> members(String circleId) async {
    await _enter('members');
    membersFetches++;
    return [...?membersByCircle[circleId]];
  }

  @override
  Future<String> createCircle(String name) async {
    await _enter('createCircle:$name');
    final id = 'circle-new-${++_seq}';
    circles.add(Circle(id: id, name: name));
    membersByCircle[id] = [
      fakeMember(selfId, selfName, role: CircleRole.admin),
    ];
    return id;
  }

  @override
  Future<CircleInvite> createInvite(String circleId) async {
    await _enter('createInvite:$circleId');
    return nextInvite;
  }

  @override
  Future<InvitePreview?> previewInvite(String code) async {
    await _enter('previewInvite:$code');
    return previews[code];
  }

  @override
  Future<String?> joinCircle(String code) async {
    await _enter('joinCircle:$code');
    final id = joinTargets[code];
    if (id == null) return null;
    final name = previews[code]?.circleName ?? 'Circle';
    if (!circles.any((c) => c.id == id))
      circles.add(Circle(id: id, name: name));
    membersByCircle.putIfAbsent(id, () => []);
    if (!membersByCircle[id]!.any((m) => m.userId == selfId)) {
      membersByCircle[id]!.add(fakeMember(selfId, selfName));
    }
    return id;
  }

  @override
  Future<void> leaveCircle(String circleId) async {
    await _enter('leaveCircle:$circleId');
    circles.removeWhere((c) => c.id == circleId);
    membersByCircle.remove(circleId);
  }

  @override
  Future<void> removeMember(String circleId, String userId) async {
    await _enter('removeMember:$circleId:$userId');
    membersByCircle[circleId]?.removeWhere((m) => m.userId == userId);
  }

  @override
  Stream<void> memberChanges(String circleId) =>
      (_changes[circleId] ??= StreamController<void>.broadcast()).stream;
}
