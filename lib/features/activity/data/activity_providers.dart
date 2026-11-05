import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/selected_circle.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/activity_event.dart';
import '../domain/activity_repository.dart';
import '../domain/notification_gateway.dart';
import '../domain/read_marker_store.dart';
import '../presentation/activity_strings.dart';
import 'local_notification_gateway.dart';
import 'shared_prefs_read_marker_store.dart';
import 'supabase_activity_repository.dart';

/// Override di tes dengan repository palsu.
final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => SupabaseActivityRepository(ref.watch(supabaseClientProvider)),
);

/// Override di tes dengan gateway palsu (tanpa plugin platform).
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationGateway(),
);

/// Override di tes dengan penyimpanan di memori.
final readMarkerStoreProvider = Provider<ReadMarkerStore>(
  (ref) => SharedPrefsReadMarkerStore(ref.watch(currentUserIdProvider)),
);

/// Jam tab Aktivitas: memperbarui waktu relatif tiap menit.
/// Override di tes dengan subclass yang waktunya tetap.
class ActivityClock extends Notifier<DateTime> {
  static const tick = Duration(minutes: 1);

  @override
  DateTime build() {
    final timer = Timer.periodic(tick, (_) => state = DateTime.now());
    ref.onDispose(timer.cancel);
    return DateTime.now();
  }
}

final activityClockProvider = NotifierProvider<ActivityClock, DateTime>(
  ActivityClock.new,
);

// ---------------------------------------------------------------------------
// Daftar event satu Circle
// ---------------------------------------------------------------------------

class ActivityListState {
  const ActivityListState({
    required this.events,
    required this.names,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.realtimeConnected = true,
  });

  /// Terbaru dulu.
  final List<ActivityEvent> events;

  /// Id pengguna ke nama tampilan anggota saat ini.
  final Map<String, String> names;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// False selagi koneksi realtime terputus (data bisa tertinggal).
  final bool realtimeConnected;

  ActivityListState copyWith({
    List<ActivityEvent>? events,
    Map<String, String>? names,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    bool? realtimeConnected,
  }) => ActivityListState(
    events: events ?? this.events,
    names: names ?? this.names,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    realtimeConnected: realtimeConnected ?? this.realtimeConnected,
  );
}

/// Event satu Circle, terbaru dulu, dengan paginasi dan pembaruan realtime.
final activityListProvider =
    AsyncNotifierProvider.family<
      ActivityListNotifier,
      ActivityListState,
      String
    >(
      ActivityListNotifier.new,
      isAutoDispose: true,
      retry: (_, _) => null, // pengguna memicu ulang lewat tombol
    );

class ActivityListNotifier extends AsyncNotifier<ActivityListState> {
  ActivityListNotifier(this.circleId);

  static const pageSize = 30;

  final String circleId;

  final _early = <ActivityEvent>[];
  bool _wasDisconnected = false;
  bool _refreshing = false;

  @override
  Future<ActivityListState> build() async {
    _early.clear();
    ref.watch(currentUserIdProvider);
    final repo = ref.watch(activityRepositoryProvider);
    // Berlangganan lebih dulu agar tidak ada celah antara muat awal dan event.
    final sub = repo
        .realtimeEvents(circleId: circleId)
        .listen(_onRealtime, onError: (Object _) => _setConnected(false));
    ref.onDispose(sub.cancel);
    final results = await Future.wait([
      repo.fetchEvents(circleId, limit: pageSize),
      _namesOrEmpty(repo),
    ]);
    final fetched = results[0] as List<ActivityEvent>;
    return ActivityListState(
      // Event realtime yang datang selama memuat ikut digabung.
      events: _merge(_early, fetched),
      names: results[1] as Map<String, String>,
      hasMore: fetched.length >= pageSize,
    );
  }

  Future<Map<String, String>> _namesOrEmpty(ActivityRepository repo) async {
    try {
      return await repo.fetchMemberNames(circleId);
    } catch (_) {
      return const {}; // nama dari payload tetap dipakai
    }
  }

