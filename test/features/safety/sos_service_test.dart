import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/safety/data/sos_service.dart';
import 'package:tether/features/safety/domain/safety_error.dart';
import 'package:tether/features/safety/domain/sos_models.dart';
import 'package:tether/features/safety/domain/sos_queue_store.dart';

import 'safety_fakes.dart';

final uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Penyimpanan yang selalu gagal menulis (disk penuh, berkas terkunci).
class FailingAddStore extends InMemorySosQueueStore {
  @override
  Future<void> add(PendingSos sos) async => throw Exception('disk penuh');
}

void main() {
  group('defaultSosBackoff', () {
    test('2, 4, 8, 16, 32 lalu tertahan di 60 detik', () {
      expect(
        [for (var i = 1; i <= 8; i++) defaultSosBackoff(i).inSeconds],
        [2, 4, 8, 16, 32, 60, 60, 60],
      );
    });
  });

  group('model', () {
    test('UUID v4 valid dan tidak berulang', () {
      final ids = {for (var i = 0; i < 50; i++) generateUuidV4()};
      expect(ids.length, 50);
      expect(ids.every(uuidV4.hasMatch), isTrue);
    });

    test('PendingSos bolak-balik JSON; toString tanpa koordinat', () {
      final sos = PendingSos(
        clientId: generateUuidV4(),
        userId: 'u1',
        triggeredAt: DateTime.utc(2026, 11, 5, 10, 0, 1, 234),
        fix: jakarta,
      );
      final back = PendingSos.fromJson(sos.toJson());
      expect(back.clientId, sos.clientId);
      expect(back.triggeredAt, sos.triggeredAt);
      expect(back.fix.lat, jakarta.lat);
      expect(back.fix.lng, jakarta.lng);
      expect(back.fix.accuracyM, 12);
      expect(
        '$sos $jakarta ${const SafetyError(SafetyErrorKind.network)}',
        isNot(contains('106')),
      );
      expect('$sos $jakarta', isNot(contains('6.2')));
    });

    test('SosFix.isValid menolak NaN, di luar rentang, akurasi negatif', () {
      expect(jakarta.isValid, isTrue);
      expect(const SosFix(lat: double.nan, lng: 0).isValid, isFalse);
      expect(const SosFix(lat: 91, lng: 0).isValid, isFalse);
      expect(const SosFix(lat: 0, lng: -181).isValid, isFalse);
      expect(const SosFix(lat: 0, lng: 0, accuracyM: -1).isValid, isFalse);
      expect(const SosFix(lat: 0, lng: 0).isValid, isTrue);
    });

    test(
      'isTransient: jaringan/sesi/tak dikenal sementara, sisanya permanen',
      () {
        bool t(SafetyErrorKind k) => SafetyError(k).isTransient;
        expect(t(SafetyErrorKind.network), isTrue);
        expect(t(SafetyErrorKind.notSignedIn), isTrue);
        expect(t(SafetyErrorKind.unknown), isTrue);
        expect(t(SafetyErrorKind.rateLimited), isFalse);
        expect(t(SafetyErrorKind.noCircle), isFalse);
        expect(t(SafetyErrorKind.notMember), isFalse);
        expect(t(SafetyErrorKind.invalidArgument), isFalse);
        expect(t(SafetyErrorKind.expired), isFalse);
      },
    );
  });

  group('SosService', () {
    late FakeSafetyRepository repo;
    late InMemorySosQueueStore store;
    late FakeSosLocation location;
    late DateTime clock;
    String? uid;

    setUp(() {
      repo = FakeSafetyRepository();
      store = InMemorySosQueueStore();
      location = FakeSosLocation(currentFix: jakarta);
      clock = DateTime.utc(2026, 11, 5, 10);
      uid = 'u1';
    });

    SosService make({Duration maxAge = const Duration(days: 1)}) => SosService(
      repository: repo,
      store: store,
      location: location,
      currentUserId: () => uid,
      now: () => clock,
      maxAge: maxAge,
    );

    test(
      'sukses: clientId v4 dan triggeredAt dari saat dipicu, antrean kosong',
      () {
        fakeAsync((async) {
          final svc = make();
          SosOutcome? out;
          svc.send(jakarta).then((o) => out = o);
          async.flushMicrotasks();
          expect(out, isA<SosSent>());
          expect((out as SosSent).circles, 2);
          final c = repo.sosCalls.single;
          expect(uuidV4.hasMatch(c.clientId), isTrue);
          expect(c.triggeredAt, DateTime.utc(2026, 11, 5, 10));
          expect(c.lat, jakarta.lat);
          expect(c.lng, jakarta.lng);
          expect(c.accuracyM, 12);
          store.load().then((l) => expect(l, isEmpty));
          async.flushMicrotasks();
          svc.dispose();
        });
      },
    );

    test('jaringan putus: antre, coba ulang dengan backoff, id dan waktu sama, '
        'event server hanya satu set', () {
      fakeAsync((async) {
        final svc = make();
        repo.sosScript.addAll([
          SafetyErrorKind.network,
          SafetyErrorKind.network,
          SafetyErrorKind.network,
        ]);
        final deliveries = <SosDelivery>[];
        svc.deliveries.listen(deliveries.add);

        SosOutcome? out;
        svc.send(jakarta).then((o) => out = o);
        async.flushMicrotasks();
        expect(out, isA<SosQueued>());
        expect(repo.sosCalls, hasLength(1));

        // Waktu berjalan; triggeredAt tidak boleh ikut berubah.
        clock = clock.add(const Duration(minutes: 3));
        async.elapse(const Duration(seconds: 1));
        expect(repo.sosCalls, hasLength(1)); // backoff pertama 2 detik
        async.elapse(const Duration(seconds: 1));
        expect(repo.sosCalls, hasLength(2)); // gagal lagi, jeda 4 detik
        async.elapse(const Duration(seconds: 3));
        expect(repo.sosCalls, hasLength(2));
        async.elapse(const Duration(seconds: 1));
        expect(repo.sosCalls, hasLength(3)); // gagal lagi, jeda 8 detik
        async.elapse(const Duration(seconds: 8));
        expect(repo.sosCalls, hasLength(4)); // sukses

        expect({for (final c in repo.sosCalls) c.clientId}, hasLength(1));
        expect(
          {for (final c in repo.sosCalls) c.triggeredAt},
          {DateTime.utc(2026, 11, 5, 10)},
        );
        expect(repo.eventsCreated, 2);
        expect(deliveries, hasLength(1));
        expect(deliveries.single.outcome, isA<SosSent>());

        async.elapse(const Duration(minutes: 5));
        expect(repo.sosCalls, hasLength(4)); // berhenti setelah berhasil
        store.load().then((l) => expect(l, isEmpty));
        async.flushMicrotasks();
        svc.dispose();
      });
    });

    test('trigger_sos menggantung: batas waktu 15 detik jadi antre, antrean '
        'serial tidak macet', () {
      fakeAsync((async) {
        final svc = make();
        repo.gate = Completer<void>(); // tidak pernah selesai
        SosOutcome? first;
        svc.send(jakarta).then((o) => first = o);
        async.elapse(const Duration(seconds: 14));
        expect(first, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(first, isA<SosQueued>());

        // Panggilan berikutnya (di antrean serial) tetap dijalankan.
        repo.gate = null;
        SosOutcome? second;
        svc.send(jakarta).then((o) => second = o);
        async.flushMicrotasks();
        expect(second, isA<SosSent>());
        // Coba ulang SOS pertama oleh backoff juga berjalan dan berhasil.
        async.elapse(const Duration(seconds: 3));
        expect(
          repo.sosCalls.where(
            (c) => c.clientId == repo.sosCalls.first.clientId,
          ),
          hasLength(2),
        );
        svc.dispose();
      });
    });

    test('penyimpanan gagal tetapi kirim berhasil: terkirim', () {
      fakeAsync((async) {
        final svc = SosService(
          repository: repo,
          store: FailingAddStore(),
          location: location,
          currentUserId: () => uid,
          now: () => clock,
        );
        SosOutcome? out;
        svc.send(jakarta).then((o) => out = o);
        async.flushMicrotasks();
        expect(out, isA<SosSent>());
        svc.dispose();
      });
    });

    test('penyimpanan gagal dan kirim gagal sementara: gagal jujur '
        '(notSaved), bukan antre, tanpa coba ulang', () {
      fakeAsync((async) {
        final svc = SosService(
          repository: repo,
          store: FailingAddStore(),
          location: location,
          currentUserId: () => uid,
          now: () => clock,
        );
        repo.sosScript.add(SafetyErrorKind.network);
        final deliveries = <SosDelivery>[];
        svc.deliveries.listen(deliveries.add);
        SosOutcome? out;
        svc.send(jakarta).then((o) => out = o);
        async.flushMicrotasks();
        expect(out, isA<SosRejected>());
        expect((out as SosRejected).kind, SafetyErrorKind.notSaved);
        async.elapse(const Duration(minutes: 5));
        expect(repo.sosCalls, hasLength(1));
        expect(deliveries.single.outcome, isA<SosRejected>());
        svc.dispose();
      });
    });

    test('SOS dicatat di penyimpanan sebelum dikirim', () {
      fakeAsync((async) {
        final svc = make();
        repo.gate = Completer<void>();
        svc.send(jakarta);
        async.flushMicrotasks();
        List<PendingSos>? during;
        store.load().then((l) => during = l);
        async.flushMicrotasks();
        expect(during, hasLength(1));
        expect(during!.single.userId, 'u1');
        repo.gate!.complete();
        async.flushMicrotasks();
        svc.dispose();
      });
    });

    test('kegagalan permanen dibuang tanpa coba ulang', () {
      for (final kind in [
        SafetyErrorKind.rateLimited, // TH007
        SafetyErrorKind.noCircle, // TH008
        SafetyErrorKind.notMember, // 42501
        SafetyErrorKind.invalidArgument, // 22023
      ]) {
        fakeAsync((async) {
          final r = FakeSafetyRepository()..sosScript.add(kind);
          final s = InMemorySosQueueStore();
          final svc = SosService(
            repository: r,
            store: s,
            location: location,
            currentUserId: () => uid,
            now: () => clock,
          );
          final deliveries = <SosDelivery>[];
          svc.deliveries.listen(deliveries.add);
          SosOutcome? out;
          svc.send(jakarta).then((o) => out = o);
          async.flushMicrotasks();
          expect(out, isA<SosRejected>(), reason: '$kind');
          expect((out as SosRejected).kind, kind);
          async.elapse(const Duration(minutes: 10));
          expect(r.sosCalls, hasLength(1), reason: '$kind tidak diulang');
          s.load().then((l) => expect(l, isEmpty));
          async.flushMicrotasks();
          expect(deliveries.single.outcome, isA<SosRejected>());
          svc.dispose();
        });
      }
    });

    test('galat tak dikenal diperlakukan sementara (diulang)', () {
      fakeAsync((async) {
        final svc = make();
        repo.sosScript.add(Exception('500'));
        SosOutcome? out;
        svc.send(jakarta).then((o) => out = o);
        async.flushMicrotasks();
        expect(out, isA<SosQueued>());
        async.elapse(const Duration(seconds: 2));
        expect(repo.sosCalls, hasLength(2));
        svc.dispose();
      });
    });

    test('kedaluwarsa setelah maxAge: dibuang, tidak dikirim', () {
      fakeAsync((async) {
        final svc = make(maxAge: const Duration(minutes: 10));
        repo.sosScript.add(SafetyErrorKind.network);
        svc.send(jakarta);
        async.flushMicrotasks();
        final deliveries = <SosDelivery>[];
        svc.deliveries.listen(deliveries.add);
        clock = clock.add(const Duration(minutes: 11));
        async.elapse(const Duration(seconds: 2));
        expect(repo.sosCalls, hasLength(1));
        expect(deliveries.single.outcome, isA<SosRejected>());
        expect(
          (deliveries.single.outcome as SosRejected).kind,
          SafetyErrorKind.expired,
        );
        store.load().then((l) => expect(l, isEmpty));
        async.flushMicrotasks();
        svc.dispose();
      });
    });

    test('proses baru melanjutkan antrean yang tersimpan (idempoten)', () {
      fakeAsync((async) {
        final first = make();
        repo.sosScript.add(SafetyErrorKind.network);
        first.send(jakarta);
        async.flushMicrotasks();
        first.dispose(); // aplikasi ditutup

        final second = make();
        second.flush();
        async.flushMicrotasks();
        expect(repo.sosCalls, hasLength(2));
        expect(repo.sosCalls[1].clientId, repo.sosCalls[0].clientId);
        expect(repo.sosCalls[1].triggeredAt, repo.sosCalls[0].triggeredAt);
        // Pengulangan sesudah sukses (mis. respons hilang) tetap aman.
        store.add(
          PendingSos(
            clientId: repo.sosCalls[0].clientId,
            userId: 'u1',
            triggeredAt: repo.sosCalls[0].triggeredAt,
            fix: jakarta,
          ),
        );
        second.flush();
        async.flushMicrotasks();
        expect(repo.sosCalls, hasLength(3));
        expect(repo.eventsCreated, 2, reason: 'server tidak menambah event');
        second.dispose();
      });
    });

    test('flush mengabaikan SOS milik akun lain dan tanpa login', () {
      fakeAsync((async) {
        store.add(
          PendingSos(
            clientId: generateUuidV4(),
            userId: 'orang-lain',
            triggeredAt: clock,
            fix: jakarta,
          ),
        );
        final svc = make();
        svc.flush();
        async.flushMicrotasks();
        expect(repo.sosCalls, isEmpty);
        uid = null;
        svc.flush();
        async.flushMicrotasks();
        expect(repo.sosCalls, isEmpty);
        store.load().then((l) => expect(l, hasLength(1)));
        async.flushMicrotasks();
        svc.dispose();
      });
    });

    test('flush mengirim dari yang tertua dan berhenti di gagal sementara', () {
      fakeAsync((async) {
        final older = PendingSos(
          clientId: generateUuidV4(),
          userId: 'u1',
          triggeredAt: clock.subtract(const Duration(minutes: 5)),
          fix: jakarta,
        );
        final newer = PendingSos(
          clientId: generateUuidV4(),
          userId: 'u1',
          triggeredAt: clock.subtract(const Duration(minutes: 1)),
          fix: jakarta,
        );
        store.add(newer);
        store.add(older);
        repo.sosScript.add(SafetyErrorKind.network);
        final svc = make();
        svc.flush();
        async.flushMicrotasks();
        expect(repo.sosCalls.map((c) => c.clientId), [older.clientId]);
        async.elapse(const Duration(seconds: 2));
        expect(repo.sosCalls.map((c) => c.clientId), [
          older.clientId,
          older.clientId,
          newer.clientId,
        ]);
        svc.dispose();
      });
    });

    test('tanpa login atau koordinat tidak valid: ditolak, tidak dikirim', () {
      fakeAsync((async) {
        final svc = make();
        uid = null;
        SosOutcome? a;
        svc.send(jakarta).then((o) => a = o);
        uid = 'u1';
        SosOutcome? b;
        svc.send(const SosFix(lat: 200, lng: 0)).then((o) => b = o);
        async.flushMicrotasks();
        expect((a as SosRejected).kind, SafetyErrorKind.notSignedIn);
        expect((b as SosRejected).kind, SafetyErrorKind.invalidArgument);
        expect(repo.sosCalls, isEmpty);
        svc.dispose();
      });
    });

    test('dua pemicu terpisah mendapat clientId berbeda', () {
      fakeAsync((async) {
        final svc = make();
        svc.send(jakarta);
        svc.send(jakarta);
        async.flushMicrotasks();
        expect({for (final c in repo.sosCalls) c.clientId}, hasLength(2));
        svc.dispose();
      });
    });

    group('acquireFix', () {
      test('memakai posisi saat ini bila ada', () async {
        location.last = const SosFix(lat: 1, lng: 1);
        expect((await make().acquireFix())!.lat, jakarta.lat);
      });

      test('jatuh ke posisi terakhir bila posisi saat ini tak ada', () async {
        location.currentFix = null;
        location.last = const SosFix(lat: 1, lng: 2);
        final fix = await make().acquireFix();
        expect(fix!.lat, 1);
        expect(fix.lng, 2);
      });

      test('posisi saat ini tidak valid: pakai posisi terakhir', () async {
        location.currentFix = const SosFix(lat: double.nan, lng: 0);
        location.last = const SosFix(lat: 3, lng: 4);
        expect((await make().acquireFix())!.lat, 3);
      });

      test('keduanya tak ada: null, tidak ada koordinat karangan', () async {
        location.currentFix = null;
        location.last = null;
        expect(await make().acquireFix(), isNull);
      });

      test('posisi terakhir juga dibatasi waktu (tidak menggantung)', () {
        fakeAsync((async) {
          location.currentFix = null;
          location.lastGate = Completer<SosFix?>();
          var done = false;
          SosFix? fix;
          make().acquireFix().then((f) {
            fix = f;
            done = true;
          });
          async.elapse(const Duration(seconds: 11));
          expect(done, isTrue);
          expect(fix, isNull);
        });
      });

      test('melewati batas waktu: pakai posisi terakhir', () {
        fakeAsync((async) {
          location.currentGate = Completer<SosFix?>();
          location.last = const SosFix(lat: 5, lng: 6);
          SosFix? fix;
          make().acquireFix().then((f) => fix = f);
          async.elapse(const Duration(seconds: 11));
          expect(fix!.lat, 5);
        });
      });
    });
  });
}
