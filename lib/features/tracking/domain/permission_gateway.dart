/// Izin yang dibutuhkan pelacakan (F13).
enum TrackingPermission { locationWhenInUse, locationAlways, notification }

/// Hasil izin yang disederhanakan. Di Android, ditolak permanen hanya muncul
/// sebagai hasil request (permission_handler tidak bisa membedakannya lewat
/// status biasa).
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied;

  bool get isGranted => this == AppPermissionStatus.granted;
}

/// Pembungkus izin sistem supaya alur onboarding teruji dengan fake.
abstract class PermissionGateway {
  Future<AppPermissionStatus> status(TrackingPermission permission);

  /// Menampilkan dialog sistem bila perlu dan mengembalikan hasilnya.
  Future<AppPermissionStatus> request(TrackingPermission permission);

  /// Membuka layar pengaturan aplikasi di sistem.
  Future<void> openSettings();
}
