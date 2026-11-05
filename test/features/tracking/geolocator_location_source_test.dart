import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';
import 'package:tether/features/location_tracking/domain/tracking_policy.dart';
import 'package:tether/features/tracking/data/geolocator_location_source.dart';

final _base = DateTime.utc(2026, 1, 1);

Position _pos({
  double speed = 0,
  bool hasSpeed = false,
  double accuracy = 0,
  bool hasAccuracy = false,
  DateTime? at,
  double lat = -6.2,
  double lng = 106.8,
}) => Position(
  longitude: lng,
  latitude: lat,
  timestamp: at ?? _base,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
  hasSpeed: hasSpeed,
  hasAccuracy: hasAccuracy,
);

/// cancel() bawaan stream mengembalikan future global yang lanjutannya lolos
/// dari FakeAsync. Pembungkus ini mengembalikan future di zona waktu palsu.
class _FakeZoneStream extends Stream<Position> {
  _FakeZoneStream(this._inner);

  final Stream<Position> _inner;

  @override
  StreamSubscription<Position> listen(
    void Function(Position event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _FakeZoneSubscription(
    _inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
  );
}

class _FakeZoneSubscription implements StreamSubscription<Position> {
  _FakeZoneSubscription(this._inner);

  final StreamSubscription<Position> _inner;

  @override
  Future<void> cancel() {
    unawaited(_inner.cancel());
    return Future<void>.value();
  }

  @override
  void onData(void Function(Position data)? handleData) =>
      _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}

void main() {
  group('locationSettingsFor', () {
    test('akurasi per mode', () {
      LocationAccuracy of(TrackingMode m) =>
          locationSettingsFor(m, TargetPlatform.linux).accuracy;
      expect(of(TrackingMode.moving), LocationAccuracy.high);
      expect(of(TrackingMode.stationary), LocationAccuracy.medium);
      expect(of(TrackingMode.batterySaver), LocationAccuracy.low);
    });

    test('filter jarak per mode mengikuti kebijakan', () {
      for (final m in TrackingMode.values) {
        expect(
          locationSettingsFor(m, TargetPlatform.linux).distanceFilter,
          TrackingPolicy.distanceFilterFor(m).round(),
        );
      }
    });

    test(
      'Android: interval mode dan notifikasi foreground tanpa koordinat',
      () {
        final s =
            locationSettingsFor(TrackingMode.moving, TargetPlatform.android)
                as AndroidSettings;
        expect(s.intervalDuration, TrackingPolicy.movingInterval);
        expect(
          locationSettingsFor(TrackingMode.batterySaver, TargetPlatform.android)
              as AndroidSettings,
          isA<AndroidSettings>().having(
            (a) => a.intervalDuration,
            'interval',
            TrackingPolicy.batterySaverInterval,
          ),
        );
        final n = s.foregroundNotificationConfig!;
        expect(n.notificationTitle, foregroundNotificationTitle);
        expect(n.notificationText, foregroundNotificationText);
        expect(n.notificationChannelName, foregroundNotificationChannel);
        expect(n.setOngoing, isTrue);
        for (final t in [n.notificationTitle, n.notificationText]) {
          expect(t, isNot(contains('-6.2')));
          expect(t, isNot(contains('106.8')));
        }
      },
    );

    test('iOS dan macOS: pengaturan Apple tanpa pembaruan latar belakang', () {
      for (final p in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        final s =
            locationSettingsFor(TrackingMode.stationary, p) as AppleSettings;
        expect(s.allowBackgroundLocationUpdates, iosAllowBackgroundUpdates);
        expect(s.pauseLocationUpdatesAutomatically, isFalse);
        expect(s.showBackgroundLocationIndicator, isFalse);
        expect(s.activityType, ActivityType.other);
      }
    });

    test('platform lain: pengaturan dasar', () {
      final s = locationSettingsFor(
        TrackingMode.stationary,
        TargetPlatform.linux,
      );
      expect(s, isNot(isA<AndroidSettings>()));
      expect(s, isNot(isA<AppleSettings>()));
    });
  });

  group('positionToPoint', () {
    test('menyalin koordinat dan waktu (UTC)', () {
      final p = positionToPoint(
        _pos(at: DateTime(2026, 3, 4, 5, 6, 7), lat: -6.25, lng: 106.75),
      );
      expect(p.lat, -6.25);
      expect(p.lng, 106.75);
      expect(p.recordedAt.isUtc, isTrue);
    });

    test('kecepatan 0 tanpa penanda tersedia dianggap tidak ada', () {
      final p = positionToPoint(_pos(speed: 0));
      expect(p.speedMps, isNull);
      expect(p.isMoving, isFalse);
    });

    test('kecepatan 0 dengan hasSpeed tetap 0', () {
      final p = positionToPoint(_pos(speed: 0, hasSpeed: true));
      expect(p.speedMps, 0);
      expect(p.isMoving, isFalse);
    });

    test('kecepatan positif tanpa hasSpeed tetap dipakai', () {
      final p = positionToPoint(_pos(speed: 3));
      expect(p.speedMps, 3);
      expect(p.isMoving, isTrue);
    });

    test('isMoving mengikuti ambang 1.5 m/s', () {
      expect(positionToPoint(_pos(speed: 1.49)).isMoving, isFalse);
      expect(positionToPoint(_pos(speed: 1.5)).isMoving, isTrue);
    });

    test('kecepatan negatif (sentinel) dibuang', () {
      expect(positionToPoint(_pos(speed: -1)).speedMps, isNull);
      expect(positionToPoint(_pos(speed: -1, hasSpeed: true)).speedMps, isNull);
    });

    test('akurasi 0 tanpa penanda tersedia dianggap tidak ada', () {
      expect(positionToPoint(_pos(accuracy: 0)).accuracyM, isNull);
    });

    test('akurasi 0 dengan hasAccuracy tetap 0; positif dipakai', () {
      expect(positionToPoint(_pos(hasAccuracy: true)).accuracyM, 0);
      expect(positionToPoint(_pos(accuracy: 12.5)).accuracyM, 12.5);
    });

    test('akurasi negatif dibuang', () {
      expect(positionToPoint(_pos(accuracy: -1)).accuracyM, isNull);
    });

    test('baterai dijepit 0 sampai 100, null tetap null', () {
      expect(positionToPoint(_pos(), batteryPct: 150).batteryPct, 100);
      expect(positionToPoint(_pos(), batteryPct: -5).batteryPct, 0);
      expect(positionToPoint(_pos(), batteryPct: 42).batteryPct, 42);
      expect(positionToPoint(_pos()).batteryPct, isNull);
    });
  });

  group('describeSourceError', () {
    test('layanan lokasi mati', () {
      expect(
        describeSourceError(const LocationServiceDisabledException()),
        'Layanan lokasi perangkat mati.',
      );
    });

    test('izin ditolak', () {
      expect(
        describeSourceError(const PermissionDeniedException('x')),
        'Izin lokasi ditolak.',
      );
    });

    test('timeout', () {
      expect(
        describeSourceError(TimeoutException('x')),
        'Sinyal lokasi belum didapat.',
      );
    });

    test('lainnya hanya menyebut tipe, tanpa isi pesan', () {
      final text = describeSourceError(StateError('-6.2,106.8'));
      expect(text, 'Sumber lokasi gagal (StateError).');
      expect(text, isNot(contains('106.8')));
    });
  });

  group('GeolocatorLocationSource', () {
    late List<StreamController<Position>> streams;
    late List<LocationSettings> settingsLog;
    late List<Object?> problems;
    late List<LocationPoint> points;
    late int currentCalls;
    late Object? currentError;
    late int? battery;

    /// Menjalankan [body] dengan waktu palsu; stream posisi dan baterai palsu.
    void run(
      void Function(FakeAsync async, GeolocatorLocationSource source) body, {
      TargetPlatform platform = TargetPlatform.android,
      Future<int?> Function()? batteryReader,
    }) {
      streams = [];
      settingsLog = [];
      problems = [];
      points = [];
      currentCalls = 0;
      currentError = null;
      battery = 80;
      FakeAsync().run((async) {
        DateTime now() => _base.add(async.elapsed);
        final source = GeolocatorLocationSource(
          platform: platform,
          positionStream: (settings) {
            settingsLog.add(settings);
            final c = StreamController<Position>.broadcast();
            streams.add(c);
            return _FakeZoneStream(c.stream);
          },
          currentPosition: (settings) async {
            currentCalls++;
            final e = currentError;
            if (e != null) throw e;
            return _pos(at: now());
          },
          batteryLevel: batteryReader ?? () async => battery,
          now: now,
          onProblem: problems.add,
        );
        source.points.listen(points.add);
        body(async, source);
        source.stop();
        async.flushMicrotasks();
      });
    }

    Position fast(FakeAsync a) =>
        _pos(speed: 3, hasSpeed: true, at: _base.add(a.elapsed));
    Position still(FakeAsync a) => _pos(at: _base.add(a.elapsed));

    test('start membuka stream dengan pengaturan mode diam, sekali saja', () {
      run((async, source) {
        source.start();
        source.start();
        async.flushMicrotasks();
        expect(streams, hasLength(1));
        expect(settingsLog.single.accuracy, LocationAccuracy.medium);
        expect(settingsLog.single, isA<AndroidSettings>());
        expect(source.mode, TrackingMode.stationary);
      });
    });

    test('posisi diubah jadi titik dengan baterai dan melapor sehat', () {
      run((async, source) {
        source.start();
        streams.single.add(_pos(speed: 0, accuracy: 7, at: _base));
        async.flushMicrotasks();
        expect(points, hasLength(1));
        expect(points.single.batteryPct, 80);
        expect(points.single.accuracyM, 7);
        expect(problems, [null]);
      });
    });

    test('baterai gagal dibaca: titik tetap terkirim tanpa baterai', () {
      run((async, source) {
        source.start();
        streams.single.add(still(async));
        async.flushMicrotasks();
        expect(points.single.batteryPct, isNull);
      }, batteryReader: () async => null);
    });

    test(
      'kecepatan tinggi memindah ke mode bergerak dan membuka ulang stream',
      () {
        run((async, source) {
          source.start();
          final first = streams.single;
          first.add(fast(async));
          async.flushMicrotasks();

          expect(source.mode, TrackingMode.moving);
          expect(
            first.hasListener,
            isFalse,
            reason: 'langganan lama dibatalkan',
          );
          expect(streams, hasLength(2));
          expect(settingsLog.last.accuracy, LocationAccuracy.high);
          expect(
            settingsLog.last.distanceFilter,
            TrackingPolicy.movingDistanceFilterM.round(),
          );
          expect(streams.last.hasListener, isTrue);
        });
      },
    );

    test('baterai rendah memindah ke mode hemat', () {
      run((async, source) {
        battery = 10;
        source.start();
        streams.single.add(still(async));
        async.flushMicrotasks();
        expect(source.mode, TrackingMode.batterySaver);
        expect(settingsLog.last.accuracy, LocationAccuracy.low);
      });
    });

    test('titik pada stream baru tetap diteruskan', () {
      run((async, source) {
        source.start();
        streams.first.add(fast(async));
        async.flushMicrotasks();
        streams.last.add(fast(async));
        async.flushMicrotasks();
        expect(points, hasLength(2));
        expect(streams, hasLength(2), reason: 'mode sama, tidak dibuka ulang');
      });
    });

    test('galat stream dilaporkan, titik berikutnya menghapus galat', () {
      run((async, source) {
        source.start();
        final e = const LocationServiceDisabledException();
        streams.single.addError(e);
        async.flushMicrotasks();
        expect(problems, [e]);

        streams.single.add(still(async));
        async.flushMicrotasks();
        expect(problems, [e, null]);
      });
    });

    test(
      'pengawas mode bergerak: sunyi selama movingHold turun ke mode diam',
      () {
        run((async, source) {
          source.start();
          streams.single.add(fast(async));
          async.flushMicrotasks();
          expect(source.mode, TrackingMode.moving);

          async.elapse(const Duration(minutes: 2));
          expect(source.mode, TrackingMode.stationary);
          expect(settingsLog.last.accuracy, LocationAccuracy.medium);
          expect(currentCalls, 0);
        });
      },
    );

    test(
      'pengawas mode diam: tanpa titik selama interval mengambil satu posisi',
      () {
        run((async, source) {
          source.start();
          async.elapse(
            TrackingPolicy.stationaryInterval - const Duration(seconds: 1),
          );
          expect(currentCalls, 0);
          expect(points, isEmpty);

          async.elapse(const Duration(seconds: 1));
          expect(currentCalls, 1);
          expect(points, hasLength(1));
          expect(problems, [null]);
        });
      },
    );

    test('pengawas mode hemat memakai interval 5 menit', () {
      run((async, source) {
        battery = 5;
        source.start();
        streams.single.add(still(async));
        async.flushMicrotasks();
        expect(source.mode, TrackingMode.batterySaver);
        final before = currentCalls;

        async.elapse(TrackingPolicy.batterySaverInterval);
        expect(currentCalls, before + 1);
      });
    });

    test('detak berulang tiap interval selama tidak ada titik dari stream', () {
      run((async, source) {
        source.start();
        async.elapse(TrackingPolicy.stationaryInterval * 3);
        expect(currentCalls, 3);
        expect(points, hasLength(3));
      });
    });

    test('gagal mengambil posisi dilaporkan lalu dicoba lagi', () {
      run((async, source) {
        currentError = TimeoutException('lama');
        source.start();
        async.elapse(TrackingPolicy.stationaryInterval);
        expect(currentCalls, 1);
        expect(problems.single, isA<TimeoutException>());
        expect(points, isEmpty);

        currentError = null;
        async.elapse(TrackingPolicy.stationaryInterval);
        expect(currentCalls, 2);
        expect(points, hasLength(1));
        expect(problems.last, isNull);
      });
    });

    test('stop membatalkan langganan dan pengawas', () {
      run((async, source) {
        source.start();
        source.stop();
        async.flushMicrotasks();
        expect(streams.single.hasListener, isFalse);

        async.elapse(TrackingPolicy.stationaryInterval * 2);
        expect(currentCalls, 0);
      });
    });

    test('titik yang tiba saat stop (menunggu baterai) dibuang', () {
      final gate = Completer<int?>();
      run((async, source) {
        source.start();
        streams.single.add(still(async));
        async.flushMicrotasks();
        source.stop();
        gate.complete(50);
        async.flushMicrotasks();
        expect(points, isEmpty);
        expect(problems, isEmpty);
      }, batteryReader: () => gate.future);
    });

    test('bisa start lagi sesudah stop', () {
      run((async, source) {
        source.start();
        source.stop();
        async.flushMicrotasks();
        source.start();
        async.flushMicrotasks();
        expect(streams, hasLength(2));
        expect(streams.last.hasListener, isTrue);
      });
    });
  });
}
