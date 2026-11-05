import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/selected_circle.dart';
import 'package:tether/features/activity/data/activity_providers.dart';
import 'package:tether/features/activity/domain/activity_event.dart';
import 'package:tether/features/activity/domain/notification_gateway.dart';
import 'package:tether/features/auth/data/auth_providers.dart';

import '../../support/fakes.dart';
import 'fake_activity.dart';

class Env {
  Env({FakeActivityRepository? repo, DateTime? marker, String? userId = 'u1'})
    : repo = repo ?? FakeActivityRepository(),
      gateway = FakeNotificationGateway(),
      store = MemoryReadMarkerStore(marker),
      auth = FakeAuthRepository(userId: userId) {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        activityRepositoryProvider.overrideWithValue(this.repo),
        notificationGatewayProvider.overrideWithValue(gateway),
        readMarkerStoreProvider.overrideWithValue(store),
        activityClockProvider.overrideWith(FixedActivityClock.new),
      ],
    );
  }

  final FakeActivityRepository repo;
  final FakeNotificationGateway gateway;
  final MemoryReadMarkerStore store;
  final FakeAuthRepository auth;
  late final ProviderContainer container;

  ActivityUnread get unread => container.read(activityUnreadProvider.notifier);
  int get count => container.read(activityUnreadProvider);

  /// Menyalakan pemantau dan menunggu inisialisasi selesai.
  Future<void> startMonitor() async {
    container.listen(activityUnreadProvider, (_, _) {});
    await pumpEventQueue();
  }

  /// Menjaga daftar Circle tetap hidup (provider otomatis dibuang).
  Future<ActivityListState> loadList(String circleId) async {
    container.listen(activityListProvider(circleId), (_, _) {});
    return container.read(activityListProvider(circleId).future);
  }

  ActivityListState list(String circleId) =>
      container.read(activityListProvider(circleId)).requireValue;

  void dispose() => container.dispose();
}

