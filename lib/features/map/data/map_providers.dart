import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/map_circle.dart';
import '../domain/map_member.dart';
import '../domain/map_repository.dart';
import 'supabase_map_repository.dart';

/// Override di tes dengan repository palsu.
final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => SupabaseMapRepository(ref.watch(supabaseClientProvider)),
);

/// Penyedia tile. Override di tes agar tidak mengakses jaringan.
final mapTileProviderProvider = Provider<TileProvider>(
  (ref) => NetworkTileProvider(),
);

/// Jam peta: memperbarui waktu relatif dan status jeda/basi tiap 30 detik.
/// Override di tes dengan subclass yang waktunya tetap.
class MapClock extends Notifier<DateTime> {
  static const tick = Duration(seconds: 30);

  @override
  DateTime build() {
    final timer = Timer.periodic(tick, (_) => state = DateTime.now());
    ref.onDispose(timer.cancel);
    return DateTime.now();
  }
}

final mapClockProvider = NotifierProvider<MapClock, DateTime>(MapClock.new);

/// Circle milik pengguna yang sedang masuk. Dimuat ulang bila pengguna ganti.
final mapCirclesProvider = FutureProvider<List<MapCircle>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.watch(mapRepositoryProvider).fetchCircles();
}, retry: (_, _) => null);

/// Keadaan peta satu Circle.
class MapSnapshot {
  const MapSnapshot({
    required this.members,
    required this.selfId,
    this.realtimeConnected = true,
  });

  final List<MapMember> members;
  final String? selfId;

  /// False selagi koneksi realtime terputus (data bisa tertinggal).
  final bool realtimeConnected;

  MapMember? get self {
    for (final m in members) {
      if (m.userId == selfId) return m;
    }
    return null;
  }

  MapSnapshot copyWith({List<MapMember>? members, bool? realtimeConnected}) =>
      MapSnapshot(
        members: members ?? this.members,
        selfId: selfId,
        realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      );
}

/// Anggota satu Circle. Diperbarui lewat Realtime tanpa kilatan loading.
final mapMembersProvider =
    AsyncNotifierProvider.family<MapMembersNotifier, MapSnapshot, String>(
      MapMembersNotifier.new,
      isAutoDispose: true,
      retry: (_, _) => null, // pengguna memicu ulang lewat tombol
    );

class MapMembersNotifier extends AsyncNotifier<MapSnapshot> {
  MapMembersNotifier(this.circleId);

  final String circleId;

  Timer? _expiryTimer;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _wasDisconnected = false;

  @override
  Future<MapSnapshot> build() async {
    final selfId = ref.watch(currentUserIdProvider);
    final repo = ref.watch(mapRepositoryProvider);
    // Berlangganan lebih dulu agar tidak ada celah antara muat awal dan event.
    final sub = repo
        .realtimeEvents(circleId)
        .listen(_onEvent, onError: (Object _) => _setConnected(false));
    ref.onDispose(sub.cancel);
    ref.onDispose(() => _expiryTimer?.cancel());
    final members = await repo.fetchMembers(circleId);
    final snapshot = MapSnapshot(members: members, selfId: selfId);
    _scheduleExpiry(members);
    return snapshot;
  }

  void _onEvent(MapRealtimeEvent e) {
    switch (e) {
      case StatusChanged(:final userId, :final location):
        final cur = state.value;
        if (cur == null) return;
        // Saring ke anggota Circle ini (member_status tidak punya circle_id).
        if (!cur.members.any((m) => m.userId == userId)) return;
        state = AsyncData(
          cur.copyWith(
            members: [
              for (final m in cur.members)
                if (m.userId == userId && location != null)
                  m.copyWith(location: location)
                else
                  m,
            ],
          ),
        );
      case RefreshNeeded():
        unawaited(refresh());
      case ConnectionChanged(:final connected):
        _setConnected(connected);
    }
  }

  void _setConnected(bool connected) {
    final cur = state.value;
    if (connected && _wasDisconnected) {
      _wasDisconnected = false;
      unawaited(refresh()); // tersambung kembali: muat ulang data yang terlewat
    }
    if (!connected) _wasDisconnected = true;
    if (cur != null && cur.realtimeConnected != connected) {
      state = AsyncData(cur.copyWith(realtimeConnected: connected));
    }
  }

  /// Ambil ulang anggota tanpa menampilkan loading. Galat jaringan diabaikan
  /// (data lama tetap). Permintaan bersamaan digabung.
  Future<void> refresh() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final members = await ref
          .read(mapRepositoryProvider)
          .fetchMembers(circleId);
      if (!ref.mounted) return;
      final cur = state.value;
      state = AsyncData(
        (cur ??
                MapSnapshot(
                  members: members,
                  selfId: ref.read(currentUserIdProvider),
                ))
            .copyWith(members: members),
      );
      _scheduleExpiry(members);
    } catch (_) {
      // data lama tetap
    } finally {
      _refreshing = false;
      if (_refreshQueued && ref.mounted) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  /// Jeda diri sendiri di Circle ini. Melempar [MapFailure].
  Future<void> pause({int? minutes}) async {
    await ref
        .read(mapRepositoryProvider)
        .pauseSharing(circleId, minutes: minutes);
    await refresh();
  }

  Future<void> resume() async {
    await ref.read(mapRepositoryProvider).resumeSharing(circleId);
    await refresh();
  }

  /// Setelah jeda anggota lain berakhir, member_status mereka baru terlihat
  /// lagi (RLS) tanpa event apa pun: muat ulang tepat saat jeda terdekat habis.
  void _scheduleExpiry(List<MapMember> members) {
    _expiryTimer?.cancel();
    final now = ref.read(mapClockProvider);
    DateTime? next;
    for (final m in members) {
      final until = m.pause.until;
      if (until != null && until.isAfter(now)) {
        if (next == null || until.isBefore(next)) next = until;
      }
    }
    if (next == null) return;
    _expiryTimer = Timer(
      next.difference(now) + const Duration(seconds: 1),
      () => unawaited(refresh()),
    );
  }
}
