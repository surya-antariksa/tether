import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'presentation/location_onboarding_page.dart';

/// Rute onboarding izin lokasi (F13).
const String locationOnboardingPath = '/onboarding/location';

/// Rute tingkat atas (bukan anak tab), tampil di atas tab bar.
final List<RouteBase> trackingRoutes = [
  GoRoute(
    path: locationOnboardingPath,
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, _) => const LocationOnboardingPage(),
  ),
];
