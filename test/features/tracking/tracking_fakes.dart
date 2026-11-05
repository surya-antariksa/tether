import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tether/features/auth/data/auth_providers.dart';
import 'package:tether/features/location_tracking/data/point_queue.dart';
import 'package:tether/features/location_tracking/domain/location_point.dart';
import 'package:tether/features/location_tracking/domain/location_source.dart';
import 'package:tether/features/tracking/data/tracking_providers.dart';
import 'package:tether/features/tracking/domain/permission_gateway.dart';
import 'package:tether/features/tracking/domain/tracking_platform.dart';

import '../location_tracking/fakes.dart';

export '../location_tracking/fakes.dart' show FakeLocationApi, pointAt;

/// Gateway izin palsu: tidak menyentuh plugin. [request] memperbarui hasil
/// [status] seperti sistem sungguhan.
class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway({
    Map<TrackingPermission, AppPermissionStatus>? statuses,
    Map<TrackingPermission, AppPermissionStatus>? requestResults,
  }) : statuses = {...?statuses},
       requestResults = {...?requestResults};

  /// Status saat ini; yang tidak ada dianggap denied (belum diminta).
  final Map<TrackingPermission, AppPermissionStatus> statuses;

  /// Hasil [request]; yang tidak ada dianggap granted.
  final Map<TrackingPermission, AppPermissionStatus> requestResults;

  final List<TrackingPermission> statusCalls = [];
  final List<TrackingPermission> requestCalls = [];
  int openSettingsCalls = 0;

  /// Bila true, status/request/openSettings melempar.
  bool throwOnStatus = false;
  bool throwOnRequest = false;
  bool throwOnOpenSettings = false;

  /// Bila diisi, request menunggu completer ini.
  Completer<void>? requestGate;

  @override
  Future<AppPermissionStatus> status(TrackingPermission permission) async {
    statusCalls.add(permission);
    if (throwOnStatus) throw StateError('status gagal (uji)');
    return statuses[permission] ?? AppPermissionStatus.denied;
  }

  @override
  Future<AppPermissionStatus> request(TrackingPermission permission) async {
    requestCalls.add(permission);
    await requestGate?.future;
    if (throwOnRequest) throw StateError('request gagal (uji)');
    final result = requestResults[permission] ?? AppPermissionStatus.granted;
    statuses[permission] = result;
    return result;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
    if (throwOnOpenSettings) throw StateError('openSettings gagal (uji)');
  }
}

/// Sumber lokasi palsu yang bisa dipaksa mengeluarkan titik.
class FakeLocationSource implements LocationSource {
  final _controller = StreamController<LocationPoint>.broadcast();
  int starts = 0;
  int stops = 0;

  /// Bila diisi, start melempar ini.
  Object? startError;

  @override
  Stream<LocationPoint> get points => _controller.stream;

  @override
  Future<void> start() async {
    starts++;
    final e = startError;
    if (e != null) throw e;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  void emit(LocationPoint point) => _controller.add(point);
}

/// Id pengguna yang bisa diganti dari tes (menggantikan aliran auth).
class FakeUserId extends CurrentUserIdNotifier {
  FakeUserId(this.initial);

  final String? initial;

  @override
  String? build() => initial;

  void set(String? id) => state = id;
}

/// Semua pihak palsu untuk layanan pelacakan, plus daftar override-nya.
class TrackingHarness {
  TrackingHarness({
    this.userId = 'user-1',
    this.hasCircle = true,
    this.platform = TrackingPlatform.android,
    this.simulationAllowed = false,
    FakePermissionGateway? gateway,
    FakeLocationSource? source,
    FakeLocationApi? api,
    InMemoryPointQueue? queue,
  }) : gateway =
           gateway ??
           FakePermissionGateway(
             statuses: {
               TrackingPermission.locationWhenInUse:
                   AppPermissionStatus.granted,
             },
           ),
       source = source ?? FakeLocationSource(),
       api = api ?? FakeLocationApi(),
       queue = queue ?? InMemoryPointQueue();

  final String? userId;
  final TrackingPlatform platform;
  final bool simulationAllowed;
  final FakePermissionGateway gateway;
  final FakeLocationSource source;
  final FakeLocationApi api;
  final InMemoryPointQueue queue;

  /// Hasil query keanggotaan Circle; bisa diubah sebelum provider dimuat ulang.
  bool hasCircle;

  /// Bila diisi, query keanggotaan melempar ini.
  Object? circleError;

  /// Berapa kali query keanggotaan dijalankan.
  int circleChecks = 0;

  List<Override> get overrides => [
    trackingPlatformProvider.overrideWithValue(platform),
    simulationAllowedProvider.overrideWithValue(simulationAllowed),
    permissionGatewayProvider.overrideWithValue(gateway),
    currentUserIdProvider.overrideWith(() => FakeUserId(userId)),
    hasCircleMembershipProvider.overrideWith((ref) async {
      circleChecks++;
      final e = circleError;
      if (e != null) throw e;
      return hasCircle;
    }),
    pointQueueProvider.overrideWith((ref) async => queue),
    locationApiProvider.overrideWithValue(api),
    locationSourceProvider.overrideWithValue(source),
  ];
}
