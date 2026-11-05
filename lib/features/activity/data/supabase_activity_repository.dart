import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_event.dart';
import '../domain/activity_repository.dart';
import 'activity_mappers.dart';

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this._client);

  final SupabaseClient _client;

  static int _channelSeq = 0;

  @override
  Future<List<ActivityEvent>> fetchEvents(
    String circleId, {
    DateTime? before,
    int limit = 30,
  }) async {
    try {
      var query = _client
          .from('events')
          .select('id, circle_id, user_id, type, created_at, payload')
          .eq('circle_id', circleId)
          .inFilter('type', ActivityType.wireValues);
      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      // order() bawaan MENURUN; ditulis eksplisit.
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in rows) ?activityEventFromRow(r)];
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<Map<String, String>> fetchMemberNames(String circleId) async {
    try {
      final rows = await _client
          .from('circle_members')
          .select('user_id, profiles(display_name)')
          .eq('circle_id', circleId);
      return {
        for (final r in rows)
          if ((r['profiles'] as Map?)?['display_name'] is String)
            r['user_id'] as String:
                (r['profiles'] as Map)['display_name'] as String,
      };
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String?> fetchCircleName(String circleId) async {
    try {
      final row = await _client
          .from('circles')
          .select('name')
          .eq('id', circleId)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<String>> fetchEventIdsSince(
    DateTime since, {
    required String excludeUserId,
    int cap = 100,
  }) async {
    try {
      final rows = await _client
          .from('events')
          .select('id')
          .neq('user_id', excludeUserId)
          .gt('created_at', since.toUtc().toIso8601String())
          .inFilter('type', ActivityType.wireValues)
          .limit(cap);
      return [for (final r in rows) r['id'] as String];
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Stream<ActivityRealtime> realtimeEvents({String? circleId}) {
    late final StreamController<ActivityRealtime> controller;
    RealtimeChannel? channel;
    controller = StreamController<ActivityRealtime>(
      onListen: () {
        // Nama unik: satu instance channel hanya boleh subscribe sekali.
        channel = _client
            .channel('activity-${circleId.hashCode}-${_channelSeq++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'events',
              filter: circleId == null
                  ? null
                  : PostgresChangeFilter(
                      type: PostgresChangeFilterType.eq,
                      column: 'circle_id',
                      value: circleId,
                    ),
              callback: (p) {
                if (controller.isClosed) return;
                final event = activityEventFromRow(p.newRecord);
                if (event != null) controller.add(EventInserted(event));
              },
            )
            .subscribe((status, _) {
              if (controller.isClosed) return;
              controller.add(
                ActivityConnectionChanged(
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

  ActivityFailure _map(Object e) {
    if (e is ActivityFailure) return e;
    if (e is SocketException ||
        e is TimeoutException ||
        e is AuthRetryableFetchException ||
        // ClientException milik paket http (tidak diimpor langsung).
        e.runtimeType.toString() == 'ClientException') {
      return const ActivityFailure(ActivityFailureKind.network);
    }
    if (e is AuthException) {
      return const ActivityFailure(ActivityFailureKind.unauthenticated);
    }
    if (e is PostgrestException &&
        (e.code == '28000' || e.code == 'PGRST301')) {
      return const ActivityFailure(ActivityFailureKind.unauthenticated);
    }
    return const ActivityFailure(ActivityFailureKind.unknown);
  }
}
