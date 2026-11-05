import 'package:go_router/go_router.dart';

import '../places/places_routes.dart';

/// Rute tambahan fitur map (anak rute tab Peta, path relatif).
/// Isi daftar ini tanpa menyentuh lib/app/router.dart.
final List<RouteBase> mapRoutes = [...placesRoutes];
