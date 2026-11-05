import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/safety_error.dart';
import '../domain/safety_repository.dart';

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> checkin(String circleId, CheckinKind kind) async {
    try {
      await _client.rpc(
        'checkin',
        params: {'p_circle_id': circleId, 'p_kind': kind.wire},
      );
    } catch (e) {
      throw mapSafetyError(e);
    }
  }

  @override
  Future<int> triggerSos({
    required double lat,
    required double lng,
    double? accuracyM,
    required String clientId,
    required DateTime triggeredAt,
  }) async {
    try {
      final res = await _client.rpc(
        'trigger_sos',
        params: {
          'p_lat': lat,
          'p_lng': lng,
          'p_accuracy_m': accuracyM,
          'p_client_id': clientId,
          'p_triggered_at': triggeredAt.toUtc().toIso8601String(),
        },
      );
      return res is num ? res.toInt() : 0;
    } catch (e) {
      // Hanya kode galat yang dipakai: pesan/detail server tidak diteruskan.
      throw mapSafetyError(e);
    }
  }
}

/// Memetakan galat apa pun ke [SafetyError] tanpa membawa pesan asli.
SafetyError mapSafetyError(Object e) {
  if (e is SafetyError) return e;
  if (e is SocketException ||
      e is TimeoutException ||
      e is AuthRetryableFetchException ||
      // ClientException milik paket http (tidak diimpor langsung).
      e.runtimeType.toString() == 'ClientException') {
    return const SafetyError(SafetyErrorKind.network);
  }
  if (e is PostgrestException) {
    return SafetyError(switch (e.code) {
      'TH006' || 'TH007' => SafetyErrorKind.rateLimited,
      'TH008' => SafetyErrorKind.noCircle,
      '42501' => SafetyErrorKind.notMember,
      '28000' || 'PGRST301' => SafetyErrorKind.notSignedIn,
      '22023' => SafetyErrorKind.invalidArgument,
      _ => SafetyErrorKind.unknown,
    });
  }
  return const SafetyError(SafetyErrorKind.unknown);
}
