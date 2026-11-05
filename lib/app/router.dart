import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/activity/activity_routes.dart';
import '../features/activity/presentation/activity_tab_page.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/circle/circle_routes.dart';
import '../features/circle/presentation/circle_tab_page.dart';
import '../features/location_tracking/presentation/spike_page.dart';
import '../features/map/map_routes.dart';
import '../features/map/presentation/map_tab_page.dart';
import '../features/profile/presentation/profile_tab_page.dart';
import '../features/profile/profile_routes.dart';
import '../features/tracking/tracking_routes.dart';
import 'app_shell.dart';
import 'routes.dart';

/// Belum masuk -> /auth; sudah masuk -> /. Halaman dev (/dev/...) hanya ada
/// di mode debug dan tidak dipaksa ke /auth (spike masuk anonim sendiri).
String? authRedirect({required bool signedIn, required String path}) {
  if (kDebugMode && path.startsWith('/dev/')) return null;
  if (path == AppRoutes.auth) return signedIn ? AppRoutes.map : null;
  return signedIn ? null : AppRoutes.auth;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Auth gate memicu evaluasi ulang redirect saat status masuk berubah.
  final refresh = ValueNotifier<int>(0);
  ref.listen(currentUserIdProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.map,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      signedIn: ref.read(currentUserIdProvider) != null,
      path: state.uri.path,
    ),
    routes: [
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthPage()),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.devSpike,
          builder: (_, _) => SpikePage(
            supabaseConfigured: ref.read(appConfigProvider).isConfigured,
          ),
        ),
      ...trackingRoutes,
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (_, _) => const MapTabPage(),
                routes: mapRoutes,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.circle,
                builder: (_, _) => const CircleTabPage(),
                routes: circleRoutes,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activity,
                builder: (_, _) => const ActivityTabPage(),
                routes: activityRoutes,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileTabPage(),
                routes: profileRoutes,
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
