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
    return Stack(
      children: [
        Positioned.fill(
          child: navigationShell,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: CupertinoTabBar(
            currentIndex: navigationShell.currentIndex,
            backgroundColor: CupertinoDynamicColor.resolve(
              CupertinoColors.systemBackground.withValues(alpha: 0.82),
              context,
            ),
            border: Border(
              top: BorderSide(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.separator.withValues(alpha: 0.35),
                  context,
                ),
                width: 0.5,
              ),
            ),
            // Ketuk tab aktif lagi kembali ke halaman awal tab itu.
            onTap: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.map_fill),
                label: AppStrings.tabMap,
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_2_fill),
                label: AppStrings.tabCircle,
              ),
              BottomNavigationBarItem(
                icon: ActivityTabIcon(),
                label: AppStrings.tabActivity,
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_crop_circle_fill),
                label: AppStrings.tabProfile,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