void main() {
  group('activityListProvider', () {
    test('memuat halaman pertama terbaru dulu beserta nama anggota', () async {
      final env = Env(
        repo: FakeActivityRepository(
          events: {
            'c1': [
              ev('a', minutesAgo: 30),
              ev('b', minutesAgo: 5),
              ev('c', minutesAgo: 10),
            ],
          },
          names: {'u2': 'Sinta'},
        ),
      );
      addTearDown(env.dispose);
      final s = await env.loadList('c1');
      expect(s.events.map((e) => e.id), ['b', 'c', 'a']);
      expect(s.names, {'u2': 'Sinta'});
      expect(s.hasMore, isFalse);
      expect(env.repo.subscriptions, ['c1']);
    });

    test('galat nama anggota tidak menggagalkan daftar', () async {
      final repo = FakeActivityRepository(
        events: {
          'c1': [ev('a')],
        },
      )..namesFailure = Exception('x');
      final env = Env(repo: repo);
      addTearDown(env.dispose);
      final s = await env.loadList('c1');
      expect(s.events, hasLength(1));
      expect(s.names, isEmpty);
    });

    test('galat memuat menjadi AsyncError', () async {
      final repo = FakeActivityRepository()..fetchFailure = Exception('x');
      final env = Env(repo: repo);
      addTearDown(env.dispose);
      env.container.listen(activityListProvider('c1'), (_, _) {});
      await expectLater(
        env.container.read(activityListProvider('c1').future),
        throwsException,
      );
    });

    test('event realtime masuk di atas, duplikat diabaikan', () async {
      final env = Env(
        repo: FakeActivityRepository(
          events: {
            'c1': [ev('a', minutesAgo: 30)],
          },
        ),
      );
      addTearDown(env.dispose);
      await env.loadList('c1');
      env.repo.insert(ev('n', minutesAgo: 0));
      env.repo.insert(ev('n', minutesAgo: 0));
      env.repo.insert(ev('lain', circleId: 'c2', minutesAgo: 0));
      await pumpEventQueue();
      expect(env.list('c1').events.map((e) => e.id), ['n', 'a']);
    });

    test('event realtime saat masih memuat tidak hilang', () async {
      final repo = FakeActivityRepository(
        events: {
          'c1': [ev('a', minutesAgo: 30)],
        },
      )..fetchGate = Completer<void>();
      final env = Env(repo: repo);
      addTearDown(env.dispose);
      env.container.listen(activityListProvider('c1'), (_, _) {});
      await pumpEventQueue();
      repo.insert(ev('n', minutesAgo: 0));
      await pumpEventQueue();
      repo.fetchGate!.complete();
      final s = await env.container.read(activityListProvider('c1').future);
      expect(s.events.map((e) => e.id), ['n', 'a']);
    });

    test(
      'paginasi: halaman penuh membuka hasMore, loadMore menambah',
      () async {
        final events = [
          for (var i = 0; i < 45; i++) ev('e$i', minutesAgo: i + 1),
        ];
        final env = Env(repo: FakeActivityRepository(events: {'c1': events}));
        addTearDown(env.dispose);
        final first = await env.loadList('c1');
        expect(first.events, hasLength(30));
        expect(first.hasMore, isTrue);

        await env.container
            .read(activityListProvider('c1').notifier)
            .loadMore();
        final s = env.list('c1');
        expect(s.events, hasLength(45));
        expect(s.events.map((e) => e.id).toSet(), hasLength(45));
        expect(s.hasMore, isFalse);
        expect(s.loadingMore, isFalse);
        // Urutan tetap menurun menurut waktu.
        for (var i = 1; i < s.events.length; i++) {
          expect(
            s.events[i].createdAt.isAfter(s.events[i - 1].createdAt),
            isFalse,
          );
        }
        expect(env.repo.fetchCalls.last.before, events[29].createdAt);
      },
    );

    test('loadMore gagal ditandai dan bisa diulang', () async {
      final events = [
        for (var i = 0; i < 40; i++) ev('e$i', minutesAgo: i + 1),
      ];
      final env = Env(repo: FakeActivityRepository(events: {'c1': events}));
      addTearDown(env.dispose);
      await env.loadList('c1');
      final notifier = env.container.read(activityListProvider('c1').notifier);
      env.repo.fetchFailuresLeft = 1;
      await notifier.loadMore();
      expect(env.list('c1').loadMoreFailed, isTrue);
      expect(env.list('c1').events, hasLength(30));
      await notifier.loadMore();
      expect(env.list('c1').loadMoreFailed, isFalse);
      expect(env.list('c1').events, hasLength(40));
    });

    test(
      'sambung ulang realtime mengambil ulang event yang terlewat',
      () async {
        final env = Env(
          repo: FakeActivityRepository(
            events: {
              'c1': [ev('a', minutesAgo: 30)],
            },
          ),
        );
        addTearDown(env.dispose);
        await env.loadList('c1');
        env.repo.connection(false);
        await pumpEventQueue();
        expect(env.list('c1').realtimeConnected, isFalse);
        env.repo.events['c1']!.add(ev('missed', minutesAgo: 1));
        env.repo.connection(true);
        await pumpEventQueue();
        expect(env.list('c1').realtimeConnected, isTrue);
        expect(env.list('c1').events.map((e) => e.id), ['missed', 'a']);
      },
    );

    test('member_joined baru memuat ulang nama anggota', () async {
      final repo = FakeActivityRepository(
        events: {
          'c1': [ev('a', minutesAgo: 30)],
        },
        names: {'u2': 'Sinta'},
      );
      final env = Env(repo: repo);
      addTearDown(env.dispose);
      await env.loadList('c1');
      final before = repo.namesCalls;
      repo.insert(ev('j', userId: 'u9', type: ActivityType.memberJoined));
      await pumpEventQueue();
      expect(repo.namesCalls, before + 1);
    });

    test('langganan dibatalkan saat provider dibuang', () async {
      final env = Env(repo: FakeActivityRepository());
      final sub = env.container.listen(activityListProvider('c1'), (_, _) {});
      await env.container.read(activityListProvider('c1').future);
      sub.close();
      await pumpEventQueue();
      expect(env.repo.cancels, 1);
      env.dispose();
    });
  });

  group('activityUnreadProvider', () {
    test('mulai: inisialisasi gateway aman, izin diminta', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      expect(env.gateway.initCalls, 1);
      expect(env.gateway.permissionCalls, 1);
      // Satu langganan tanpa filter Circle (semua Circle, dibatasi RLS).
      expect(env.repo.subscriptions, [null]);
    });

    test('pertama kali: penanda dibuat dan lencana nol', () async {
      final env = Env();
      addTearDown(env.dispose);
      env.repo.unreadIds = ['x', 'y'];
      await env.startMonitor();
      expect(env.count, 0);
      expect(env.store.value, fixedNow);
      expect(env.repo.sinceCalls, isEmpty);
    });

    test('jumlah awal dari event setelah penanda', () async {
      final marker = fixedNow.subtract(const Duration(hours: 2));
      final env = Env(marker: marker);
      addTearDown(env.dispose);
      env.repo.unreadIds = ['x', 'y', 'z'];
      await env.startMonitor();
      expect(env.count, 3);
      expect(env.repo.sinceCalls, [marker]);
      // Event lama tidak memicu notifikasi.
      expect(env.gateway.shown, isEmpty);
    });

    test('event orang lain: lencana naik dan notifikasi tampil', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      env.repo.names.addAll({'u2': 'Sinta'});
      await env.startMonitor();
      env.repo.insert(ev('n1', place: 'Rumah'));
      await pumpEventQueue();
      expect(env.count, 1);
      final n = env.gateway.shown.single;
      expect(n.title, 'Keluarga');
      expect(n.body, 'Sinta tiba di Rumah');
      expect(n.urgency, NotificationUrgency.normal);
      expect(n.payload, 'c1');
    });

    test('nama dari payload dipakai tanpa kueri nama', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(ev('n1', type: ActivityType.memberJoined, name: 'Budi'));
      await pumpEventQueue();
      expect(env.gateway.shown.single.body, 'Budi bergabung ke Circle');
      expect(env.repo.namesCalls, 0);
    });

    test('nama tidak diketahui: "Seorang anggota"', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(ev('n1', type: ActivityType.resumed));
      await pumpEventQueue();
      expect(
        env.gateway.shown.single.body,
        'Seorang anggota melanjutkan berbagi lokasi',
      );
    });

    test(
      'event milik sendiri tidak dihitung dan tidak dinotifikasikan',
      () async {
        final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
        addTearDown(env.dispose);
        await env.startMonitor();
        env.repo.insert(ev('mine', userId: 'u1'));
        await pumpEventQueue();
        expect(env.count, 0);
        expect(env.gateway.shown, isEmpty);
      },
    );

    test('event duplikat (sambung ulang) hanya dihitung sekali', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(ev('n1'));
      env.repo.insert(ev('n1'));
      await pumpEventQueue();
      expect(env.count, 1);
      expect(env.gateway.shown, hasLength(1));
    });

    test('SOS memakai prioritas tinggi tanpa koordinat di teks', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(
        ev('s1', type: ActivityType.sos, name: 'Sinta', lat: -6.2, lng: 106.8),
      );
      await pumpEventQueue();
      final n = env.gateway.shown.single;
      expect(n.urgency, NotificationUrgency.high);
      expect(n.title, 'SOS dari Sinta');
      expect(n.body, contains('Keluarga'));
      expect('${n.title} ${n.body}', isNot(contains('-6.2')));
    });

    test('SOS dua Circle (client_id sama) hanya satu notifikasi', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(
        ev('s1', type: ActivityType.sos, name: 'Sinta', clientId: 'x'),
      );
      env.repo.insert(
        ev('s2', type: ActivityType.sos, name: 'Sinta', clientId: 'x'),
      );
      await pumpEventQueue();
      expect(env.gateway.shown, hasLength(1));
      expect(env.gateway.shown.single.title, 'SOS dari Sinta');
      // client_id berbeda tetap dinotifikasikan.
      env.repo.insert(
        ev('s3', type: ActivityType.sos, name: 'Sinta', clientId: 'y'),
      );
      await pumpEventQueue();
      expect(env.gateway.shown, hasLength(2));
    });

    test(
      'tab terlihat: event biasa tanpa lencana dan notifikasi, SOS tetap',
      () async {
        final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
        addTearDown(env.dispose);
        await env.startMonitor();
        env.unread.setTabVisible(true);
        env.repo.insert(ev('n1'));
        env.repo.insert(ev('s1', type: ActivityType.sos, name: 'Sinta'));
        await pumpEventQueue();
        expect(env.count, 0);
        expect(env.gateway.shown.map((n) => n.urgency), [
          NotificationUrgency.high,
        ]);
      },
    );

    test('markAllRead nol-kan lencana dan menyimpan waktu server', () async {
      final marker = fixedNow.subtract(const Duration(hours: 2));
      final env = Env(marker: marker);
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(ev('n1', minutesAgo: 3));
      env.repo.insert(ev('n2', minutesAgo: 1));
      await pumpEventQueue();
      expect(env.count, 2);
      await env.unread.markAllRead();
      expect(env.count, 0);
      expect(env.store.value, fixedNow.subtract(const Duration(minutes: 1)));
    });

    test('penanda tidak pernah mundur', () async {
      final marker = fixedNow.subtract(const Duration(minutes: 1));
      final env = Env(marker: marker);
      addTearDown(env.dispose);
      await env.startMonitor();
      await env.unread.markAllRead(
        newestSeen: fixedNow.subtract(const Duration(hours: 5)),
      );
      expect(env.store.value, marker);
    });

    test('markAllRead memakai created_at event terbaru dari daftar', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 2)));
      addTearDown(env.dispose);
      await env.startMonitor();
      final newest = fixedNow.subtract(const Duration(minutes: 7));
      await env.unread.markAllRead(newestSeen: newest);
      expect(env.store.value, newest);
    });

    test('ganti akun: event terbaru akun lama tidak dipakai menggeser penanda '
        'akun baru', () async {
      final marker = fixedNow.subtract(const Duration(hours: 2));
      final env = Env(marker: marker);
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.insert(ev('n1', minutesAgo: 1));
      await pumpEventQueue();
      expect(env.count, 1);

      env.auth.emit('u2');
      await pumpEventQueue();
      expect(env.count, 0);
      await env.unread.markAllRead();
      expect(env.store.value, marker, reason: 'penanda akun baru tidak maju');
    });

    test('sambung ulang memuat ulang jumlah belum dibaca', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.repo.unreadIds = ['a', 'b'];
      env.repo.connection(false);
      env.repo.connection(true);
      await pumpEventQueue();
      expect(env.count, 2);
    });

    test('ketuk notifikasi memilih Circle-nya', () async {
      final env = Env(marker: fixedNow.subtract(const Duration(hours: 1)));
      addTearDown(env.dispose);
      await env.startMonitor();
      env.gateway.tapController.add('c2');
      await pumpEventQueue();
      expect(env.container.read(selectedCircleIdProvider), 'c2');
    });

    test('belum masuk: tidak berlangganan, lencana nol', () async {
      final env = Env(userId: null);
      addTearDown(env.dispose);
      await env.startMonitor();
      expect(env.count, 0);
      expect(env.repo.subscriptions, isEmpty);
      expect(env.gateway.initCalls, 0);
    });
  });
}
