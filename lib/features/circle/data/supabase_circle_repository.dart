import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/circle.dart';
import '../domain/circle_repository.dart';
import 'circle_mappers.dart';

class SupabaseCircleRepository implements CircleRepository {
  SupabaseCircleRepository(this._client);

  final SupabaseClient _client;

  static const _memberColumns =
      'role, joined_at, sharing_enabled, paused_until, user_id, '
      'profiles(display_name, color)';

  /// Tipe event yang mengubah daftar anggota atau status jeda/berbagi.
  static const memberEventTypes = {
    'member_joined',
    'member_left',
    'member_removed',
    'paused',
    'resumed',
    'sharing_changed',
  };

  @override
  Future<List<Circle>> myCircles() async {
    try {
      final rows = await _client
          .from('circles')
          .select('id, name')
          .order('created_at', ascending: true);
      return [
        for (final r in rows)
          Circle(id: r['id'] as String, name: r['name'] as String),
      ];
    } catch (e) {
      throw mapCircleError(e);
    }
  }

  @override
  Future<List<CircleMember>> members(String circleId) async {
    try {
      final rows = await _client
          .from('circle_members')
          .select(_memberColumns)
          .eq('circle_id', circleId)
          .order('joined_at', ascending: true);
      return [for (final r in rows) memberFromRow(r)];
    } catch (e) {
      throw mapCircleError(e, forbidden: CircleErrorKind.notMember);
    }
  }

  @override
  Future<String> createCircle(String name) async {
    try {
      final id = await _client.rpc('create_circle', params: {'p_name': name});
      return id as String;
    } catch (e) {
      throw mapCircleError(e);
    }
  }

  @override
  Future<CircleInvite> createInvite(String circleId) async {
    try {
      final rows =
          await _client.rpc('create_invite', params: {'p_circle_id': circleId})
              as List;
      final row = rows.first as Map<String, dynamic>;
      return CircleInvite(
        code: row['code'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
      );
    } catch (e) {
      throw mapCircleError(e);
    }
  }

  @override
  Future<InvitePreview?> previewInvite(String code) async {
    try {
      final rows =
          await _client.rpc('preview_invite', params: {'p_code': code}) as List;
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return InvitePreview(
        circleName: row['circle_name'] as String,
        memberCount: (row['member_count'] as num).toInt(),
      );
    } catch (e) {
      throw mapCircleError(e);
    }
  }

  @override
  Future<String?> joinCircle(String code) async {
    try {
      final id = await _client.rpc('join_circle', params: {'p_code': code});
      return id as String?;
    } catch (e) {
      throw mapCircleError(e);
    }
  }

  @override
  Future<void> leaveCircle(String circleId) async {
    try {
      await _client.rpc('leave_circle', params: {'p_circle_id': circleId});
    } catch (e) {
      throw mapCircleError(e, forbidden: CircleErrorKind.notMember);
    }
  }

  @override
  Future<void> removeMember(String circleId, String userId) async {
    try {
      await _client.rpc(
        'remove_member',
        params: {'p_circle_id': circleId, 'p_user_id': userId},
      );
    } catch (e) {
      throw mapCircleError(e);
    }
  }

  @override
  Future<void> setSharingEnabled(String circleId, bool enabled) async {
    try {
      await _client.rpc(
        'set_sharing_enabled',
        params: {'p_circle_id': circleId, 'p_enabled': enabled},
      );
    } catch (e) {
      throw mapCircleError(e, forbidden: CircleErrorKind.notMember);
    }
  }

  /// circle_members tidak ada di publikasi Realtime, jadi mendengarkan INSERT
  /// pada `events` (RLS: hanya anggota Circle yang menerima).
  @override
  Stream<void> memberChanges(String circleId) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('circle-members:$circleId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'events',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'circle_id',
                value: circleId,
              ),
              callback: (payload) {
                if (memberEventTypes.contains(payload.newRecord['type'])) {
                  controller.add(null);
                }
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final c = channel;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return controller.stream;
  }
}
