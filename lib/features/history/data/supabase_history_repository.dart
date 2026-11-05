import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../map/domain/geography.dart';
import '../domain/history_point.dart';
import '../domain/history_repository.dart';

class SupabaseHistoryRepository implements HistoryRepository {
  SupabaseHistoryRepository(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _now;

  @override
  Future<List<HistoryPoint>> fetchLast48h() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const HistoryFailure(HistoryFailureKind.unauthorized);
    }
    final since = _now().toUtc().subtract(HistoryRepository.window);
    try {
      // RLS juga membolehkan titik anggota Circle lain: filter user_id wajib.
      final rows = await _client
          .from('location_points')
          .select('point, recorded_at, accuracy_m, is_moving')
          .eq('user_id', uid)
          .gte('recorded_at', since.toIso8601String())
          .order('recorded_at', ascending: false)
          .limit(maxHistoryPoints);
      return [for (final r in rows) ?parseHistoryRow(r)];
    } catch (e) {
      throw mapHistoryError(e);
    }
  }

  @override
  Future<int> deleteAll() async {
    try {
      final n = await _client.rpc('delete_my_location_history');
      return n is int ? n : 0;
    } catch (e) {
      throw mapHistoryError(e);
    }
  }
}

/// Galat teknis -> [HistoryFailure].
HistoryFailure mapHistoryError(Object e) {
  if (e is HistoryFailure) return e;
  if (e is SocketException ||
      e is TimeoutException ||
      e is AuthRetryableFetchException ||
      // ClientException milik paket http (tidak diimpor langsung).
      e.runtimeType.toString() == 'ClientException') {
    return const HistoryFailure(HistoryFailureKind.network);
  }
  // 28000 (RPC tanpa auth.uid) atau 42501 (hak ditolak) / JWT tak sah.
  if (e is PostgrestException &&
      (e.code == '28000' || e.code == '42501' || e.code == 'PGRST301')) {
    return const HistoryFailure(HistoryFailureKind.unauthorized);
  }
  return const HistoryFailure(HistoryFailureKind.unknown);
}

/// Baris location_points -> [HistoryPoint]; null bila titik/waktu tidak sah.
HistoryPoint? parseHistoryRow(Map<String, dynamic> row) {
  final point = parseGeographyPoint(row['point']);
  final at = DateTime.tryParse('${row['recorded_at']}');
  if (point == null || at == null) return null;
  final acc = row['accuracy_m'];
  return HistoryPoint(
    point: point,
    recordedAt: at.toLocal(),
    accuracyM: acc is num ? acc.toDouble() : null,
    isMoving: row['is_moving'] == true,
  );
}
