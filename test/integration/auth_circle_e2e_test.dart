// Tes integrasi ujung ke ujung auth + profil + Circle terhadap Supabase LOKAL
// yang sedang berjalan, memakai kelas produksi (SupabaseAuthRepository,
// SupabaseProfileRepository, SupabaseCircleRepository). Dilewati bila
// SUPABASE_URL atau SUPABASE_ANON_KEY kosong. Kunci tidak pernah disimpan:
//   set -a; eval "$(npx supabase status -o env)"; set +a
//   SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY \
//     flutter test test/integration/auth_circle_e2e_test.dart
//
// Tiap run mendaftarkan 2 pengguna baru (email unik, domain example.test) agar
// hemat batas laju pendaftaran auth lokal. Pengguna tidak bisa dihapus lewat
// klien, jadi dibiarkan; Circle uji hilang karena anggota terakhir keluar.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/core/member_colors.dart';
import 'package:tether/features/auth/data/supabase_auth_repository.dart';
import 'package:tether/features/auth/domain/auth_repository.dart';
import 'package:tether/features/circle/data/supabase_circle_repository.dart';
import 'package:tether/features/circle/domain/circle.dart';
import 'package:tether/features/circle/domain/circle_repository.dart';
import 'package:tether/features/circle/domain/invite_code.dart';
import 'package:tether/features/profile/data/supabase_profile_repository.dart';

const _urlDefine = String.fromEnvironment('SUPABASE_URL');
const _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

final String _url = _urlDefine.isNotEmpty
    ? _urlDefine
    : (Platform.environment['SUPABASE_URL'] ?? '');
final String _anonKey = _keyDefine.isNotEmpty
    ? _keyDefine
    : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');

final String? _skipReason = (_url.isEmpty || _anonKey.isEmpty)
    ? 'SUPABASE_URL atau SUPABASE_ANON_KEY kosong: jalankan Supabase lokal lalu '
          'berikan keduanya (lihat komentar di atas berkas ini)'
    : null;

Future<CircleError> _catchCircleError(Future<void> Function() f) async {
  try {
    await f();
  } on CircleError catch (e) {
    return e;
  }
  fail('seharusnya melempar CircleError');
}

