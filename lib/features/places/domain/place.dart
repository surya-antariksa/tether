import 'package:latlong2/latlong.dart';

/// Batas tempat (PRD F7, sama dengan constraint dan RPC di database).
abstract final class PlaceLimits {
  static const maxPerCircle = 5;
  static const nameMaxLength = 40;
  static const minRadiusM = 100;
  static const maxRadiusM = 5000;
  static const radiusStepM = 50;
  static const defaultRadiusM = 200;
}

/// Tempat (geofence lingkaran) milik satu Circle.
class Place {
  const Place({
    required this.id,
    required this.circleId,
    required this.name,
    required this.center,
    required this.radiusM,
    this.createdBy,
  });

  final String id;
  final String circleId;
  final String name;
  final LatLng center;
  final int radiusM;

  /// Null bila pembuatnya sudah menghapus akun.
  final String? createdBy;

  /// Pembuat atau admin Circle boleh mengubah dan menghapus (aturan RPC).
  bool canManage({required String? userId, required bool isAdmin}) =>
      isAdmin || (userId != null && createdBy == userId);
}

/// Kesalahan validasi nama menurut aturan RPC (1 sampai 40 karakter setelah
/// dipangkas). Dihitung per code point, sama dengan `char_length` di database.
enum PlaceNameIssue { empty, tooLong }

PlaceNameIssue? validatePlaceName(String raw) {
  final length = raw.trim().runes.length;
  if (length == 0) return PlaceNameIssue.empty;
  if (length > PlaceLimits.nameMaxLength) return PlaceNameIssue.tooLong;
  return null;
}

/// Radius ditampilkan dalam meter, atau kilometer mulai 1000 m ("1,5 km").
String formatRadius(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  final text = km == km.roundToDouble()
      ? km.toStringAsFixed(0)
      : km.toString().replaceAll('.', ',');
  return '$text km';
}
