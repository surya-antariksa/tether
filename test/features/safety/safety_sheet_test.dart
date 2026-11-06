import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/selected_circle.dart';
import 'package:tether/features/activity/domain/notification_gateway.dart';
import 'package:tether/features/safety/data/safety_providers.dart';
import 'package:tether/features/safety/domain/safety_error.dart';
import 'package:tether/features/safety/domain/safety_repository.dart';
import 'package:tether/features/safety/domain/sos_models.dart';
import 'package:tether/features/safety/domain/sos_queue_store.dart';
import 'package:tether/features/safety/presentation/safety_strings.dart';

import 'safety_fakes.dart';
import 'safety_harness.dart';

/// Simpul semantik tombol SOS (judul bagian "SOS" tidak punya aksi tekan-lama).
final sosNode = find.semantics.byPredicate(
  (n) =>
      n.label == SafetyStrings.holdLabel &&
      n.getSemanticsData().hasAction(SemanticsAction.longPress),
);

/// Antrean yang add-nya tidak pernah selesai (berkas macet).
class HangingAddStore extends InMemorySosQueueStore {
  @override
  Future<void> add(PendingSos sos) => Completer<void>().future;
}

Future<void> tick(WidgetTester tester, [int seconds = 1]) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Menahan 3 detik penuh dan melepas; dialog hitung mundur terbuka.
Future<void> holdUntilCountdown(WidgetTester tester) async {
  final g = await holdSos(tester, const Duration(milliseconds: 3100));
  await tester.pump(); // dialog muncul
  await tester.pump(const Duration(milliseconds: 400));
  await g.up();
  await tester.pump();
}

