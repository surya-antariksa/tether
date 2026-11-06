import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'presentation/create_circle_page.dart';
import 'presentation/join_circle_page.dart';

/// Path lengkap rute fitur circle (anak rute tab Circle).
abstract final class CircleRoutes {
  static const create = '${AppRoutes.circle}/create';
  static const join = '${AppRoutes.circle}/join';
}

/// Rute tambahan fitur circle (anak rute tab Circle, path relatif), tampil
/// penuh di atas tab bar.
final List<RouteBase> circleRoutes = [
  GoRoute(
    path: 'create',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const CreateCirclePage(),
  ),
  GoRoute(
    path: 'join',
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) =>
        JoinCirclePage(initialCode: state.uri.queryParameters['code']),
  ),
];
