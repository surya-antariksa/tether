import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../location_tracking/domain/location_point.dart';
import '../../location_tracking/domain/location_source.dart';
import '../../location_tracking/domain/tracking_policy.dart';
import '../domain/tracking_mode_governor.dart';

/// Teks notifikasi layanan foreground Android. Sengaja tanpa koordinat.
const String foregroundNotificationTitle = 'Tether';
const String foregroundNotificationText =
    'Tether sedang membagikan lokasimu ke Circle keluarga';
const String foregroundNotificationChannel = 'Berbagi lokasi';

/// iOS: pembaruan di background butuh UIBackgroundModes `location` di
/// Info.plist, yang belum ditambahkan (ios/ belum disentuh). Tanpa itu,
/// mengaktifkannya membuat CLLocationManager melempar pengecualian.
const bool iosAllowBackgroundUpdates = false;

/// Pengaturan stream untuk [mode] dan [platform]. Akurasi per mode adalah
/// asumsi awal (perlu kalibrasi di Sprint 0B); jarak dan interval dari
/// [TrackingPolicy].
LocationSettings locationSettingsFor(
  TrackingMode mode,
  TargetPlatform platform,
) {
  final accuracy = switch (mode) {
    TrackingMode.moving => LocationAccuracy.high,
    TrackingMode.stationary => LocationAccuracy.medium,
    TrackingMode.batterySaver => LocationAccuracy.low,
  };
  final distanceFilter = TrackingPolicy.distanceFilterFor(mode).round();
  switch (platform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: TrackingPolicy.intervalFor(mode),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: foregroundNotificationTitle,
          notificationText: foregroundNotificationText,
          notificationChannelName: foregroundNotificationChannel,
          setOngoing: true,
        ),
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
        allowBackgroundLocationUpdates: iosAllowBackgroundUpdates,
      );
    default:
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
  }
}

/// Memetakan [Position] ke [LocationPoint]. Nilai 0 pada Position berarti
/// "tidak tersedia" kecuali platform menandai tersedia (hasSpeed, hasAccuracy).
LocationPoint positionToPoint(Position p, {int? batteryPct}) {
  final hasSpeed = (p.hasSpeed || p.speed > 0) && p.speed >= 0;
  final speed = hasSpeed ? p.speed : null;
  final hasAccuracy = (p.hasAccuracy || p.accuracy > 0) && p.accuracy >= 0;
  return LocationPoint(
    lat: p.latitude,
    lng: p.longitude,
    accuracyM: hasAccuracy ? p.accuracy : null,
    speedMps: speed,
    batteryPct: batteryPct?.clamp(0, 100),
    isMoving: TrackingPolicy.modeFor(speed, null) == TrackingMode.moving,
    recordedAt: p.timestamp,
  );
}

/// Teks galat sumber lokasi yang aman (tanpa koordinat).
String describeSourceError(Object error) {
  if (error is LocationServiceDisabledException) {
    return 'Layanan lokasi perangkat mati.';
  }
  if (error is PermissionDeniedException) return 'Izin lokasi ditolak.';
  if (error is TimeoutException) return 'Sinyal lokasi belum didapat.';
  return 'Sumber lokasi gagal (${error.runtimeType}).';
}

typedef PositionStreamFactory =
    Stream<Position> Function(LocationSettings settings);
typedef CurrentPositionFetcher =
    Future<Position> Function(LocationSettings settings);
typedef BatteryLevelReader = Future<int?> Function();

/// Level baterai atau null bila gagal (mis. Linux tanpa UPower).
Future<int?> defaultBatteryLevel() async {
  try {
    return await Battery().batteryLevel.timeout(const Duration(seconds: 2));
  } catch (_) {
    return null;
  }
}

