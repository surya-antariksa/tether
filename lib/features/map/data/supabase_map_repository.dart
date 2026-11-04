import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/member_colors.dart';
import '../domain/geography.dart';
import '../domain/map_circle.dart';
import '../domain/map_member.dart';
import '../domain/map_repository.dart';
import '../domain/paused_until.dart';

class SupabaseMapRepository implements MapRepository {
  SupabaseMapRepository(this._client);

  final SupabaseClient _client;

  static int _channelSeq = 0;

  /// Event yang membuat daftar perlu dimuat ulang (circle_members tidak ada di
  /// publikasi Realtime, jadi perubahannya diketahui lewat events).
  static const _refreshEventTypes = {
    'paused',
    'resumed',
    'member_joined',
    'member_left',
    'member_removed',
  };

  @override
  Future<List<MapCircle>> fetchCircles() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw const MapFailure(MapFailureKind.unauthenticated);
      final rows = await _client
          .from('circle_members')
          .select('circle_id, joined_at, circles(name)')
          .eq('user_id', uid)
          .order('joined_at', ascending: true);
      return [
        for (final r in rows)
          MapCircle(
            id: r['circle_id'] as String,
            name: (r['circles'] as Map?)?['name'] as String? ?? '',
          ),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<MapMember>> fetchMembers(String circleId) async {
    try {
      final memberRows = await _client
          .from('circle_members')
          .select(
            'user_id, sharing_enabled, paused_until, profiles(display_name, color)',
          )
          .eq('circle_id', circleId);
      final ids = [for (final r in memberRows) r['user_id'] as String];
      final statusRows = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _client
                .from('member_status')
                .select(
                  'user_id, last_point, last_seen_at, battery_pct, is_moving',
                )
                .inFilter('user_id', ids);
      final locations = <String, MemberLocation>{};
      for (final r in statusRows) {
        final loc = locationFromRow(r);
        if (loc != null) locations[r['user_id'] as String] = loc;
      }
      return [
        for (final r in memberRows)
          () {
            final profile = r['profiles'] as Map?;
            final color = profile?['color'] as String?;
            return MapMember(
              userId: r['user_id'] as String,
              displayName: (profile?['display_name'] as String?) ?? '',
              colorHex: color != null && MemberColors.isValid(color)
                  ? color
                  : MemberColors.defaultHex,
              sharingEnabled: r['sharing_enabled'] as bool? ?? true,
              pause: PausedUntil.parse(r['paused_until']),
              location: locations[r['user_id']],
            );
          }(),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  /// Baris member_status (REST atau payload Realtime) menjadi [MemberLocation].
  /// Null bila titik atau waktu belum ada/tidak valid.
  static MemberLocation? locationFromRow(Map<dynamic, dynamic> r) {
    final point = parseGeographyPoint(r['last_point']);
    final seenRaw = r['last_seen_at'];
    final seen = seenRaw is String ? DateTime.tryParse(seenRaw) : null;
    if (point == null || seen == null) return null;
    return MemberLocation(
      point: point,
      lastSeenAt: seen,
      batteryPct: (r['battery_pct'] as num?)?.toInt(),
      isMoving: r['is_moving'] as bool?,
    );
  }

  @override
  Stream<MapRealtimeEvent> realtimeEvents(String circleId) {
    late final StreamController<MapRealtimeEvent> controller;
    RealtimeChannel? channel;
    controller = StreamController<MapRealtimeEvent>(
      onListen: () {
        // Nama unik: satu instance channel hanya boleh subscribe sekali.
        channel = _client
            .channel('map-${circleId.hashCode}-${_channelSeq++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'member_status',
              callback: (p) {
                if (controller.isClosed) return;
                final uid = p.newRecord['user_id'];
                // DELETE hanya membawa primary key: muat ulang.
                if (p.eventType == PostgresChangeEvent.delete ||
                    uid is! String) {
                  controller.add(const RefreshNeeded());
                } else {
                  controller.add(
                    StatusChanged(uid, locationFromRow(p.newRecord)),
                  );
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'events',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'circle_id',
                value: circleId,
              ),
              callback: (p) {
                if (controller.isClosed) return;
                if (_refreshEventTypes.contains(p.newRecord['type'])) {
                  controller.add(const RefreshNeeded());
                }
              },
            )
            .subscribe((status, _) {
              if (controller.isClosed) return;
              controller.add(
                ConnectionChanged(
                  connected: status == RealtimeSubscribeStatus.subscribed,
                ),
              );
            });
      },
      onCancel: () async {
        final ch = channel;
        if (ch != null) await _client.removeChannel(ch);
      },
    );
    return controller.stream;
  }

  @override
  Future<void> pauseSharing(String circleId, {int? minutes}) async {
    try {
      await _client.rpc(
        'pause_sharing',
        params: {'p_circle_id': circleId, 'p_minutes': minutes},
      );
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> resumeSharing(String circleId) async {
    try {
      await _client.rpc('resume_sharing', params: {'p_circle_id': circleId});
    } catch (e) {
      throw _map(e);
    }
  }

  MapFailure _map(Object e) {
    if (e is MapFailure) return e;
    if (e is SocketException ||
        e is TimeoutException ||
        e is AuthRetryableFetchException ||
        // ClientException milik paket http (tidak diimpor langsung).
        e.runtimeType.toString() == 'ClientException') {
      return const MapFailure(MapFailureKind.network);
    }
    if (e is PostgrestException) {
      return switch (e.code) {
        '28000' => const MapFailure(MapFailureKind.unauthenticated),
        '42501' => const MapFailure(MapFailureKind.notMember),
        '22023' => const MapFailure(MapFailureKind.invalid),
        _ => const MapFailure(MapFailureKind.unknown),
      };
    }
    return const MapFailure(MapFailureKind.unknown);
  }
}
