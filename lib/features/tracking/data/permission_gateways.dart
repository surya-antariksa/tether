import 'package:permission_handler/permission_handler.dart' as ph;

import '../domain/permission_gateway.dart';

/// Android dan iOS lewat permission_handler.
///
/// Android 10+: izin "selalu" hanya bisa diminta setelah izin saat dipakai
/// diberikan (dokumentasi permission_handler). Android 11+: sistem membawa
/// pengguna ke layar pengaturan untuk "Izinkan sepanjang waktu".
/// Android 13+: notifikasi butuh izin runtime; di bawahnya otomatis granted.
class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  @override
  Future<AppPermissionStatus> status(TrackingPermission permission) async =>
      _convert(await _map(permission).status);

  @override
  Future<AppPermissionStatus> request(TrackingPermission permission) async =>
      _convert(await _map(permission).request());

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }

  static ph.Permission _map(TrackingPermission p) => switch (p) {
    TrackingPermission.locationWhenInUse => ph.Permission.locationWhenInUse,
    TrackingPermission.locationAlways => ph.Permission.locationAlways,
    TrackingPermission.notification => ph.Permission.notification,
  };

  static AppPermissionStatus _convert(ph.PermissionStatus s) => switch (s) {
    ph.PermissionStatus.granted ||
    ph.PermissionStatus.limited ||
    ph.PermissionStatus.provisional => AppPermissionStatus.granted,
    ph.PermissionStatus.denied => AppPermissionStatus.denied,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => AppPermissionStatus.permanentlyDenied,
  };
}

/// Linux/desktop: tidak ada plugin izin, semuanya dianggap granted dan tidak
/// ada plugin yang dipanggil.
class DesktopPermissionGateway implements PermissionGateway {
  const DesktopPermissionGateway();

  @override
  Future<AppPermissionStatus> status(TrackingPermission permission) async =>
      AppPermissionStatus.granted;

  @override
  Future<AppPermissionStatus> request(TrackingPermission permission) async =>
      AppPermissionStatus.granted;

  @override
  Future<void> openSettings() async {}
}
