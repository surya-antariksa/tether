import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../features/activity/presentation/activity_tab_icon.dart';
import 'app_strings.dart';
import 'theme/app_colors.dart';

/// Kerangka tab bar bawah (Cupertino). Urutan sama dengan cabang di router.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: navigationShell),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _GlassTabBar(navigationShell: navigationShell),
        ),
      ],
    );
  }
}

/// Tab bar kaca: latar gelap berkabut, item aktif aksen tint dengan ikon
/// terisi dan cahaya tipis (hanya di mode gelap).
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final tint = CupertinoDynamicColor.resolve(AppColors.tint, context);
    final inactive = CupertinoDynamicColor.resolve(
      AppColors.textSecondary,
      context,
    ).withValues(alpha: 0.7);
    return CupertinoTabBar(
      currentIndex: navigationShell.currentIndex,
      backgroundColor: CupertinoDynamicColor.resolve(
        AppColors.glassFill,
        context,
      ).withValues(alpha: dark ? 0.85 : 0.92),
      activeColor: tint,
      inactiveColor: inactive,
      iconSize: 24,
      border: Border(
        top: BorderSide(
          color: CupertinoDynamicColor.resolve(AppColors.glassBorder, context),
          width: 0.5,
        ),
      ),
      // Ketuk tab aktif lagi kembali ke halaman awal tab itu.
      onTap: (i) => navigationShell.goBranch(
        i,
        initialLocation: i == navigationShell.currentIndex,
      ),
      items: [
        _item(Symbols.map, AppStrings.tabMap, dark, tint),
        _item(Symbols.group, AppStrings.tabCircle, dark, tint),
        BottomNavigationBarItem(
          icon: const ActivityTabIcon(),
          activeIcon: _glow(const ActivityTabIcon(filled: true), dark, tint),
          label: AppStrings.tabActivity,
        ),
        _item(Symbols.person, AppStrings.tabProfile, dark, tint),
      ],
    );
  }

  static BottomNavigationBarItem _item(
    IconData icon,
    String label,
    bool dark,
    Color tint,
  ) => BottomNavigationBarItem(
    icon: Icon(icon),
    activeIcon: _glow(Icon(icon, fill: 1), dark, tint),
    label: label,
  );

  static Widget _glow(Widget icon, bool dark, Color tint) {
    if (!dark) return icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ],
      ),
      child: icon,
    );
  }
}
