import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/activity/data/supabase_activity_repository.dart';
import 'package:tether/features/activity/domain/activity_event.dart';
import 'package:tether/features/activity/domain/activity_repository.dart';

import '../map/supabase_map_repository_test.dart'
    show FakePostgrest, clientFor, err, ok;

Map<String, dynamic> eventRow(
  String id,
  String type,
  String createdAt, {
  Map<String, dynamic> payload = const {},
}) => {
  'id': id,
  'circle_id': 'c1',
  'user_id': 'u2',
  'type': type,
  'created_at': createdAt,
  'payload': payload,
};

void main() {
  late FakePostgrest server;
  late SupabaseActivityRepository repo;

  setUp(() async {
    server = await FakePostgrest.start();
    repo = SupabaseActivityRepository(await clientFor(server, uid: 'u1'));
  });
  tearDown(() => server.close());

  group('fetchEvents', () {
    test('memfilter Circle dan tipe, urut menurun, batas halaman', () async {
      server.routes['/rest/v1/events'] = (_) => ok([
        eventRow(
          'e2',
          'arrive',
          '2026-11-05T11:55:00+00:00',
          payload: {'place_name': 'Rumah'},
        ),
        eventRow(
          'e1',
          'sos',
          '2026-11-05T11:00:00+00:00',
          payload: {'display_name': 'Rina', 'lat': -6.2, 'lng': 106.8},
        ),
      ]);
      final list = await repo.fetchEvents('c1', limit: 20);
      expect(list.map((e) => e.id), ['e2', 'e1']);
      expect(list.first.placeName, 'Rumah');
      expect(list.last.hasCoordinates, isTrue);

      final q = server.requests.single.uri.queryParameters;
      expect(q['circle_id'], 'eq.c1');
      expect(q['order'], startsWith('created_at.desc'));
      expect(q['limit'], '20');
      expect(q['created_at'], isNull);
      for (final t in ActivityType.wireValues) {
        expect(q['type'], contains(t));
      }
    });

    test('paginasi memakai created_at kurang dari batas', () async {
      server.routes['/rest/v1/events'] = (_) => ok([]);
      await repo.fetchEvents('c1', before: DateTime.utc(2026, 11, 5, 11));
      final q = server.requests.single.uri.queryParameters;
      expect(q['created_at'], startsWith('lt.2026-11-05T11:00:00'));
    });

    test('baris tak valid dilewati', () async {
      server.routes['/rest/v1/events'] = (_) => ok([
        eventRow('e1', 'tipe_baru', '2026-11-05T11:00:00+00:00'),
        eventRow('e2', 'resumed', '2026-11-05T10:00:00+00:00'),
      ]);
      final list = await repo.fetchEvents('c1');
      expect(list.map((e) => e.id), ['e2']);
    });

    test('galat server menjadi ActivityFailure.unknown', () async {
      server.routes['/rest/v1/events'] = (_) => err(500, 'XX000');
      await expectLater(
        repo.fetchEvents('c1'),
        throwsA(
          isA<ActivityFailure>().having(
            (f) => f.kind,
            'kind',
            ActivityFailureKind.unknown,
          ),
        ),
      );
    });

    test('galat 28000 menjadi unauthenticated', () async {
      server.routes['/rest/v1/events'] = (_) => err(401, '28000');
      await expectLater(
        repo.fetchEvents('c1'),
        throwsA(
          isA<ActivityFailure>().having(
            (f) => f.kind,
            'kind',
            ActivityFailureKind.unauthenticated,
          ),
        ),
      );
    });
  });

  test('fetchMemberNames memetakan id ke nama profil', () async {
    server.routes['/rest/v1/circle_members'] = (_) => ok([
      {
        'user_id': 'u1',
        'profiles': {'display_name': 'Rina'},
      },
      {'user_id': 'u2', 'profiles': null},
    ]);
    expect(await repo.fetchMemberNames('c1'), {'u1': 'Rina'});
  });

  test('fetchCircleName', () async {
    server.routes['/rest/v1/circles'] = (_) => ok([
      {'name': 'Keluarga'},
    ]);
    expect(await repo.fetchCircleName('c1'), 'Keluarga');
  });

  test('fetchEventIdsSince mengecualikan diri sendiri dan membatasi', () async {
    server.routes['/rest/v1/events'] = (_) => ok([
      {'id': 'a'},
      {'id': 'b'},
    ]);
    final ids = await repo.fetchEventIdsSince(
      DateTime.utc(2026, 11, 5, 10),
      excludeUserId: 'u1',
      cap: 50,
    );
    expect(ids, ['a', 'b']);
    final q = server.requests.single.uri.queryParameters;
    expect(q['user_id'], 'neq.u1');
    expect(q['created_at'], startsWith('gt.2026-11-05T10:00:00'));
    expect(q['limit'], '50');
  });
}
