import 'package:go_router/go_router.dart';

import '../history/presentation/history_page.dart';
import 'presentation/delete_account_page.dart';
import 'presentation/notification_settings_page.dart';

/// Path relatif anak rute tab Profil (menjadi '/profile/history' dst.).
abstract final class ProfileRoutes {
  static const history = 'history';
  static const notifications = 'notifications';
  static const deleteAccount = 'delete-account';
}

/// Rute tambahan fitur profile (anak rute tab Profil, path relatif).
/// Isi daftar ini tanpa menyentuh lib/app/router.dart.
final List<RouteBase> profileRoutes = [
  GoRoute(path: ProfileRoutes.history, builder: (_, _) => const HistoryPage()),
  GoRoute(
    path: ProfileRoutes.notifications,
    builder: (_, _) => const NotificationSettingsPage(),
  ),
  GoRoute(
    path: ProfileRoutes.deleteAccount,
    builder: (_, _) => const DeleteAccountPage(),
  ),
];
