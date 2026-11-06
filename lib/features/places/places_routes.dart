import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import 'presentation/place_picker_page.dart';
import 'presentation/places_page.dart';

/// Path lengkap rute fitur tempat (anak rute tab Peta).
abstract final class PlacesRoutes {
  static String list(String circleId) => '${AppRoutes.map}places/$circleId';
  static String create(
    String circleId, {
    double? lat,
    double? lng,
    String? name,
  }) {
    final q = <String, String>{
      'lat': ?lat?.toString(),
      'lng': ?lng?.toString(),
      'name': ?name,
    };
    return Uri(
      path: '${list(circleId)}/new',
      queryParameters: q.isEmpty ? null : q,
    ).toString();
  }
}

/// Rute tempat (path relatif di bawah tab Peta), tampil penuh di atas tab bar.
/// Dipasang lewat `mapRoutes` (lib/features/map/map_routes.dart).
final List<RouteBase> placesRoutes = [
  GoRoute(
    path: 'places/:circleId',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) =>
        PlacesPage(circleId: state.pathParameters['circleId']!),
  ),
  GoRoute(
    path: 'places/:circleId/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) {
      final q = state.uri.queryParameters;
      final lat = double.tryParse(q['lat'] ?? '');
      final lng = double.tryParse(q['lng'] ?? '');
      return PlacePickerPage(
        circleId: state.pathParameters['circleId']!,
        initialCenter: lat == null || lng == null ? null : LatLng(lat, lng),
        initialName: q['name'],
      );
    },
  ),
];
