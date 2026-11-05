import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/activity/data/activity_mappers.dart';
import 'package:tether/features/activity/domain/activity_event.dart';
import 'package:tether/features/activity/presentation/activity_strings.dart';

import 'fake_activity.dart';

Map<String, dynamic> row(
  String type, {
  Object? payload = const <String, dynamic>{},
  Object? userId = 'u2',
}) => {
  'id': 'e1',
  'circle_id': 'c1',
  'user_id': userId,
  'type': type,
  'created_at': '2026-11-05T11:55:00.123456+00:00',
  'payload': payload,
};

void main() {
  group('activityEventFromRow', () {
    test('arrive membawa nama tempat', () {
      final e = activityEventFromRow(
        row('arrive', payload: {'place_name': 'Rumah', 'recorded_at': 'x'}),
      )!;
      expect(e.type, ActivityType.arrive);
      expect(e.placeName, 'Rumah');
      expect(e.displayName, isNull);
      expect(e.createdAt, DateTime.utc(2026, 11, 5, 11, 55, 0, 123, 456));
    });

    test('member_* dan checkin memakai display_name', () {
      final j = activityEventFromRow(
        row('member_joined', payload: {'display_name': 'Sinta'}),
      )!;
      expect(j.displayName, 'Sinta');
      final c = activityEventFromRow(
        row('checkin', payload: {'kind': 'safe', 'display_name': 'Budi'}),
      )!;
      expect(c.checkinKind, CheckinKind.safe);
      expect(
        activityEventFromRow(
          row('checkin', payload: {'kind': 'arrived'}),
        )!.checkinKind,
        CheckinKind.arrived,
      );
    });

    test('paused: minutes angka atau null', () {
      expect(
        activityEventFromRow(
          row('paused', payload: {'minutes': 30}),
        )!.pausedMinutes,
        30,
      );
      expect(
        activityEventFromRow(
          row('paused', payload: {'minutes': null}),
        )!.pausedMinutes,
        isNull,
      );
    });

    test('sos membawa koordinat dan triggered_at', () {
      final e = activityEventFromRow(
        row(
          'sos',
          payload: {
            'display_name': 'Rina',
            'lat': -6.2,
            'lng': 106,
            'accuracy_m': 12.5,
            'triggered_at': '2026-11-05T11:54:00Z',
          },
        ),
      )!;
      expect(e.lat, -6.2);
      expect(e.lng, 106.0);
      expect(e.hasCoordinates, isTrue);
      expect(e.triggeredAt, DateTime.utc(2026, 11, 5, 11, 54));
      expect(e.shownAt, e.triggeredAt);
    });

    test('sos setelah 48 jam (koordinat dibuang) tanpa koordinat', () {
      final e = activityEventFromRow(
        row('sos', payload: {'display_name': 'Rina', 'triggered_at': null}),
      )!;
      expect(e.hasCoordinates, isFalse);
      expect(e.shownAt, e.createdAt);
    });

    test('koordinat hanya dibaca untuk sos', () {
      final e = activityEventFromRow(
        row('arrive', payload: {'lat': 1.0, 'lng': 2.0}),
      )!;
      expect(e.lat, isNull);
    });

    test('baris tidak valid atau tipe tak dikenal menghasilkan null', () {
      expect(activityEventFromRow(row('geofence_x')), isNull);
      expect(activityEventFromRow(row('arrive', userId: null)), isNull);
      expect(activityEventFromRow({...row('arrive'), 'id': 5}), isNull);
      expect(
        activityEventFromRow({...row('arrive'), 'created_at': 'bukan'}),
        isNull,
      );
      expect(
        activityEventFromRow({...row('arrive'), 'circle_id': null}),
        isNull,
      );
    });

    test('payload bukan objek dan nama kosong diabaikan', () {
      expect(
        activityEventFromRow(row('arrive', payload: 'x'))!.placeName,
        isNull,
      );
      expect(
        activityEventFromRow(
          row('member_left', payload: {'display_name': '  '}),
        )!.displayName,
        isNull,
      );
    });
  });

  group('ActivityType', () {
    test('wire sesuai batasan events_type_check untuk sepuluh tipe', () {
      expect(ActivityType.wireValues, [
        'arrive',
        'leave',
        'member_joined',
        'member_left',
        'member_removed',
        'paused',
        'resumed',
        'checkin',
        'sos',
        'sharing_changed',
      ]);
      expect(ActivityType.parse('bukan'), isNull);
    });
  });

  group('ActivityStrings.sentence', () {
    String s(ActivityEvent e, [String who = 'Sinta']) =>
        ActivityStrings.sentence(e, who);

    test('semua tipe', () {
      expect(s(ev('1', place: 'Rumah')), 'Sinta tiba di Rumah');
      expect(
        s(ev('1', type: ActivityType.leave, place: 'Sekolah')),
        'Sinta meninggalkan Sekolah',
      );
      expect(s(ev('1')), 'Sinta tiba di sebuah tempat');
      expect(
        s(ev('1', type: ActivityType.memberJoined)),
        'Sinta bergabung ke Circle',
      );
      expect(
        s(ev('1', type: ActivityType.memberLeft)),
        'Sinta keluar dari Circle',
      );
      expect(
        s(ev('1', type: ActivityType.memberRemoved)),
        'Sinta dikeluarkan dari Circle',
      );
      expect(
        s(ev('1', type: ActivityType.resumed)),
        'Sinta melanjutkan berbagi lokasi',
      );
      expect(
        s(ev('1', type: ActivityType.checkin, kind: CheckinKind.arrived)),
        'Sinta memberi kabar: sudah sampai',
      );
      expect(
        s(ev('1', type: ActivityType.checkin, kind: CheckinKind.safe)),
        'Sinta memberi kabar: aman',
      );
      expect(s(ev('1', type: ActivityType.sos)), 'SOS dari Sinta');
      expect(
        s(ev('1', type: ActivityType.sharingChanged, sharingEnabled: false)),
        'Sinta mematikan berbagi lokasi untuk Circle ini',
      );
      expect(
        s(ev('1', type: ActivityType.sharingChanged, sharingEnabled: true)),
        'Sinta menyalakan berbagi lokasi Circle ini',
      );
    });

    test('paused: menit, jam, tanpa batas', () {
      String p(int? m) => s(ev('1', type: ActivityType.paused, minutes: m));
      expect(p(30), 'Sinta menjeda berbagi lokasi selama 30 menit');
      expect(p(60), 'Sinta menjeda berbagi lokasi selama 1 jam');
      expect(p(90), 'Sinta menjeda berbagi lokasi selama 90 menit');
      expect(p(null), 'Sinta menjeda berbagi lokasi sampai dinyalakan lagi');
    });

    test('subjek "Anda" untuk diri sendiri', () {
      expect(s(ev('1', place: 'Rumah'), 'Anda'), 'Anda tiba di Rumah');
    });
  });
}