void main() {
  group('lembar Keselamatan', () {
    testSafety('tombol masuk berukuran minimal 44 pt dan berlabel', (t) async {
      await pumpSafety(t);
      final size = t.getSize(find.bySemanticsLabel(SafetyStrings.entryLabel));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testSafety('menampilkan check-in, SOS, dan keterangan bukan pengganti '
        'layanan darurat dengan 112 sebagai teks', (t) async {
      await pumpSafety(t);
      await openSheet(t);
      expect(find.text(SafetyStrings.arrived), findsOneWidget);
      expect(find.text(SafetyStrings.safe), findsOneWidget);
      expect(find.text(SafetyStrings.holdIdle), findsOneWidget);
      final disclaimer = t.widget<Text>(
        find.byKey(const ValueKey('sos-disclaimer')),
      );
      expect(disclaimer.data, contains('SOS bukan pengganti layanan darurat'));
      expect(disclaimer.data, contains('112'));
      // 112 hanya teks: tidak ada tombol/tautan telepon.
      expect(find.textContaining('tel:'), findsNothing);
    });

    testSafety('area sentuh tombol check-in dan SOS minimal 44 pt', (t) async {
      await pumpSafety(t);
      await openSheet(t);
      for (final f in [
        find
            .ancestor(
              of: find.text(SafetyStrings.arrived),
              matching: find.byType(GestureDetector),
            )
            .first,
        find
            .ancestor(
              of: find.text(SafetyStrings.safe),
              matching: find.byType(GestureDetector),
            )
            .first,
        holdButton,
        find.widgetWithText(CupertinoButton, SafetyStrings.close),
      ]) {
        final s = t.getSize(f);
        expect(s.height, greaterThanOrEqualTo(44), reason: '$f');
        expect(s.width, greaterThanOrEqualTo(44), reason: '$f');
      }
    });

    testSafety('teks besar (2x) tidak overflow', (t) async {
      await pumpSafety(t, textScale: 2.0);
      await openSheet(t);
      expect(t.takeException(), isNull);
    });
  });

  group('check-in', () {
    testSafety('"Saya sudah sampai" memanggil RPC untuk Circle terpilih lalu '
        'menampilkan sukses', (t) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      expect(h.repo.checkinCalls, [('c1', CheckinKind.arrived)]);
      expect(
        find.text(SafetyStrings.checkinDone(CheckinKind.arrived)),
        findsOneWidget,
      );
    });

    testSafety('"Saya aman" memakai kind safe', (t) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.safe));
      await t.pump();
      await t.pump();
      expect(h.repo.checkinCalls.single.$2, CheckinKind.safe);
    });

    testSafety('memuat: tombol nonaktif selagi mengirim, tidak terkirim dua '
        'kali', (t) async {
      final repo = FakeSafetyRepository()..gate = Completer<void>();
      final h = await pumpSafety(t, repo: repo);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      expect(find.text(SafetyStrings.checkinSending), findsOneWidget);
      await t.tap(find.text(SafetyStrings.safe), warnIfMissed: false);
      await t.pump();
      expect(h.repo.checkinCalls, hasLength(1));
      repo.gate!.complete();
      await t.pump();
      await t.pump();
      expect(find.textContaining('Terkirim ke Circle'), findsOneWidget);
    });

    testSafety('status check-in tidak basi: lembar ditutup lalu dibuka lagi '
        'kembali ke awal', (t) async {
      await pumpSafety(t);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      expect(find.textContaining('Terkirim ke Circle'), findsOneWidget);
      await t.tap(find.text(SafetyStrings.close));
      await t.pumpAndSettle();
      await openSheet(t);
      expect(find.textContaining('Terkirim ke Circle'), findsNothing);
    });

    testSafety('status check-in direset saat Circle terpilih berubah', (
      t,
    ) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      expect(find.textContaining('Terkirim ke Circle'), findsOneWidget);
      h.container.read(selectedCircleIdProvider.notifier).select('c2');
      await t.pump();
      expect(find.textContaining('Terkirim ke Circle'), findsNothing);
      expect(h.container.read(checkinControllerProvider), isA<CheckinIdle>());
    });

    testSafety('TH006: pesan terlalu sering (30 detik)', (t) async {
      final repo = FakeSafetyRepository()
        ..checkinFailure = SafetyErrorKind.rateLimited;
      await pumpSafety(t, repo: repo);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.safe));
      await t.pump();
      await t.pump();
      expect(
        find.text(SafetyStrings.checkinError(SafetyErrorKind.rateLimited)),
        findsOneWidget,
      );
      expect(find.textContaining('30 detik'), findsOneWidget);
    });

    testSafety('42501: bukan anggota Circle', (t) async {
      final repo = FakeSafetyRepository()
        ..checkinFailure = SafetyErrorKind.notMember;
      await pumpSafety(t, repo: repo);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      expect(find.text('Kamu bukan anggota Circle ini.'), findsOneWidget);
    });

    testSafety('jaringan putus: pesan jelas, tombol bisa dicoba lagi', (
      t,
    ) async {
      final repo = FakeSafetyRepository()
        ..checkinFailure = SafetyErrorKind.network;
      final h = await pumpSafety(t, repo: repo);
      await openSheet(t);
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      expect(find.textContaining('Tidak ada koneksi'), findsOneWidget);
      repo.checkinFailure = null;
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      expect(h.repo.checkinCalls, hasLength(2));
      expect(find.textContaining('Terkirim ke Circle'), findsOneWidget);
    });

    testSafety('tanpa Circle terpilih: tombol nonaktif dan ada petunjuk', (
      t,
    ) async {
      final h = await pumpSafety(t, selectedCircle: null);
      await openSheet(t);
      expect(find.text(SafetyStrings.noCircleSelected), findsOneWidget);
      await t.tap(find.text(SafetyStrings.arrived), warnIfMissed: false);
      await t.pump();
      expect(h.repo.checkinCalls, isEmpty);
    });

    testSafety('Semantics: tombol berlabel dan status adalah live region', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      await pumpSafety(t);
      await openSheet(t);
      expect(
        t.getSemantics(find.bySemanticsLabel(SafetyStrings.arrived)),
        matchesSemantics(
          label: SafetyStrings.arrived,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      await t.tap(find.text(SafetyStrings.arrived));
      await t.pump();
      await t.pump();
      final status = t.getSemantics(
        find.byKey(const ValueKey('checkin-status')),
      );
      expect(status.flagsCollection.isLiveRegion, isTrue);
      sem.dispose();
    });
  });

  group('SOS: tombol tahan', () {
    testSafety('tahan kurang dari 3 detik membatalkan tanpa efek', (t) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      final g = await holdSos(t, const Duration(milliseconds: 1500));
      expect(progressFraction(t), greaterThan(0.3));
      expect(find.text(SafetyStrings.holdActive), findsOneWidget);
      await g.up();
      await t.pump();
      expect(progressFraction(t), 0);
      await tick(t, 5);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(h.sos.phase, SosPhase.idle);
      expect(h.repo.sosCalls, isEmpty);
      expect(h.haptics.holdCompletes, 0);
    });

    testSafety('progres terlihat naik dan haptic tiap detik', (t) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      final g = await holdSos(t, const Duration(milliseconds: 1100));
      final p1 = progressFraction(t);
      await t.pump(const Duration(milliseconds: 1000));
      final p2 = progressFraction(t);
      expect(p2, greaterThan(p1));
      expect(h.haptics.holdTicks, 2);
      await g.up();
      await t.pump();
    });

    testSafety('Reduce Motion: progres melompat per sepertiga', (t) async {
      await pumpSafety(t, reduceMotion: true);
      await openSheet(t);
      final g = await holdSos(t, const Duration(milliseconds: 1500));
      expect(progressFraction(t), closeTo(1 / 3, 1e-9));
      await t.pump(const Duration(milliseconds: 600));
      expect(progressFraction(t), closeTo(2 / 3, 1e-9));
      await g.up();
      await t.pump();
    });

    testSafety('selesai 3 detik: hitung mundur 5 detik, belum ada yang '
        'terkirim', (t) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      await holdUntilCountdown(t);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text(SafetyStrings.countdownTitle(5)), findsOneWidget);
      expect(h.haptics.holdCompletes, 1);
      expect(h.repo.sosCalls, isEmpty);
      await tick(t, 3);
      expect(find.text(SafetyStrings.countdownTitle(2)), findsOneWidget);
      expect(h.repo.sosCalls, isEmpty);
      expect(h.haptics.countdownTicks, 3);
    });
  });

  group('SOS: alur', () {
    testSafety('hitungan selesai: terkirim dengan koordinat, clientId, waktu', (
      t,
    ) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(h.repo.sosCalls, hasLength(1));
      final c = h.repo.sosCalls.single;
      expect(c.lat, jakarta.lat);
      expect(c.lng, jakarta.lng);
      expect(c.clientId, hasLength(36));
      expect(find.text(SafetyStrings.sentTitle), findsOneWidget);
      expect(find.text(SafetyStrings.sentBody(2)), findsOneWidget);
      await t.tap(find.text(SafetyStrings.done));
      await t.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(h.sos.phase, SosPhase.idle);
    });

    testSafety('Batalkan satu ketukan: tidak ada yang terkirim', (t) async {
      final h = await pumpSafety(t);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 2);
      await t.tap(find.text(SafetyStrings.cancel));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await tick(t, 10);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(h.repo.sosCalls, isEmpty);
      expect(h.location.currentCalls, 1);
      expect(h.sos.phase, SosPhase.idle);
    });

    testSafety('keadaan mengirim: indikator aktivitas; Reduce Motion tanpa '
        'indikator berputar', (t) async {
      for (final reduce in [false, true]) {
        final repo = FakeSafetyRepository()..gate = Completer<void>();
        await pumpSafety(t, repo: repo, reduceMotion: reduce);
        await openSheet(t);
        await holdUntilCountdown(t);
        await tick(t, 5);
        await t.pump();
        expect(find.text(SafetyStrings.sending), findsOneWidget);
        expect(
          find.byType(CupertinoActivityIndicator),
          reduce ? findsNothing : findsOneWidget,
        );
        repo.gate!.complete();
        await t.pump();
        await t.pump();
        expect(find.text(SafetyStrings.sentTitle), findsOneWidget);
        // Bersihkan untuk iterasi berikutnya.
        await t.tap(find.text(SafetyStrings.done));
        await t.pump();
        await t.pump(const Duration(seconds: 1));
        await t.pumpWidget(const SizedBox());
      }
    });

    testSafety('TH007: pesan batas 3 per 10 menit', (t) async {
      final repo = FakeSafetyRepository()
        ..sosScript.add(SafetyErrorKind.rateLimited);
      await pumpSafety(t, repo: repo);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(find.text(SafetyStrings.failedTitle), findsOneWidget);
      expect(find.textContaining('3 kali per 10 menit'), findsOneWidget);
      expect(find.text(SafetyStrings.emergencyHint), findsOneWidget);
    });

    testSafety('TH008: pesan tanpa Circle', (t) async {
      final repo = FakeSafetyRepository()
        ..sosScript.add(SafetyErrorKind.noCircle);
      await pumpSafety(t, repo: repo);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(find.textContaining('belum punya Circle'), findsOneWidget);
    });

    testSafety('lokasi tidak tersedia: galat jelas, tidak mengirim koordinat '
        'palsu', (t) async {
      final loc = FakeSosLocation();
      final h = await pumpSafety(t, location: loc);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(find.text(SafetyStrings.noLocation), findsOneWidget);
      expect(h.repo.sosCalls, isEmpty);
    });

    testSafety('memakai posisi terakhir bila posisi saat ini tak ada', (
      t,
    ) async {
      final loc = FakeSosLocation(last: const SosFix(lat: 1.5, lng: 2.5));
      final h = await pumpSafety(t, location: loc);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(h.repo.sosCalls.single.lat, 1.5);
      expect(h.repo.sosCalls.single.lng, 2.5);
    });

    testSafety('jaringan putus: pesan antre, lalu terkirim otomatis dan '
        'dialog berubah', (t) async {
      final repo = FakeSafetyRepository()
        ..sosScript.add(SafetyErrorKind.network);
      final h = await pumpSafety(t, repo: repo);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(find.text(SafetyStrings.queuedTitle), findsOneWidget);
      expect(find.text(SafetyStrings.queuedBody), findsOneWidget);
      expect(h.sos.phase, SosPhase.queued);

      await t.pump(const Duration(seconds: 2)); // backoff pertama
      await t.pump();
      expect(h.repo.sosCalls, hasLength(2));
      expect(h.repo.sosCalls[1].clientId, h.repo.sosCalls[0].clientId);
      expect(h.repo.sosCalls[1].triggeredAt, h.repo.sosCalls[0].triggeredAt);
      expect(find.text(SafetyStrings.sentTitle), findsOneWidget);
      expect(h.repo.eventsCreated, 2);
    });

    testSafety('trigger_sos menggantung: dialog tidak macet, antre setelah 15 '
        'detik dan bisa ditutup', (t) async {
      final repo = FakeSafetyRepository()..gate = Completer<void>();
      final h = await pumpSafety(t, repo: repo);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      expect(find.text(SafetyStrings.sending), findsOneWidget);
      await tick(t, 16);
      await t.pump();
      expect(find.text(SafetyStrings.queuedTitle), findsOneWidget);
      await t.tap(find.text(SafetyStrings.done));
      await t.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(h.sos.phase, SosPhase.idle);
      // Jaringan pulih: coba ulang otomatis berhasil.
      repo.gate!.complete();
      await t.pump(const Duration(seconds: 3));
      await t.pump();
      expect(h.repo.eventsCreated, 2);
    });

    testSafety('pengaman dialog: penyimpanan menggantung, 45 detik berakhir '
        'gagal jujur dan bisa ditutup', (t) async {
      final h = await pumpSafety(t, store: HangingAddStore());
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      expect(find.text(SafetyStrings.sending), findsOneWidget);
      await tick(t, 44);
      expect(find.text(SafetyStrings.sending), findsOneWidget);
      await tick(t, 2);
      expect(find.text(SafetyStrings.failedTitle), findsOneWidget);
      expect(find.text(SafetyStrings.emergencyHint), findsOneWidget);
      await t.tap(find.text(SafetyStrings.done));
      await t.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(h.sos.phase, SosPhase.idle);
    });

    testSafety('SOS antre ditolak permanen setelah dialog ditutup: pengguna '
        'diberi tahu lewat notifikasi lokal', (t) async {
      final repo = FakeSafetyRepository()
        ..sosScript.addAll([
          SafetyErrorKind.network,
          SafetyErrorKind.rateLimited,
        ]);
      final h = await pumpSafety(t, repo: repo);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      expect(find.text(SafetyStrings.queuedTitle), findsOneWidget);
      await t.tap(find.text(SafetyStrings.done));
      await t.pumpAndSettle();
      expect(h.gateway.shown, isEmpty);

      await t.pump(const Duration(seconds: 2)); // coba ulang: TH007
      await t.pump();
      expect(h.repo.sosCalls, hasLength(2));
      final n = h.gateway.shown.single;
      expect(n.title, SafetyStrings.sosRejectedNotificationTitle);
      expect(n.body, contains('3 kali per 10 menit'));
      expect(n.body, contains('112'));
      expect(n.urgency, NotificationUrgency.high);
    });

    testSafety('dialog ditutup lalu SOS antre terkirim: tidak ada notifikasi '
        'galat', (t) async {
      final repo = FakeSafetyRepository()
        ..sosScript.add(SafetyErrorKind.network);
      final h = await pumpSafety(t, repo: repo);
      await openSheet(t);
      await holdUntilCountdown(t);
      await tick(t, 5);
      await t.pump();
      await t.pump();
      await t.tap(find.text(SafetyStrings.done));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pump();
      expect(h.repo.sosCalls, hasLength(2));
      expect(h.gateway.shown, isEmpty);
    });

    testSafety('dipicu dua kali berturut-turut tidak membuka dua dialog', (
      t,
    ) async {
      await pumpSafety(t);
      await openSheet(t);
      await holdUntilCountdown(t);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    });
  });

  group('SOS: aksesibilitas', () {
    testSafety('tombol SOS punya label, petunjuk, dan aksi semantik tanpa '
        'menahan', (t) async {
      final sem = t.ensureSemantics();
      final h = await pumpSafety(t);
      await openSheet(t);
      final node = t.getSemantics(holdButton);
      final data = node.getSemanticsData();
      expect(data.label, SafetyStrings.holdLabel);
      expect(data.hint, SafetyStrings.holdHint);
      expect(node.flagsCollection.isButton, isTrue);
      final ids = data.customSemanticsActionIds!;
      expect(ids, hasLength(1));
      expect(
        CustomSemanticsAction.getAction(ids.single)!.label,
        SafetyStrings.startActionLabel,
      );
      // Menjalankan aksi alternatif: hitung mundur 5 detik tetap berlaku.
      t.semantics.performAction(
        sosNode,
        SemanticsAction.customAction,
        args: ids.single,
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(SafetyStrings.countdownTitle(5)), findsOneWidget);
      expect(h.repo.sosCalls, isEmpty);
      sem.dispose();
    });

    testSafety('tekan-lama pembaca layar juga memulai hitung mundur', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final h = await pumpSafety(t);
      await openSheet(t);
      t.semantics.longPress(sosNode);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(SafetyStrings.countdownTitle(5)), findsOneWidget);
      expect(h.repo.sosCalls, isEmpty);
      sem.dispose();
    });

    testSafety(
      'pembaca layar aktif: ada tombol Mulai SOS biasa; mati: tidak ada',
      (t) async {
        await pumpSafety(t);
        await openSheet(t);
        expect(find.text(SafetyStrings.startWithoutHold), findsNothing);
        await t.pumpWidget(const SizedBox());

        final h = await pumpSafety(t, screenReader: true);
        await openSheet(t);
        await t.tap(find.text(SafetyStrings.startWithoutHold));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(find.text(SafetyStrings.countdownTitle(5)), findsOneWidget);
        expect(h.repo.sosCalls, isEmpty);
      },
    );

    testSafety('hitung mundur: judul live region, tombol Batalkan >= 44 pt', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      await pumpSafety(t);
      await openSheet(t);
      await holdUntilCountdown(t);
      final announce = find.bySemanticsLabel(
        SafetyStrings.countdownAnnouncement(5),
      );
      expect(announce, findsOneWidget);
      expect(t.getSemantics(announce).flagsCollection.isLiveRegion, isTrue);
      final size = t.getSize(
        find.widgetWithText(CupertinoDialogAction, SafetyStrings.cancel),
      );
      expect(size.height, greaterThanOrEqualTo(44));
      sem.dispose();
    });
  });
}