  void _onRealtime(ActivityRealtime e) {
    switch (e) {
      case EventInserted(:final event):
        if (event.circleId != circleId) return;
        final cur = state.value;
        if (cur == null) {
          _early.add(event); // masih memuat
          return;
        }
        state = AsyncData(cur.copyWith(events: _merge(cur.events, [event])));
        if (event.type == ActivityType.memberJoined &&
            !cur.names.containsKey(event.userId)) {
          unawaited(_refreshNames());
        }
      case ActivityConnectionChanged(:final connected):
        _setConnected(connected);
    }
  }

  void _setConnected(bool connected) {
    final cur = state.value;
    if (connected && _wasDisconnected) {
      _wasDisconnected = false;
      unawaited(refresh()); // tersambung kembali: ambil yang terlewat
    }
    if (!connected) _wasDisconnected = true;
    if (cur != null && cur.realtimeConnected != connected) {
      state = AsyncData(cur.copyWith(realtimeConnected: connected));
    }
  }

  Future<void> _refreshNames() async {
    final names = await _namesOrEmpty(ref.read(activityRepositoryProvider));
    final cur = state.value;
    if (!ref.mounted || cur == null || names.isEmpty) return;
    state = AsyncData(cur.copyWith(names: names));
  }

  /// Ambil ulang halaman pertama tanpa loading; data lama tetap. Galat
  /// jaringan diabaikan.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final repo = ref.read(activityRepositoryProvider);
      final fetched = await repo.fetchEvents(circleId, limit: pageSize);
      final names = await _namesOrEmpty(repo);
      if (!ref.mounted) return;
      final cur = state.value;
      state = AsyncData(
        cur == null
            ? ActivityListState(
                events: fetched,
                names: names,
                hasMore: fetched.length >= pageSize,
              )
            : cur.copyWith(
                events: _merge(cur.events, fetched),
                names: names.isEmpty ? cur.names : names,
              ),
      );
    } catch (_) {
      // data lama tetap
    } finally {
      _refreshing = false;
    }
  }

  /// Muat halaman yang lebih lama. Galat ditandai di state, dicoba ulang
  /// pengguna.
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.loadingMore || !cur.hasMore || cur.events.isEmpty) {
      return;
    }
    state = AsyncData(cur.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final older = await ref
          .read(activityRepositoryProvider)
          .fetchEvents(
            circleId,
            before: cur.events.last.createdAt,
            limit: pageSize,
          );
      if (!ref.mounted) return;
      final latest = state.value ?? cur;
      state = AsyncData(
        latest.copyWith(
          events: _merge(latest.events, older),
          hasMore: older.length >= pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(
        (state.value ?? cur).copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

/// Gabungan tanpa duplikat (menurut id), terbaru dulu.
List<ActivityEvent> _merge(List<ActivityEvent> a, List<ActivityEvent> b) {
  final byId = {for (final e in a) e.id: e, for (final e in b) e.id: e};
  return byId.values.toList()..sort((x, y) {
    final c = y.createdAt.compareTo(x.createdAt);
    return c != 0 ? c : y.id.compareTo(x.id);
  });
}

// ---------------------------------------------------------------------------
// Lencana belum dibaca dan notifikasi lokal
// ---------------------------------------------------------------------------

/// Tujuan tombol "Lihat di peta" pada kartu SOS. Peta membaca ini untuk
/// memusatkan kamera, lalu mengosongkannya.
class ActivityMapFocus {
  const ActivityMapFocus({
    required this.circleId,
    required this.lat,
    required this.lng,
  });

  final String circleId;
  final double lat;
  final double lng;
}

class ActivityMapFocusNotifier extends Notifier<ActivityMapFocus?> {
  @override
  ActivityMapFocus? build() => null;

  void focus(ActivityMapFocus target) => state = target;

  void clear() => state = null;
}

final activityMapFocusProvider =
    NotifierProvider<ActivityMapFocusNotifier, ActivityMapFocus?>(
      ActivityMapFocusNotifier.new,
    );

/// Jumlah event orang lain yang belum dibaca di semua Circle (lencana tab
/// Aktivitas). Sekaligus pemantau event baru: menampilkan notifikasi lokal
/// selagi aplikasi terbuka. Harus tetap ditonton selama pengguna masuk
/// (dipasang lewat ActivityTabIcon di tab bar).
final activityUnreadProvider = NotifierProvider<ActivityUnread, int>(
  ActivityUnread.new,
);

class ActivityUnread extends Notifier<int> {
  static const _seenLimit = 500;

  final _unreadIds = <String>{};
  final _seen = <String>{};
  final _sosClientIds = <String>{};
  final _names = <String, Map<String, String>>{};
  final _circleNames = <String, String?>{};

  String? _uid;
  DateTime? _marker;
  DateTime? _latestSeen;
  bool _tabVisible = false;
  bool _wasDisconnected = false;

  @override
  int build() {
    _unreadIds.clear();
    _seen.clear();
    _sosClientIds.clear();
    _names.clear();
    _circleNames.clear();
    // Keadaan milik pengguna sebelumnya tidak boleh bocor ke akun berikutnya.
    _marker = null;
    _latestSeen = null;
    _wasDisconnected = false;
    _uid = ref.watch(currentUserIdProvider);
    final uid = _uid;
    if (uid == null) return 0;
    final repo = ref.watch(activityRepositoryProvider);
    final gateway = ref.watch(notificationGatewayProvider);

    final sub = repo.realtimeEvents().listen(
      (e) => _onRealtime(e, repo, gateway),
      onError: (Object _) => _wasDisconnected = true,
    );
    ref.onDispose(sub.cancel);
    final tapSub = gateway.taps.listen(
      (circleId) =>
          ref.read(selectedCircleIdProvider.notifier).select(circleId),
    );
    ref.onDispose(tapSub.cancel);
    unawaited(_start(uid, repo, gateway));
    return 0;
  }

  Future<void> _start(
    String uid,
    ActivityRepository repo,
    NotificationGateway gateway,
  ) async {
    await gateway.initialize();
    unawaited(gateway.requestPermission());
    final store = ref.read(readMarkerStoreProvider);
    try {
      _marker = await store.read();
      if (!ref.mounted) return;
      if (_marker == null) {
        // Pertama kali: semua yang sudah ada dianggap terbaca.
        _marker = ref.read(activityClockProvider);
        await store.write(_marker!);
        return;
      }
      await _loadUnread(repo, uid);
    } catch (_) {
      // Lencana tertunda sampai event berikutnya; bukan galat bagi pengguna.
    }
  }

  Future<void> _loadUnread(ActivityRepository repo, String uid) async {
    final marker = _marker;
    if (marker == null) return;
    final ids = await repo.fetchEventIdsSince(marker, excludeUserId: uid);
    if (!ref.mounted) return;
    for (final id in ids) {
      _remember(id);
    }
    if (!_tabVisible) _unreadIds.addAll(ids);
    state = _unreadIds.length;
  }

  void _remember(String id) {
    _seen.add(id);
    if (_seen.length > _seenLimit) _seen.remove(_seen.first);
  }

  void _onRealtime(
    ActivityRealtime e,
    ActivityRepository repo,
    NotificationGateway gateway,
  ) {
    switch (e) {
      case ActivityConnectionChanged(:final connected):
        if (!connected) {
          _wasDisconnected = true;
        } else if (_wasDisconnected) {
          _wasDisconnected = false;
          final uid = _uid;
          if (uid != null) {
            unawaited(_loadUnread(repo, uid).catchError((Object _) {}));
          }
        }
      case EventInserted(:final event):
        unawaited(_onEvent(event, repo, gateway));
    }
  }

  Future<void> _onEvent(
    ActivityEvent event,
    ActivityRepository repo,
    NotificationGateway gateway,
  ) async {
    if (event.userId == _uid) return; // milik sendiri: tanpa lencana/notifikasi
    if (!_seen.add(event.id)) return; // duplikat setelah sambung ulang
    if (_seen.length > _seenLimit) _seen.remove(_seen.first);
    if (_latestSeen == null || event.createdAt.isAfter(_latestSeen!)) {
      _latestSeen = event.createdAt;
    }
    final isSos = event.type == ActivityType.sos;
    // Dedup notifikasi SOS: satu pemicu SOS menghasilkan satu event per Circle,
    // jadi anggota yang berbagi dua Circle dengan pengirim melihat dua event.
    // Notifikasi lokal cukup sekali per client_id (server punya dedup serupa di outbox).
    if (isSos && event.clientId != null) {
      final clientId = event.clientId!;
      if (_sosClientIds.contains(clientId)) return;
      _sosClientIds.add(clientId);
      if (_sosClientIds.length > _seenLimit) {
        _sosClientIds.remove(_sosClientIds.first);
      }
    }
    if (_tabVisible) {
      unawaited(_persistMarker(null));
    } else {
      _unreadIds.add(event.id);
      state = _unreadIds.length;
    }
    // Daftar sedang terlihat: event biasa tidak perlu notifikasi lagi.
    if (_tabVisible && !isSos) return;

    final names = await _namesFor(repo, event);
    final circleName = await _circleNameFor(repo, event.circleId);
    if (!ref.mounted) return;
    final who =
        event.displayName ?? names[event.userId] ?? ActivityStrings.someone;
    await gateway.show(
      LocalNotification(
        id: event.id.hashCode & 0x7fffffff,
        title: isSos
            ? ActivityStrings.sosNotificationTitle(who)
            : circleName ?? ActivityStrings.notificationDefaultTitle,
        body: isSos
            ? ActivityStrings.sosNotificationBody(circleName)
            : ActivityStrings.sentence(event, who),
        urgency: isSos ? NotificationUrgency.high : NotificationUrgency.normal,
        payload: event.circleId,
      ),
    );
  }

  Future<Map<String, String>> _namesFor(
    ActivityRepository repo,
    ActivityEvent event,
  ) async {
    if (event.displayName != null) return const {};
    final cached = _names[event.circleId];
    if (cached != null && cached.containsKey(event.userId)) return cached;
    try {
      return _names[event.circleId] = await repo.fetchMemberNames(
        event.circleId,
      );
    } catch (_) {
      return cached ?? const {};
    }
  }

  Future<String?> _circleNameFor(ActivityRepository repo, String id) async {
    if (_circleNames.containsKey(id)) return _circleNames[id];
    try {
      return _circleNames[id] = await repo.fetchCircleName(id);
    } catch (_) {
      return null;
    }
  }

  /// Dipanggil tab Aktivitas saat terlihat atau tersembunyi (aplikasi di
  /// latar belakang dihitung tersembunyi).
  void setTabVisible(bool visible) => _tabVisible = visible;

  /// Tandai semua terbaca (tab Aktivitas dibuka). [newestSeen] adalah
  /// created_at event terbaru yang tampil di daftar.
  Future<void> markAllRead({DateTime? newestSeen}) async {
    _unreadIds.clear();
    state = 0;
    await _persistMarker(newestSeen);
  }

  /// Penanda memakai waktu server (created_at) agar tahan selisih jam perangkat.
  Future<void> _persistMarker(DateTime? newestSeen) async {
    var candidate = _latestSeen;
    if (newestSeen != null &&
        (candidate == null || newestSeen.isAfter(candidate))) {
      candidate = newestSeen;
    }
    final current = _marker;
    final DateTime next;
    if (candidate == null) {
      next = current ?? ref.read(activityClockProvider);
    } else if (current != null && current.isAfter(candidate)) {
      next = current;
    } else {
      next = candidate;
    }
    if (current != null && !next.isAfter(current)) return;
    _marker = next;
    try {
      await ref.read(readMarkerStoreProvider).write(next);
    } catch (_) {
      // penanda lokal gagal tersimpan: lencana bisa muncul lagi saat mulai
    }
  }
}
