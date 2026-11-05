import 'dart:async';

import 'package:tether/features/activity/data/activity_providers.dart';
import 'package:tether/features/activity/domain/activity_event.dart';
import 'package:tether/features/activity/domain/activity_repository.dart';
import 'package:tether/features/activity/domain/notification_gateway.dart';
import 'package:tether/features/activity/domain/read_marker_store.dart';

/// Jam tetap semua tes aktivitas.
final fixedNow = DateTime.utc(2026, 11, 5, 12);

class FixedActivityClock extends ActivityClock {
  @override
  DateTime build() => fixedNow;
}

ActivityEvent ev(
  String id, {
  String circleId = 'c1',
  String userId = 'u2',
  ActivityType type = ActivityType.arrive,
  int minutesAgo = 5,
  String? name,
  String? place,
  int? minutes,
  CheckinKind? kind,
  bool? sharingEnabled,
  String? clientId,
  double? lat,
  double? lng,
  DateTime? triggeredAt,
}) => ActivityEvent(
  id: id,
  circleId: circleId,
  userId: userId,
  type: type,
  createdAt: fixedNow.subtract(Duration(minutes: minutesAgo)),
  displayName: name,
  placeName: place,
  pausedMinutes: minutes,
  checkinKind: kind,
  sharingEnabled: sharingEnabled,
  clientId: clientId,
  lat: lat,
  lng: lng,
  triggeredAt: triggeredAt,
);

/// Repository aktivitas palsu: data di memori, galat dan penahan yang bisa
/// diatur, dan aliran realtime yang digerakkan tes.
class FakeActivityRepository implements ActivityRepository {
  FakeActivityRepository({
    Map<String, List<ActivityEvent>> events = const {},
    Map<String, String> names = const {},
    this.circleNames = const {'c1': 'Keluarga', 'c2': 'Kantor'},
  }) : names = {...names},
       events = {
         for (final e in events.entries) e.key: [...e.value],
       };

  /// Per Circle, urutan bebas (disortir saat diambil).
  final Map<String, List<ActivityEvent>> events;
  final Map<String, String> names;
  final Map<String, String> circleNames;

  /// Id yang dikembalikan fetchEventIdsSince.
  List<String> unreadIds = [];

  Object? fetchFailure;
  Object? namesFailure;
  Completer<void>? fetchGate;

  final fetchCalls = <({String circleId, DateTime? before, int limit})>[];
  int namesCalls = 0;
  final sinceCalls = <DateTime>[];
  int fetchFailuresLeft = 0;

  final stream = StreamController<ActivityRealtime>.broadcast();
  final subscriptions = <String?>[];
  int cancels = 0;

  @override
  Future<List<ActivityEvent>> fetchEvents(
    String circleId, {
    DateTime? before,
    int limit = 30,
  }) async {
    fetchCalls.add((circleId: circleId, before: before, limit: limit));
    await fetchGate?.future;
    if (fetchFailuresLeft > 0) {
      fetchFailuresLeft--;
      throw const ActivityFailure(ActivityFailureKind.network);
    }
    if (fetchFailure != null) throw fetchFailure!;
    final all = [...?events[circleId]]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final e in all)
        if (before == null || e.createdAt.isBefore(before)) e,
    ].take(limit).toList();
  }

  @override
  Future<Map<String, String>> fetchMemberNames(String circleId) async {
    namesCalls++;
    if (namesFailure != null) throw namesFailure!;
    return {...names};
  }

  @override
  Future<String?> fetchCircleName(String circleId) async =>
      circleNames[circleId];

  @override
  Future<List<String>> fetchEventIdsSince(
    DateTime since, {
    required String excludeUserId,
    int cap = 100,
  }) async {
    sinceCalls.add(since);
    return unreadIds.take(cap).toList();
  }

  @override
  Stream<ActivityRealtime> realtimeEvents({String? circleId}) {
    late StreamController<ActivityRealtime> c;
    StreamSubscription<ActivityRealtime>? sub;
    c = StreamController<ActivityRealtime>(
      onListen: () {
        subscriptions.add(circleId);
        sub = stream.stream.listen((e) {
          // Langganan per Circle hanya menerima Circle-nya.
          if (circleId != null &&
              e is EventInserted &&
              e.event.circleId != circleId) {
            return;
          }
          c.add(e);
        });
      },
      onCancel: () {
        cancels++;
        return sub?.cancel();
      },
    );
    return c.stream;
  }

  void insert(ActivityEvent e) => stream.add(EventInserted(e));

  void connection(bool connected) =>
      stream.add(ActivityConnectionChanged(connected: connected));
}

class FakeNotificationGateway implements NotificationGateway {
  int initCalls = 0;
  int permissionCalls = 0;
  final shown = <LocalNotification>[];
  final tapController = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async => initCalls++;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return true;
  }

  @override
  Future<void> show(LocalNotification n) async => shown.add(n);

  @override
  Stream<String> get taps => tapController.stream;
}

class MemoryReadMarkerStore implements ReadMarkerStore {
  MemoryReadMarkerStore([this.value]);

  DateTime? value;
  int writes = 0;

  @override
  Future<DateTime?> read() async => value;

  @override
  Future<void> write(DateTime time) async {
    writes++;
    value = time;
  }
}
