import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/presentation/activity_tab_icon.dart';
import 'app_strings.dart';

/// Kerangka tab bar bawah (Cupertino). Urutan sama dengan cabang di router.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: navigationShell),
        CupertinoTabBar(
          currentIndex: navigationShell.currentIndex,
          // Ketuk tab aktif lagi kembali ke halaman awal tab itu.
          onTap: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.map_fill),
              label: AppStrings.tabMap,
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_2_fill),
              label: AppStrings.tabCircle,
            ),
            const BottomNavigationBarItem(
              icon: ActivityTabIcon(),
              label: AppStrings.tabActivity,
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_crop_circle_fill),
              label: AppStrings.tabProfile,
            ),
          ],
        ),
      ],
    );
  }
}
