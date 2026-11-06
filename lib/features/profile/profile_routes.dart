import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../history/domain/history_point.dart';
import '../history/presentation/history_page.dart';
import '../history/presentation/point_detail_page.dart';
import '../history/presentation/route_compare_page.dart';
import '../history/presentation/route_playback_page.dart';
import 'presentation/delete_account_page.dart';
import 'presentation/notification_settings_page.dart';

/// Path relatif anak rute tab Profil (menjadi '/profile/history' dst.).
abstract final class ProfileRoutes {
  static const history = 'history';
  static const notifications = 'notifications';
  static const deleteAccount = 'delete-account';
  static const playback = 'history/playback';
  static const pointDetail = 'history/point';
  static const compare = 'history/compare';

  /// Path lengkap (dipakai context.push dengan `extra`).
  static String get playbackPath => '${AppRoutes.profile}/$playback';
  static String get pointDetailPath => '${AppRoutes.profile}/$pointDetail';
  static String get comparePath => '${AppRoutes.profile}/$compare';
}

/// Rute tambahan fitur profile (anak rute tab Profil, path relatif).
/// Isi daftar ini tanpa menyentuh lib/app/router.dart.
/// Argumen rute detail titik (lewat `extra`).
class PointDetailArgs {
  const PointDetailArgs(this.point, this.previous);

  final HistoryPoint point;
  final HistoryPoint? previous;
}

final List<RouteBase> profileRoutes = [
  GoRoute(path: ProfileRoutes.history, builder: (_, _) => const HistoryPage()),
  GoRoute(
    path: ProfileRoutes.playback,
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => RoutePlaybackPage(
      points: (state.extra as List<HistoryPoint>?) ?? const [],
    ),
  ),
  GoRoute(
    path: ProfileRoutes.pointDetail,
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) {
      final args = state.extra as PointDetailArgs;
      return PointDetailPage(point: args.point, previous: args.previous);
    },
  ),
  GoRoute(
    path: ProfileRoutes.compare,
    parentNavigatorKey: rootNavigatorKey,
    builder: (_, state) => RouteComparePage(
      points: (state.extra as List<HistoryPoint>?) ?? const [],
    ),
  ),
  GoRoute(
    path: ProfileRoutes.notifications,
    builder: (_, _) => const NotificationSettingsPage(),
  ),
  GoRoute(
    path: ProfileRoutes.deleteAccount,
    builder: (_, _) => const DeleteAccountPage(),
  ),
];