/// Sumber lokasi GPS nyata (Android dan iOS) lewat geolocator.
///
/// Mode adaptif: [TrackingModeGovernor] memilih mode per titik, lalu stream
/// dibuka ulang dengan pengaturan mode itu. Pengatur waktu pengawas:
/// - mode bergerak tanpa titik selama [TrackingModeGovernor.movingHold]:
///   dianggap berhenti, turun ke mode diam (filter jarak membuat stream sunyi
///   saat diam);
/// - mode diam/hemat tanpa titik selama interval mode: ambil satu posisi
///   sebagai detak supaya anggota lain tidak melihat status basi.
class GeolocatorLocationSource implements LocationSource {
  GeolocatorLocationSource({
    TargetPlatform? platform,
    PositionStreamFactory? positionStream,
    CurrentPositionFetcher? currentPosition,
    BatteryLevelReader? batteryLevel,
    TrackingModeGovernor? governor,
    DateTime Function()? now,
    this.onProblem,
  }) : _platform = platform ?? defaultTargetPlatform,
       _positionStream =
           positionStream ??
           ((s) => Geolocator.getPositionStream(locationSettings: s)),
       _currentPosition =
           currentPosition ??
           ((s) => Geolocator.getCurrentPosition(
             locationSettings: s,
           ).timeout(const Duration(seconds: 30))),
       _battery = batteryLevel ?? defaultBatteryLevel,
       _governor = governor ?? TrackingModeGovernor(),
       _now = now ?? DateTime.now;

  final TargetPlatform _platform;
  final PositionStreamFactory _positionStream;
  final CurrentPositionFetcher _currentPosition;
  final BatteryLevelReader _battery;
  final TrackingModeGovernor _governor;
  final DateTime Function() _now;

  /// Dipanggil dengan galat sumber, atau null saat titik berikutnya tiba.
  final void Function(Object? problem)? onProblem;

  final _controller = StreamController<LocationPoint>.broadcast();
  StreamSubscription<Position>? _sub;
  Timer? _watchdog;
  bool _started = false;
  bool _reconfiguring = false;

  TrackingMode get mode => _governor.mode;

  @override
  Stream<LocationPoint> get points => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _listen();
    _armWatchdog();
  }

  @override
  Future<void> stop() async {
    _started = false;
    _watchdog?.cancel();
    _watchdog = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  void _listen() {
    _sub = _positionStream(locationSettingsFor(_governor.mode, _platform))
        .listen(
          (p) => unawaited(_onPosition(p)),
          onError: (Object e) => onProblem?.call(e),
        );
  }

  Future<void> _onPosition(Position p) async {
    if (!_started) return;
    final battery = await _battery();
    if (!_started) return;
    final point = positionToPoint(p, batteryPct: battery);
    _controller.add(point);
    onProblem?.call(null);
    final changed = _governor.onSample(
      speedMps: point.speedMps,
      batteryPct: point.batteryPct,
      at: point.recordedAt,
    );
    if (changed) await _reconfigure();
    _armWatchdog();
  }

  /// Menutup stream lalu membukanya lagi dengan pengaturan mode baru. Plugin
  /// Android menyimpan stream bersama selama masih ada pendengar, jadi
  /// langganan lama harus dibatalkan dulu.
  Future<void> _reconfigure() async {
    if (_reconfiguring || !_started) return;
    _reconfiguring = true;
    try {
      final old = _sub;
      _sub = null;
      await old?.cancel();
      if (_started) _listen();
    } finally {
      _reconfiguring = false;
    }
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    if (!_started) return;
    final wait = switch (_governor.mode) {
      TrackingMode.moving => _governor.movingHold,
      TrackingMode.stationary => TrackingPolicy.stationaryInterval,
      TrackingMode.batterySaver => TrackingPolicy.batterySaverInterval,
    };
    _watchdog = Timer(wait, () => unawaited(_onQuiet()));
  }

  Future<void> _onQuiet() async {
    if (!_started) return;
    if (_governor.mode == TrackingMode.moving) {
      if (_governor.onQuiet(_now())) await _reconfigure();
      _armWatchdog();
      return;
    }
    try {
      final p = await _currentPosition(
        locationSettingsFor(_governor.mode, _platform),
      );
      await _onPosition(p);
    } catch (e) {
      onProblem?.call(e);
      _armWatchdog();
    }
  }
}