void main() {
  test(
    'daftar, profil, buat Circle, undang, gabung, kode salah, keluar',
    () async {
      final run = DateTime.now().millisecondsSinceEpoch;
      const password = 'sandi-uji-e2e-1';
      // Tanpa Supabase.initialize tidak ada asyncStorage, jadi alur PKCE
      // (bawaan) tidak bisa dipakai: pakai implicit (tidak memengaruhi
      // signUp/signIn kata sandi).
      const authOptions = AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      );
      final clientA = SupabaseClient(_url, _anonKey, authOptions: authOptions);
      final clientB = SupabaseClient(_url, _anonKey, authOptions: authOptions);
      addTearDown(() async {
        await clientA.dispose();
        await clientB.dispose();
      });

      // --- A: daftar dengan nama tampilan; trigger profil membuat baris.
      final authA = SupabaseAuthRepository(clientA);
      final outcomeA = await authA.signUp(
        email: 'ayu-$run@example.test',
        password: password,
        displayName: 'Ayu Pertiwi',
      );
      expect(outcomeA, SignUpOutcome.signedIn);
      expect(authA.currentUserId, isNotNull);
      final idA = authA.currentUserId!;

      final profileA = SupabaseProfileRepository(clientA);
      final created = await profileA.fetchOwn();
      expect(created.id, idA);
      expect(created.displayName, 'Ayu Pertiwi'); // kontrak trigger profil
      expect(MemberColors.isValid(created.color), isTrue);

      // --- A: ubah nama dan warna.
      final updated = await profileA.updateOwn(
        displayName: 'Ayu P.',
        color: '#DB2777',
      );
      expect(updated.displayName, 'Ayu P.');
      expect(updated.color, '#DB2777');
      expect((await profileA.fetchOwn()).color, '#DB2777');

      // --- A: buat Circle.
      final circleA = SupabaseCircleRepository(clientA);
      expect(await circleA.myCircles(), isEmpty);
      final circleId = await circleA.createCircle('  Keluarga E2E  ');
      final mine = await circleA.myCircles();
      expect(mine.map((c) => c.id), [circleId]);
      expect(mine.single.name, 'Keluarga E2E'); // dipangkas server

      var members = await circleA.members(circleId);
      expect(members, hasLength(1));
      expect(members.single.userId, idA);
      expect(members.single.isAdmin, isTrue);
      expect(members.single.displayName, 'Ayu P.');
      expect(members.single.color, '#DB2777');
      expect(members.single.statusAt(DateTime.now()), SharingStatus.sharing);

      // Nama tidak valid -> invalidArgument.
      expect(
        (await _catchCircleError(() => circleA.createCircle('   '))).kind,
        CircleErrorKind.invalidArgument,
      );

      // --- A: berlangganan perubahan anggota (Realtime pada events).
      final changes = StreamController<void>.broadcast();
      final sub = circleA.memberChanges(circleId).listen(changes.add);
      addTearDown(sub.cancel);
      // Beri waktu kanal Realtime tersambung sebelum ada event.
      await Future<void>.delayed(const Duration(seconds: 3));

      // --- A: buat undangan.
      final invite = await circleA.createInvite(circleId);
      expect(invite.code, hasLength(InviteCode.length));
      expect(InviteCode.normalize(invite.code), invite.code);
      final ttl = invite.expiresAt.difference(DateTime.now().toUtc());
      expect(ttl, greaterThan(const Duration(hours: 47)));
      expect(ttl, lessThanOrEqualTo(const Duration(hours: 48, minutes: 1)));

      // --- B: daftar.
      final authB = SupabaseAuthRepository(clientB);
      await authB.signUp(
        email: 'budi-$run@example.test',
        password: password,
        displayName: 'Budi Santoso',
      );
      final idB = authB.currentUserId!;
      final circleB = SupabaseCircleRepository(clientB);
      expect(await circleB.myCircles(), isEmpty);

      // Bukan anggota: tidak bisa membaca anggota maupun membuat undangan.
      expect(await circleB.members(circleId), isEmpty);
      expect(
        (await _catchCircleError(() => circleB.createInvite(circleId))).kind,
        CircleErrorKind.notAdmin,
      );

      // --- B: pratinjau lalu gabung (kode longgar dinormalkan di klien).
      final typed = ' ${invite.code.toLowerCase()} ';
      final code = InviteCode.normalize(typed);
      expect(code, invite.code);
      final preview = await circleB.previewInvite(code);
      expect(preview, isNotNull);
      expect(preview!.circleName, 'Keluarga E2E');
      expect(preview.memberCount, 1);

      final eventAfterJoin = changes.stream.first.timeout(
        const Duration(seconds: 15),
      );
      expect(await circleB.joinCircle(code), circleId);
      expect((await circleB.myCircles()).map((c) => c.id), [circleId]);

      // --- A melihat B (nama dan warna) di daftar anggota.
      members = await circleA.members(circleId);
      expect(members, hasLength(2));
      final seenB = members.singleWhere((m) => m.userId == idB);
      expect(seenB.displayName, 'Budi Santoso');
      expect(seenB.role, CircleRole.member);
      expect(MemberColors.isValid(seenB.color), isTrue);
      expect(seenB.statusAt(DateTime.now()), SharingStatus.sharing);
      expect(members.first.userId, idA); // urut joined_at

      // Realtime: A menerima isyarat member_joined.
      await eventAfterJoin;

      // Anggota biasa tidak boleh mengeluarkan orang lain.
      expect(
        (await _catchCircleError(
          () => circleB.removeMember(circleId, idA),
        )).kind,
        CircleErrorKind.notAdmin,
      );

      // --- B: kode salah berulang. 10 gagal pertama NULL, ke-11 TH002.
      for (var i = 1; i <= 10; i++) {
        expect(await circleB.joinCircle('AAAAA2'), isNull, reason: 'ke-$i');
      }
      expect(
        (await _catchCircleError(() => circleB.joinCircle('AAAAA2'))).kind,
        CircleErrorKind.tooManyAttempts,
      );

      // --- B keluar; A melihat daftar berubah.
      final eventAfterLeave = changes.stream.first.timeout(
        const Duration(seconds: 15),
      );
      await circleB.leaveCircle(circleId);
      expect(await circleB.myCircles(), isEmpty);
      members = await circleA.members(circleId);
      expect(members.map((m) => m.userId), [idA]);
      await eventAfterLeave;

      // B bukan anggota lagi: keluar lagi -> notMember.
      expect(
        (await _catchCircleError(() => circleB.leaveCircle(circleId))).kind,
        CircleErrorKind.notMember,
      );

      // --- A (anggota terakhir) keluar: Circle hilang.
      await circleA.leaveCircle(circleId);
      expect(await circleA.myCircles(), isEmpty);
    },
    skip: _skipReason,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
