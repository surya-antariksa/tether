// Tes integrasi gelombang 3 (tempat, keselamatan, aktivitas, riwayat, hapus
// akun) terhadap Supabase LOKAL yang sedang berjalan, memakai kelas produksi
// (SupabasePlaceRepository, SupabaseSafetyRepository, SosService,
// SupabaseActivityRepository, SupabaseHistoryRepository,
// SupabaseAccountRepository). Dilewati bila SUPABASE_URL atau
// SUPABASE_ANON_KEY kosong. Kunci tidak pernah disimpan:
//   set -a; eval "$(npx supabase status -o env)"; set +a
//   SUPABASE_URL=$API_URL SUPABASE_ANON_KEY=$ANON_KEY \
//     flutter test test/integration/wave3_e2e_test.dart
//
// Satu run mendaftarkan 5 pengguna baru (email unik, domain example.test):
// A dan B (anggota), C (orang luar, tidak pernah masuk Circle apa pun), D
// (akan dihapus), E (uji batas laju SOS). Tiap tes membuat Circle sendiri dan
// keluar darinya saat selesai; titik lokasi dibersihkan di awal dan akhir tes
// riwayat. Pengguna tidak bisa dihapus tuntas lewat klien, jadi dibiarkan.
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/activity/data/supabase_activity_repository.dart';
import 'package:tether/features/activity/domain/activity_event.dart' as act;
import 'package:tether/features/activity/domain/activity_repository.dart';
import 'package:tether/features/auth/data/supabase_auth_repository.dart';
import 'package:tether/features/circle/data/supabase_circle_repository.dart';
import 'package:tether/features/history/data/supabase_history_repository.dart';
import 'package:tether/features/history/domain/history_repository.dart';
import 'package:tether/features/places/data/supabase_place_repository.dart';
import 'package:tether/features/places/domain/place_error.dart';
import 'package:tether/features/profile/data/supabase_account_repository.dart';
import 'package:tether/features/profile/data/supabase_profile_repository.dart';
import 'package:tether/features/safety/data/sos_service.dart';
import 'package:tether/features/safety/data/supabase_safety_repository.dart';
import 'package:tether/features/safety/domain/safety_error.dart';
import 'package:tether/features/safety/domain/safety_repository.dart';
import 'package:tether/features/safety/domain/sos_location.dart';
import 'package:tether/features/safety/domain/sos_models.dart';
import 'package:tether/features/safety/domain/sos_queue_store.dart';

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

const _password = 'sandi-uji-e2e-3';

/// Pengguna uji: klien sendiri + repository yang dibutuhkan.
class _User {
  _User(this.client, this.id, this.name)
    : circles = SupabaseCircleRepository(client),
      places = SupabasePlaceRepository(client),
      safety = SupabaseSafetyRepository(client),
      activity = SupabaseActivityRepository(client),
      history = SupabaseHistoryRepository(client);

  final SupabaseClient client;
  final String id;
  final String name;
  final SupabaseCircleRepository circles;
  final SupabasePlaceRepository places;
  final SupabaseSafetyRepository safety;
  final SupabaseActivityRepository activity;
  final SupabaseHistoryRepository history;
}

final _clients = <SupabaseClient>[];
final _run = DateTime.now().millisecondsSinceEpoch;

