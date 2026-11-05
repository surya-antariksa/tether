import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../location_tracking/data/drift_point_queue.dart';
import '../../location_tracking/data/location_api.dart';
import '../../location_tracking/data/location_database.dart';
import '../../location_tracking/data/point_queue.dart';
import '../../location_tracking/domain/location_point.dart';
import '../../location_tracking/domain/location_source.dart';
import '../domain/permission_gateway.dart';
import '../domain/tracking_platform.dart';
import 'geolocator_location_source.dart';
import 'looping_simulated_source.dart';
import 'permission_gateways.dart';

/// Override di tes untuk memaksa platform.
final trackingPlatformProvider = Provider<TrackingPlatform>(
  (ref) => currentTrackingPlatform(),
);

/// Override di tes dengan fake.
final permissionGatewayProvider = Provider<PermissionGateway>(
  (ref) => ref.watch(trackingPlatformProvider) == TrackingPlatform.desktop
      ? const DesktopPermissionGateway()
      : const PermissionHandlerGateway(),
);

/// True hanya di build debug atau dengan --dart-define=SIMULATE_LOCATION=true.
final simulationAllowedProvider = Provider<bool>(
  (ref) => simulationAllowedByBuild,
);

/// Simulasi sedang dihidupkan pengguna. Awalnya aktif bila flag
/// SIMULATE_LOCATION diberikan; tanpa izin build, selalu mati.
class SimulationActive extends Notifier<bool> {
  @override
  bool build() => ref.watch(simulationAllowedProvider) && simulateLocationFlag;

  void start() => state = ref.read(simulationAllowedProvider);

  void stop() => state = false;
}

final simulationActiveProvider = NotifierProvider<SimulationActive, bool>(
  SimulationActive.new,
);

final locationSourceKindProvider = Provider<LocationSourceKind>(
  (ref) => chooseLocationSourceKind(
    platform: ref.watch(trackingPlatformProvider),
    simulationAllowed: ref.watch(simulationAllowedProvider),
    simulationActive: ref.watch(simulationActiveProvider),
  ),
);

/// Teks galat sumber lokasi terakhir (tanpa koordinat), null bila sehat.
class SourceProblem extends Notifier<String?> {
  @override
  String? build() => null;

  void report(Object? problem) =>
      state = problem == null ? null : describeSourceError(problem);
}

final sourceProblemProvider = NotifierProvider<SourceProblem, String?>(
  SourceProblem.new,
);

/// Sumber lokasi sesuai [locationSourceKindProvider]. Untuk jenis
/// `unavailable`, sumber kosong (layanan tidak dijalankan).
final locationSourceProvider = Provider<LocationSource>((ref) {
  final kind = ref.watch(locationSourceKindProvider);
  final LocationSource source = switch (kind) {
    LocationSourceKind.geolocator => GeolocatorLocationSource(
      platform: switch (ref.read(trackingPlatformProvider)) {
        TrackingPlatform.android => TargetPlatform.android,
        TrackingPlatform.ios => TargetPlatform.iOS,
        TrackingPlatform.desktop => defaultTargetPlatform,
      },
      onProblem: ref.read(sourceProblemProvider.notifier).report,
    ),
    LocationSourceKind.simulated => LoopingSimulatedSource(),
    LocationSourceKind.unavailable => _NoSource(),
  };
  ref.onDispose(source.stop);
  return source;
});

class _NoSource implements LocationSource {
  @override
  Stream<LocationPoint> get points => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

final locationApiProvider = Provider<LocationApi>(
  (ref) => SupabaseLocationApi(ref.watch(supabaseClientProvider)),
);

/// Antrean titik, dibuka sekali. SQLite lewat drift; bila gagal dibuka, memori.
final pointQueueProvider = FutureProvider<PointQueue>((ref) async {
  try {
    final db = await LocationDatabase.openDefault();
    ref.onDispose(db.close);
    final queue = DriftPointQueue(db);
    await queue.length(); // memaksa berkas terbuka agar galat muncul di sini
    return queue;
  } catch (e) {
    debugPrint(
      '[tracking] antrean SQLite gagal dibuka (${e.runtimeType}), '
      'memakai antrean memori',
    );
    return InMemoryPointQueue();
  }
}, retry: (_, _) => null);

/// Apakah pengguna punya minimal satu keanggotaan Circle (query ringan ke
/// circle_members milik sendiri). Muat ulang dengan `ref.invalidate` setelah
/// membuat, bergabung, atau keluar dari Circle.
final hasCircleMembershipProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return false;
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('circle_members')
      .select('circle_id')
      .eq('user_id', uid)
      .limit(1);
  return rows.isNotEmpty;
}, retry: (_, _) => null);

/// Status izin lokasi saat dipakai. Null = belum diketahui.
class LocationPermissionNotifier extends Notifier<AppPermissionStatus?> {
  @override
  AppPermissionStatus? build() {
    refresh();
    return null;
  }

  PermissionGateway get _gateway => ref.read(permissionGatewayProvider);

  /// Baca ulang status (mis. setelah kembali dari pengaturan sistem).
  Future<void> refresh() async {
    AppPermissionStatus status;
    try {
      status = await _gateway.status(TrackingPermission.locationWhenInUse);
    } catch (_) {
      status = AppPermissionStatus.denied;
    }
    if (ref.mounted) state = status;
  }
}

final locationPermissionProvider =
    NotifierProvider<LocationPermissionNotifier, AppPermissionStatus?>(
      LocationPermissionNotifier.new,
    );
