import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Pilihan tampilan: ikut sistem, selalu terang, atau selalu gelap.
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.wire);

  /// Nilai yang disimpan di perangkat.
  final String wire;

  static AppThemeMode fromWire(String? v) =>
      AppThemeMode.values.where((m) => m.wire == v).firstOrNull ??
      AppThemeMode.system;

  /// Tema Cupertino untuk pilihan ini. Sistem = tanpa brightness tetap.
  CupertinoThemeData get theme => switch (this) {
    AppThemeMode.system => appTheme,
    AppThemeMode.light => appTheme.copyWith(brightness: Brightness.light),
    AppThemeMode.dark => appTheme.copyWith(brightness: Brightness.dark),
  };
}

const _prefsKey = 'theme_mode';

/// Pilihan tema pengguna, disimpan di perangkat. Gagal membaca atau menulis
/// penyimpanan tidak mengganggu tampilan (tetap memakai pilihan di memori).
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _load();
    return AppThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = AppThemeMode.fromWire(prefs.getString(_prefsKey));
      if (ref.mounted && saved != state) state = saved;
    } catch (_) {}
  }

  Future<void> select(AppThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.wire);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