Future<_User> _signUp(String tag, String displayName) async {
  final client = SupabaseClient(
    _url,
    _anonKey,
    // Tanpa Supabase.initialize tidak ada asyncStorage: pakai implicit.
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  _clients.add(client);
  final auth = SupabaseAuthRepository(client);
  await auth.signUp(
    email: '$tag-$_run@example.test',
    password: _password,
    displayName: displayName,
  );
  return _User(client, auth.currentUserId!, displayName);
}

/// Circle baru milik [owner] dengan [joiners] sebagai anggota. Semua keluar
/// saat tes selesai (anggota terakhir keluar menghapus Circle).
Future<String> _newCircle(String name, _User owner, List<_User> joiners) async {
  final id = await owner.circles.createCircle(name);
  addTearDown(() async {
    for (final u in [...joiners, owner]) {
      try {
        await u.circles.leaveCircle(id);
      } catch (_) {}
    }
  });
  if (joiners.isNotEmpty) {
    final invite = await owner.circles.createInvite(id);
    for (final j in joiners) {
      expect(await j.circles.joinCircle(invite.code), id);
    }
  }
  return id;
}

Future<T> _catch<T extends Exception>(Future<void> Function() f) async {
  try {
    await f();
  } on T catch (e) {
    return e;
  }
  fail('seharusnya melempar $T');
}

Future<PlaceErrorKind> _placeErr(Future<void> Function() f) async =>
    (await _catch<PlaceError>(f)).kind;

Future<SafetyErrorKind> _safetyErr(Future<void> Function() f) async =>
    (await _catch<SafetyError>(f)).kind;

/// SafetyRepository sungguhan yang gagal "jaringan" selama [offline] true.
class _FlakySafety implements SafetyRepository {
  _FlakySafety(this.inner);

  final SafetyRepository inner;
  bool offline = true;
  int attempts = 0;

  @override
  Future<void> checkin(String circleId, CheckinKind kind) =>
      inner.checkin(circleId, kind);

  @override
  Future<int> triggerSos({
    required double lat,
    required double lng,
    double? accuracyM,
    required String clientId,
    required DateTime triggeredAt,
  }) {
    attempts++;
    if (offline) throw const SafetyError(SafetyErrorKind.network);
    return inner.triggerSos(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      clientId: clientId,
      triggeredAt: triggeredAt,
    );
  }
}

class _NoLocation implements SosLocationProvider {
  @override
  Future<SosFix?> current() async => null;

  @override
  Future<SosFix?> lastKnown() async => null;
}

Map<String, dynamic> _pt(
  double lat,
  double lng,
  DateTime at, {
  double? acc,
  bool moving = false,
}) => {
  'lat': lat,
  'lng': lng,
  'accuracy_m': acc,
  'speed_mps': null,
  'battery_pct': null,
  'is_moving': moving,
  'recorded_at': at.toUtc().toIso8601String(),
};

Future<int> _upload(_User u, List<Map<String, dynamic>> pts) async {
  final n = await u.client.rpc('upload_points', params: {'p_points': pts});
  return (n as num).toInt();
}

void main() {
  late _User a, b, c;

  group('gelombang 3 ke Supabase lokal', () {
    setUpAll(() async {
      a = await _signUp('ayu', 'Ayu Pertiwi');
      b = await _signUp('budi', 'Budi Santoso');
      c = await _signUp('citra', 'Citra Luar');
    });

    tearDownAll(() async {
      for (final cl in _clients) {
        await cl.dispose();
      }
    });

    // ------------------------------------------------------------ places
    test(
      'places: CRUD, batas 5 (TH005), radius, visibilitas, center',
      () async {
        final circleId = await _newCircle('Tempat E2E', a, [b]);
        const home = LatLng(-6.2, 106.816666);

        expect(await a.places.places(circleId), isEmpty);
        expect(await a.places.isAdmin(circleId), isTrue);
        expect(await b.places.isAdmin(circleId), isFalse);

        // Radius di luar 100..5000 ditolak (22023 -> invalid); nama tidak sah.
        for (final r in [99, 5001, 0, -5]) {
          expect(
            await _placeErr(
              () => a.places.createPlace(
                circleId: circleId,
                name: 'X',
                center: home,
                radiusM: r,
              ),
            ),
            PlaceErrorKind.invalid,
            reason: 'radius $r',
          );
        }
        for (final n in ['   ', 'n' * 41]) {
          expect(
            await _placeErr(
              () => a.places.createPlace(
                circleId: circleId,
                name: n,
                center: home,
                radiusM: 200,
              ),
            ),
            PlaceErrorKind.invalid,
            reason: 'nama "${n.length} karakter"',
          );
        }
        expect(await a.places.places(circleId), isEmpty); // tak ada yang masuk

        // Batas radius yang sah (100 dan 5000), nama dipangkas, center benar.
        final id1 = await a.places.createPlace(
          circleId: circleId,
          name: '  Rumah  ',
          center: home,
          radiusM: 100,
        );
        final id2 = await a.places.createPlace(
          circleId: circleId,
          name: 'n' * 40,
          center: const LatLng(-7.797068, 110.370529),
          radiusM: 5000,
        );
        var list = await a.places.places(circleId);
        expect(list.map((p) => p.id), [id1, id2]); // urut dibuat
        final rumah = list.first;
        expect(rumah.name, 'Rumah'); // dipangkas server
        expect(rumah.radiusM, 100);
        expect(rumah.circleId, circleId);
        expect(rumah.createdBy, a.id);
        expect(rumah.center.latitude, closeTo(home.latitude, 1e-6));
        expect(rumah.center.longitude, closeTo(home.longitude, 1e-6));
        expect(list[1].radiusM, 5000);
        expect(list[1].center.latitude, closeTo(-7.797068, 1e-6));
        expect(list[1].center.longitude, closeTo(110.370529, 1e-6));

        // Lengkapi sampai 5, yang ke-6 ditolak TH005 (untuk A maupun B).
        for (var i = 3; i <= 5; i++) {
          await a.places.createPlace(
            circleId: circleId,
            name: 'Tempat $i',
            center: LatLng(-6.2 + i / 100, 106.8),
            radiusM: 200,
          );
        }
        expect((await a.places.places(circleId)), hasLength(5));
        expect(
          await _placeErr(
            () => a.places.createPlace(
              circleId: circleId,
              name: 'Ke-6',
              center: home,
              radiusM: 200,
            ),
          ),
          PlaceErrorKind.limitReached,
        );
        expect(
          await _placeErr(
            () => b.places.createPlace(
              circleId: circleId,
              name: 'Ke-6 B',
              center: home,
              radiusM: 200,
            ),
          ),
          PlaceErrorKind.limitReached,
        );

        // B (anggota) melihat tempat A dengan center yang sama; C tidak.
        final seenB = await b.places.places(circleId);
        expect(
          seenB.map((p) => p.id),
          (await a.places.places(circleId)).map((p) => p.id),
        );
        expect(seenB.first.center.latitude, closeTo(home.latitude, 1e-6));
        expect(seenB.first.center.longitude, closeTo(home.longitude, 1e-6));
        expect(await c.places.places(circleId), isEmpty);
        expect(
          await _placeErr(
            () => c.places.createPlace(
              circleId: circleId,
              name: 'Nyelonong',
              center: home,
              radiusM: 200,
            ),
          ),
          PlaceErrorKind.notMember,
        );
        expect(
          await _placeErr(
            () =>
                c.places.updatePlace(placeId: id1, name: 'Retas', radiusM: 300),
          ),
          PlaceErrorKind.notFound,
        );
        expect(
          await _placeErr(() => c.places.deletePlace(id1)),
          PlaceErrorKind.notFound,
        );

        // B bukan pembuat dan bukan admin: ubah/hapus ditolak (42501).
        expect(
          await _placeErr(
            () => b.places.updatePlace(placeId: id1, name: 'B', radiusM: 300),
          ),
          PlaceErrorKind.notAllowed,
        );
        expect(
          await _placeErr(() => b.places.deletePlace(id1)),
          PlaceErrorKind.notAllowed,
        );

        // A: ubah nama/radius (posisi tetap), radius di luar batas ditolak.
        await a.places.updatePlace(
          placeId: id1,
          name: ' Kantor ',
          radiusM: 750,
        );
        expect(
          await _placeErr(
            () =>
                a.places.updatePlace(placeId: id1, name: 'Kantor', radiusM: 99),
          ),
          PlaceErrorKind.invalid,
        );
        final after = (await b.places.places(
          circleId,
        )).firstWhere((p) => p.id == id1);
        expect(after.name, 'Kantor');
        expect(after.radiusM, 750);
        expect(after.center.latitude, closeTo(home.latitude, 1e-6));

        // id tak dikenal -> notFound.
        expect(
          await _placeErr(
            () => a.places.deletePlace('00000000-0000-4000-8000-000000000000'),
          ),
          PlaceErrorKind.notFound,
        );

        // Hapus satu: turun ke 4, lalu B boleh membuat dan A (admin) boleh
        // mengubah/menghapus tempat milik B.
        await a.places.deletePlace(id2);
        list = await a.places.places(circleId);
        expect(list, hasLength(4));
        expect(list.any((p) => p.id == id2), isFalse);
        final idB = await b.places.createPlace(
          circleId: circleId,
          name: 'Sekolah',
          center: home,
          radiusM: 300,
        );
        expect(
          (await a.places.places(
            circleId,
          )).firstWhere((p) => p.id == idB).createdBy,
          b.id,
        );
        await a.places.updatePlace(
          placeId: idB,
          name: 'Sekolah 2',
          radiusM: 400,
        );
        await b.places.deletePlace(idB); // pembuat boleh menghapus sendiri
        expect((await a.places.places(circleId)), hasLength(4));
      },
    );

    // ------------------------------------------------------------ safety
    test('safety: check-in, batas TH006, orang luar ditolak', () async {
      final circleId = await _newCircle('Checkin E2E', a, [b]);

      await a.safety.checkin(circleId, CheckinKind.arrived);
      expect(
        await _safetyErr(() => a.safety.checkin(circleId, CheckinKind.arrived)),
        SafetyErrorKind.rateLimited,
      );
      // Jendela 30 detik berlaku per pengguna per Circle, apa pun jenisnya.
      expect(
        await _safetyErr(() => a.safety.checkin(circleId, CheckinKind.safe)),
        SafetyErrorKind.rateLimited,
      );
      // B tidak terkena batas A.
      await b.safety.checkin(circleId, CheckinKind.safe);

      expect(
        await _safetyErr(() => c.safety.checkin(circleId, CheckinKind.safe)),
        SafetyErrorKind.notMember,
      );

      // A melihat dua check-in (payload tanpa koordinat).
      final events = (await b.activity.fetchEvents(
        circleId,
      )).where((e) => e.type == act.ActivityType.checkin).toList();
      expect(events.map((e) => e.userId).toSet(), {a.id, b.id});
      expect(events.every((e) => !e.hasCoordinates), isTrue);
      final ea = events.firstWhere((e) => e.userId == a.id);
      expect(ea.checkinKind, act.CheckinKind.arrived);
      expect(ea.displayName, 'Ayu Pertiwi');
    });

    test(
      'safety: SOS idempoten per client_id, B menerima event berkoordinat',
      () async {
        final circleId = await _newCircle('SOS E2E', a, [b]);
        final nCircles = (await a.circles.myCircles()).length;
        final clientId = generateUuidV4();
        final at = DateTime.now().toUtc().subtract(const Duration(minutes: 2));

        final first = await a.safety.triggerSos(
          lat: -6.175392,
          lng: 106.827153,
          accuracyM: 12.5,
          clientId: clientId,
          triggeredAt: at,
        );
        expect(first, nCircles); // satu event per Circle milik A
        expect(first, greaterThanOrEqualTo(1));

        // Ulang dengan client_id sama: tidak ada event baru.
        final second = await a.safety.triggerSos(
          lat: -6.175392,
          lng: 106.827153,
          accuracyM: 12.5,
          clientId: clientId,
          triggeredAt: at,
        );
        expect(second, first);

        final seenB = (await b.activity.fetchEvents(
          circleId,
        )).where((e) => e.type == act.ActivityType.sos).toList();
        expect(seenB, hasLength(1), reason: 'tidak boleh ada event SOS ganda');
        final sos = seenB.single;
        expect(sos.userId, a.id);
        expect(sos.displayName, 'Ayu Pertiwi');
        expect(sos.hasCoordinates, isTrue);
        expect(sos.lat, closeTo(-6.175392, 1e-9));
        expect(sos.lng, closeTo(106.827153, 1e-9));
        // triggered_at asli dipertahankan (sekitar 2 menit sebelum dibuat).
        expect(sos.triggeredAt, isNotNull);
        final lag = sos.createdAt.difference(sos.triggeredAt!);
        expect(lag, greaterThan(const Duration(minutes: 1, seconds: 55)));
        expect(lag, lessThan(const Duration(minutes: 2, seconds: 30)));

        // Orang luar tidak melihat SOS ini (RLS).
        expect(await c.activity.fetchEvents(circleId), isEmpty);

        // Koordinat tidak sah ditolak; orang tanpa Circle -> TH008.
        expect(
          await _safetyErr(
            () => a.safety.triggerSos(
              lat: 91,
              lng: 0,
              clientId: generateUuidV4(),
              triggeredAt: DateTime.now(),
            ),
          ),
          SafetyErrorKind.invalidArgument,
        );
        expect(
          await _safetyErr(
            () => c.safety.triggerSos(
              lat: -6.2,
              lng: 106.8,
              clientId: generateUuidV4(),
              triggeredAt: DateTime.now(),
            ),
          ),
          SafetyErrorKind.noCircle,
        );
      },
    );

    test(
      'safety: antrean SOS (SosService) offline lalu terkirim sekali',
      () async {
        final circleId = await _newCircle('SOS antre E2E', a, [b]);
        final nCircles = (await b.circles.myCircles()).length;
        final flaky = _FlakySafety(b.safety);
        final store = InMemorySosQueueStore();
        // Jam diputar mundur 3 menit: SOS "dipicu saat offline".
        final base = DateTime.now().toUtc().subtract(
          const Duration(minutes: 3),
        );
        final service = SosService(
          repository: flaky,
          store: store,
          location: _NoLocation(),
          currentUserId: () => b.id,
          now: () => base,
          backoff: (_) =>
              const Duration(hours: 1), // tak ada coba ulang otomatis
        );
        addTearDown(service.dispose);

        // Tanpa GPS sama sekali: tidak ada koordinat palsu.
        expect(await service.acquireFix(), isNull);

        final deliveries = <SosDelivery>[];
        service.deliveries.listen(deliveries.add);

        final outcome = await service.send(
          const SosFix(lat: -6.9, lng: 107.6, accuracyM: 20),
        );
        expect(outcome, isA<SosQueued>());
        final clientId = (outcome as SosQueued).clientId;
        expect(await store.load(), hasLength(1));
        // Belum ada event di server.
        expect(
          (await a.activity.fetchEvents(
            circleId,
          )).where((e) => e.type == act.ActivityType.sos),
          isEmpty,
        );

        // Jaringan pulih: flush mengirim sekali, antrean kosong.
        flaky.offline = false;
        await service.flush();
        expect(await store.load(), isEmpty);
        await Future<void>.delayed(Duration.zero);
        expect(deliveries, hasLength(1));
        expect(deliveries.single.clientId, clientId);
        final sent = deliveries.single.outcome;
        expect(sent, isA<SosSent>());
        expect((sent as SosSent).circles, nCircles);

        // Flush lagi tidak mengirim apa pun (antrean kosong).
        final attempts = flaky.attempts;
        await service.flush();
        expect(flaky.attempts, attempts);

        final seenA = (await a.activity.fetchEvents(
          circleId,
        )).where((e) => e.type == act.ActivityType.sos).toList();
        expect(seenA, hasLength(1));
        expect(seenA.single.userId, b.id);
        expect(seenA.single.lat, closeTo(-6.9, 1e-9));
        expect(seenA.single.lng, closeTo(107.6, 1e-9));
        // triggered_at memakai jam saat dipicu (3 menit lalu), bukan saat kirim.
        final lag = seenA.single.createdAt.difference(
          seenA.single.triggeredAt!,
        );
        expect(lag, greaterThan(const Duration(minutes: 2, seconds: 50)));

        // Pengiriman ulang manual dengan client_id yang sama: tetap satu event.
        await b.safety.triggerSos(
          lat: -6.9,
          lng: 107.6,
          clientId: clientId,
          triggeredAt: base,
        );
        expect(
          (await a.activity.fetchEvents(
            circleId,
          )).where((e) => e.type == act.ActivityType.sos),
          hasLength(1),
        );
      },
    );

    test('safety: batas laju SOS TH007 (3 per 10 menit)', () async {
      final e = await _signUp('eka', 'Eka Uji');
      await _newCircle('SOS laju E2E', e, []);
      for (var i = 0; i < 3; i++) {
        await e.safety.triggerSos(
          lat: -6.2,
          lng: 106.8,
          clientId: generateUuidV4(),
          triggeredAt: DateTime.now(),
        );
        // created_at dibedakan clock_timestamp; beri jeda kecil antar pemicu.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        await _safetyErr(
          () => e.safety.triggerSos(
            lat: -6.2,
            lng: 106.8,
            clientId: generateUuidV4(),
            triggeredAt: DateTime.now(),
          ),
        ),
        SafetyErrorKind.rateLimited,
      );
    });

    // ---------------------------------------------------------- activity
    test(
      'activity: urutan terbaru dulu, nama, payload, paginasi, Realtime',
      () async {
        final circleId = await _newCircle('Aktivitas E2E', a, [b]);

        // B berlangganan Realtime (kanal harus tersambung dulu).
        final connected = Completer<void>();
        final inserted = Completer<act.ActivityEvent>();
        final sub = b.activity.realtimeEvents(circleId: circleId).listen((ev) {
          if (ev is ActivityConnectionChanged &&
              ev.connected &&
              !connected.isCompleted) {
            connected.complete();
          }
          if (ev is EventInserted &&
              ev.event.type == act.ActivityType.checkin &&
              !inserted.isCompleted) {
            inserted.complete(ev.event);
          }
        });
        addTearDown(sub.cancel);
        await connected.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => fail('kanal Realtime tidak pernah subscribed'),
        );
        await Future<void>.delayed(const Duration(seconds: 2));

        await a.safety.checkin(circleId, CheckinKind.arrived);
        final live = await inserted.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => fail('INSERT checkin tidak diterima B dalam 15 dtk'),
        );
        expect(live.userId, a.id);
        expect(live.circleId, circleId);
        expect(live.checkinKind, act.CheckinKind.arrived);
        expect(live.displayName, 'Ayu Pertiwi');

        await b.safety.triggerSos(
          lat: -6.5,
          lng: 107.0,
          clientId: generateUuidV4(),
          triggeredAt: DateTime.now(),
        );

        final events = await a.activity.fetchEvents(circleId);
        expect(events.length, greaterThanOrEqualTo(3));
        for (var i = 1; i < events.length; i++) {
          expect(
            events[i - 1].createdAt.isBefore(events[i].createdAt),
            isFalse,
            reason: 'harus terbaru dulu',
          );
        }
        expect(events[0].type, act.ActivityType.sos);
        expect(events[0].userId, b.id);
        expect(events[0].displayName, 'Budi Santoso');
        expect(events[0].lat, closeTo(-6.5, 1e-9));
        expect(events[1].type, act.ActivityType.checkin);
        expect(events[1].id, live.id);
        expect(
          events.any(
            (e) => e.type == act.ActivityType.memberJoined && e.userId == b.id,
          ),
          isTrue,
        );
        expect(events.every((e) => e.circleId == circleId), isTrue);

        // Paginasi: limit dan before.
        final page1 = await a.activity.fetchEvents(circleId, limit: 2);
        expect(page1.map((e) => e.id), events.take(2).map((e) => e.id));
        final page2 = await a.activity.fetchEvents(
          circleId,
          before: page1.last.createdAt,
        );
        expect(page2.map((e) => e.id), isNot(contains(page1.last.id)));
        expect(page2.map((e) => e.id), events.skip(2).map((e) => e.id));

        expect(await a.activity.fetchMemberNames(circleId), {
          a.id: 'Ayu Pertiwi',
          b.id: 'Budi Santoso',
        });
        expect(await a.activity.fetchCircleName(circleId), 'Aktivitas E2E');
        expect(await c.activity.fetchCircleName(circleId), isNull);
        expect(await c.activity.fetchMemberNames(circleId), isEmpty);

        // Event orang lain sejak waktu tertentu (tanpa event sendiri).
        final ids = await a.activity.fetchEventIdsSince(
          DateTime.now().subtract(const Duration(minutes: 5)),
          excludeUserId: a.id,
        );
        expect(ids, contains(events[0].id)); // SOS B
        expect(ids, isNot(contains(live.id))); // check-in A sendiri
      },
    );

    // ----------------------------------------------------------- history
    test(
      'history: 48 jam milik sendiri, hapus riwayat hanya milik sendiri',
      () async {
        Future<void> clean() async {
          await a.history.deleteAll();
          await b.history.deleteAll();
        }

        await clean();
        addTearDown(clean);
        await _newCircle('Riwayat E2E', a, [b]);

        final now = DateTime.now().toUtc();
        // A: 3 titik sah + 1 titik 49 jam (di luar retensi, dibuang RPC).
        final inserted = await _upload(a, [
          _pt(
            -6.20,
            106.80,
            now.subtract(const Duration(hours: 1)),
            acc: 8.5,
            moving: true,
          ),
          _pt(-6.21, 106.81, now.subtract(const Duration(hours: 5))),
          _pt(-6.22, 106.82, now.subtract(const Duration(hours: 47))),
          _pt(-6.30, 106.90, now.subtract(const Duration(hours: 49))),
        ]);
        expect(inserted, 3);
        expect(
          await _upload(b, [
            _pt(-7.00, 110.00, now.subtract(const Duration(hours: 2))),
            _pt(-7.01, 110.01, now.subtract(const Duration(hours: 3))),
          ]),
          2,
        );

        // RLS membolehkan A membaca titik B (satu Circle): tanpa filter user_id
        // titik B ikut terbaca, itu sebabnya repository wajib menyaring.
        final raw = await a.client
            .from('location_points')
            .select('user_id')
            .eq('user_id', b.id);
        expect(raw, hasLength(2), reason: 'prasyarat: RLS Circle mengizinkan');

        final mine = await a.history.fetchLast48h();
        expect(mine, hasLength(3));
        expect(mine.map((p) => p.point.latitude), [
          closeTo(-6.20, 1e-6),
          closeTo(-6.21, 1e-6),
          closeTo(-6.22, 1e-6),
        ], reason: 'terbaru dulu, hanya titik A');
        expect(mine.first.point.longitude, closeTo(106.80, 1e-6));
        expect(mine.first.accuracyM, closeTo(8.5, 1e-3));
        expect(mine.first.isMoving, isTrue);
        expect(mine[1].isMoving, isFalse);
        for (var i = 1; i < mine.length; i++) {
          expect(mine[i - 1].recordedAt.isAfter(mine[i].recordedAt), isTrue);
        }
        final windowStart = DateTime.now().subtract(HistoryRepository.window);
        expect(mine.every((p) => p.recordedAt.isAfter(windowStart)), isTrue);

        final theirs = await b.history.fetchLast48h();
        expect(theirs, hasLength(2));
        expect(theirs.every((p) => p.point.latitude < -6.9), isTrue);

        // A menghapus riwayatnya: 3 baris, milik B utuh.
        expect(await a.history.deleteAll(), 3);
        expect(await a.history.fetchLast48h(), isEmpty);
        expect(await b.history.fetchLast48h(), hasLength(2));
        expect(await a.history.deleteAll(), 0); // idempoten
        expect(await b.history.deleteAll(), 2);
        expect(await b.history.fetchLast48h(), isEmpty);
      },
    );

    // ------------------------------------------------------ delete_account
    test(
      'hapus akun: data lokasi/event hilang, Circle bersih, perilaku sesi',
      () async {
        final d = await _signUp('dewi', 'Dewi Hapus');
        final accountD = SupabaseAccountRepository(d.client);
        final authD = SupabaseAuthRepository(d.client);
        final circleId = await _newCircle('Hapus akun E2E', d, [b]);

        // D punya titik lokasi dan check-in.
        expect(
          await _upload(d, [
            _pt(
              -6.4,
              106.7,
              DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
            ),
          ]),
          1,
        );
        await d.safety.checkin(circleId, CheckinKind.arrived);
        final seenBefore = await b.client
            .from('location_points')
            .select('user_id')
            .eq('user_id', d.id);
        expect(
          seenBefore,
          hasLength(1),
          reason: 'prasyarat: B melihat titik D',
        );
        expect(
          (await b.activity.fetchEvents(
            circleId,
          )).where((e) => e.userId == d.id),
          isNotEmpty,
        );

        await accountD.deleteAccount();

        // Sisi Circle: D keluar, titik dan event D (selain member_left) hilang.
        expect((await b.circles.members(circleId)).map((m) => m.userId), [
          b.id,
        ]);
        expect(
          await b.client
              .from('location_points')
              .select('user_id')
              .eq('user_id', d.id),
          isEmpty,
        );
        final after = (await b.activity.fetchEvents(
          circleId,
        )).where((e) => e.userId == d.id).toList();
        expect(
          after.every((e) => e.type == act.ActivityType.memberLeft),
          isTrue,
          reason:
              'hanya member_left yang boleh tersisa: '
              '${after.map((e) => e.type.wire).toList()}',
        );

        // Perilaku sesi (dicatat apa adanya).
        final log = StringBuffer('[hapus akun] ');
        log.write(
          'currentUserId setelah delete: ${authD.currentUserId != null ? "masih ada" : "null"}; ',
        );
        try {
          final p = await SupabaseProfileRepository(d.client).fetchOwn();
          log.write(
            'JWT lama masih bisa baca profil (nama=${p.displayName}); ',
          );
        } catch (e) {
          log.write('baca profil dengan JWT lama gagal (${e.runtimeType}); ');
        }
        try {
          await d.client.rpc('delete_account');
          log.write('delete_account kedua berhasil (idempoten); ');
        } catch (e) {
          log.write(
            'delete_account kedua gagal (${e is PostgrestException ? e.code : e.runtimeType}); ',
          );
        }
        try {
          await authD.signOut();
          log.write('signOut: TIDAK gagal; ');
        } catch (e) {
          log.write('signOut: GAGAL (${e.runtimeType}); ');
        }
        log.write(
          'currentUserId setelah signOut: ${authD.currentUserId ?? "null"}; ',
        );
        try {
          await authD.signIn(
            email: 'dewi-$_run@example.test',
            password: _password,
          );
          log.write('signIn ulang: BERHASIL (seharusnya diblokir); ');
          fail('akun terhapus tidak boleh bisa masuk lagi');
        } on TestFailure {
          rethrow;
        } catch (e) {
          log.write('signIn ulang: ditolak ($e)');
        }
        // ignore: avoid_print
        print(log);
      },
    );
  }, skip: _skipReason);
}
