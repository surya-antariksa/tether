import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/circle/data/circle_mappers.dart';
import 'package:tether/features/circle/domain/circle.dart';
import 'package:tether/features/circle/domain/circle_error.dart';
import 'package:tether/features/circle/domain/invite_code.dart';

CircleErrorKind kindOf(
  Object e, {
  CircleErrorKind forbidden = CircleErrorKind.notAdmin,
}) => mapCircleError(e, forbidden: forbidden).kind;

PostgrestException pg(String code) =>
    PostgrestException(message: 'x', code: code);

void main() {
  group('parsePausedUntil', () {
    test('null dan non-string berarti tidak dijeda', () {
      expect(parsePausedUntil(null), (until: null, indefinite: false));
      expect(parsePausedUntil(42), (until: null, indefinite: false));
    });

    test('infinity berarti dijeda tanpa batas (tanpa melempar)', () {
      expect(parsePausedUntil('infinity'), (until: null, indefinite: true));
      expect(parsePausedUntil('Infinity'), (until: null, indefinite: true));
      expect(parsePausedUntil('+infinity'), (until: null, indefinite: true));
    });

    test('-infinity sudah lewat', () {
      expect(parsePausedUntil('-infinity'), (until: null, indefinite: false));
    });

    test('timestamp PostgREST di-parse ke UTC', () {
      final r = parsePausedUntil('2026-11-04T12:30:00+00:00');
      expect(r.indefinite, isFalse);
      expect(r.until, DateTime.utc(2026, 11, 4, 12, 30));
    });

    test('rusak tidak melempar', () {
      expect(parsePausedUntil('bukan tanggal'), (
        until: null,
        indefinite: false,
      ));
    });
  });

  group('memberFromRow', () {
    test('baris dengan profil, jeda tanpa batas', () {
      final m = memberFromRow({
        'user_id': 'u1',
        'role': 'admin',
        'joined_at': '2026-11-04T01:00:00+00:00',
        'sharing_enabled': true,
        'paused_until': 'infinity',
        'profiles': {'display_name': 'Rina', 'color': '#0F766E'},
      });
      expect(m.userId, 'u1');
      expect(m.displayName, 'Rina');
      expect(m.color, '#0F766E');
      expect(m.isAdmin, isTrue);
      expect(m.pausedIndefinitely, isTrue);
      expect(m.pausedUntil, isNull);
      expect(m.isPausedAt(DateTime.utc(2100)), isTrue);
    });

    test('profil hilang dan peran member', () {
      final m = memberFromRow({
        'user_id': 'u2',
        'role': 'member',
        'joined_at': '2026-11-04T01:00:00+00:00',
        'sharing_enabled': false,
        'paused_until': null,
        'profiles': null,
      });
      expect(m.displayName, '?');
      expect(m.role, CircleRole.member);
      expect(m.statusAt(DateTime.utc(2026, 11, 5)), SharingStatus.off);
    });
  });

  group('status jeda dihitung dari waktu', () {
    final now = DateTime.utc(2026, 11, 4, 12);
    CircleMember member({DateTime? until}) => CircleMember(
      userId: 'u',
      displayName: 'A',
      color: '#0F766E',
      role: CircleRole.member,
      joinedAt: now,
      pausedUntil: until,
    );

    test('jeda di masa depan = dijeda', () {
      expect(
        member(until: now.add(const Duration(minutes: 5))).statusAt(now),
        SharingStatus.paused,
      );
    });

    test('jeda kedaluwarsa = berbagi lagi tanpa ubah baris', () {
      expect(
        member(until: now.subtract(const Duration(minutes: 1))).statusAt(now),
        SharingStatus.sharing,
      );
    });

    test('tanpa jeda = berbagi', () {
      expect(member().statusAt(now), SharingStatus.sharing);
    });
  });

  group('mapCircleError', () {
    test('kode SQLSTATE dipetakan', () {
      expect(kindOf(pg('28000')), CircleErrorKind.notSignedIn);
      expect(kindOf(pg('22023')), CircleErrorKind.invalidArgument);
      expect(kindOf(pg('P0002')), CircleErrorKind.notFound);
      expect(kindOf(pg('TH002')), CircleErrorKind.tooManyAttempts);
      expect(kindOf(pg('TH003')), CircleErrorKind.circleFull);
      expect(kindOf(pg('TH004')), CircleErrorKind.circleLimit);
      expect(kindOf(pg('XX000')), CircleErrorKind.unknown);
    });

    test('42501 mengikuti konteks pemanggil', () {
      expect(kindOf(pg('42501')), CircleErrorKind.notAdmin);
      expect(
        kindOf(pg('42501'), forbidden: CircleErrorKind.notMember),
        CircleErrorKind.notMember,
      );
    });

    test('jaringan dan lainnya', () {
      expect(kindOf(const SocketException('x')), CircleErrorKind.network);
      expect(kindOf(TimeoutException('x')), CircleErrorKind.network);
      expect(kindOf(StateError('x')), CircleErrorKind.unknown);
    });

    test('CircleError yang sudah ada dipertahankan', () {
      const e = CircleError(CircleErrorKind.circleFull);
      expect(identical(mapCircleError(e), e), isTrue);
    });
  });

  group('InviteCode.normalize', () {
    test('huruf besar dan spasi dibuang', () {
      expect(InviteCode.normalize(' ab c 234 '), 'ABC234');
    });

    test('karakter di luar alfabet dibuang (0, O, 1, I, L, simbol)', () {
      expect(InviteCode.normalize('A0O1IL-B_C'), 'ABC');
    });

    test('dipotong 6 karakter', () {
      expect(InviteCode.normalize('abcdefghjk'), 'ABCDEF');
    });

    test('isComplete hanya untuk 6 karakter', () {
      expect(InviteCode.isComplete('ABC23'), isFalse);
      expect(InviteCode.isComplete('ABC234'), isTrue);
    });

    test('alfabet sama dengan database (31 simbol)', () {
      expect(InviteCode.alphabet, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
      expect(InviteCode.alphabet.length, 31);
    });
  });
}
