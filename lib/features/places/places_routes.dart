import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'presentation/place_picker_page.dart';
import 'presentation/places_page.dart';

/// Path lengkap rute fitur tempat (anak rute tab Peta).
abstract final class PlacesRoutes {
  static String list(String circleId) => '${AppRoutes.map}places/$circleId';
  static String create(String circleId) => '${list(circleId)}/new';
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
    builder: (_, state) =>
        PlacePickerPage(circleId: state.pathParameters['circleId']!),
  ),
];
