import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/circle.dart';
import '../domain/circle_error.dart';

/// Hasil parsing paused_until.
typedef ParsedPause = ({DateTime? until, bool indefinite});

/// paused_until bisa null, timestamp, atau 'infinity' (dijeda tanpa batas).
/// DateTime.parse gagal untuk 'infinity', jadi ditangani khusus. '-infinity'
/// berarti sudah lewat (tidak dijeda).
ParsedPause parsePausedUntil(Object? raw) {
  if (raw is! String) return (until: null, indefinite: false);
  final trimmed = raw.trim();
  final s = trimmed.toLowerCase();
  if (s == 'infinity' || s == '+infinity')
    return (until: null, indefinite: true);
  if (s.isEmpty || s == '-infinity') return (until: null, indefinite: false);
  return (until: DateTime.tryParse(trimmed)?.toUtc(), indefinite: false);
}

/// Baris `circle_members?select=role,joined_at,sharing_enabled,paused_until,
/// user_id,profiles(display_name,color)`.
CircleMember memberFromRow(Map<String, dynamic> row) {
  final profile = row['profiles'];
  final profileMap = profile is Map ? profile : const {};
  final pause = parsePausedUntil(row['paused_until']);
  return CircleMember(
    userId: row['user_id'] as String,
    displayName: (profileMap['display_name'] as String?) ?? '?',
    color: (profileMap['color'] as String?) ?? '',
    role: row['role'] == 'admin' ? CircleRole.admin : CircleRole.member,
    joinedAt:
        DateTime.tryParse((row['joined_at'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    sharingEnabled: (row['sharing_enabled'] as bool?) ?? true,
    pausedUntil: pause.until,
    pausedIndefinitely: pause.indefinite,
  );
}

/// Memetakan galat apa pun ke [CircleError]. SQLSTATE 42501 berarti "bukan
/// admin" atau "bukan anggota" tergantung RPC, jadi pemanggil memberi
/// [forbidden].
CircleError mapCircleError(
  Object e, {
  CircleErrorKind forbidden = CircleErrorKind.notAdmin,
}) {
  if (e is CircleError) return e;
  if (e is SocketException || e is TimeoutException) {
    return const CircleError(CircleErrorKind.network);
  }
  if (e is PostgrestException) {
    return CircleError(switch (e.code) {
      '28000' => CircleErrorKind.notSignedIn,
      '22023' => CircleErrorKind.invalidArgument,
      '42501' => forbidden,
      'P0002' => CircleErrorKind.notFound,
      'TH002' => CircleErrorKind.tooManyAttempts,
      'TH003' => CircleErrorKind.circleFull,
      'TH004' => CircleErrorKind.circleLimit,
      _ => CircleErrorKind.unknown,
    });
  }
  return const CircleError(CircleErrorKind.unknown);
}
