import 'package:flutter/widgets.dart';

/// Jalur rute. Rute tambahan fitur (mapRoutes dst.) menjadi anak rute tab
/// mereka, jadi pakai path relatif tanpa '/' di depan (mis. 'places' menjadi
/// '/places' di bawah tab Peta).
abstract final class AppRoutes {
  static const auth = '/auth';
  static const map = '/';
  static const circle = '/circle';
  static const activity = '/activity';
  static const profile = '/profile';

  /// Hanya terdaftar bila kDebugMode.
  static const devSpike = '/dev/spike';
}

/// Navigator akar. Beri `parentNavigatorKey: rootNavigatorKey` pada rute
/// yang harus tampil penuh di atas tab bar.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
