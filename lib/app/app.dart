import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_strings.dart';
import 'config_missing_page.dart';
import 'router.dart';
import 'theme/app_theme.dart';

// Teks bawaan framework (salin, tempel, dialog) dalam bahasa Indonesia.
const _locale = Locale('id');
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

class TetherApp extends ConsumerWidget {
  const TetherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoApp.router(
      title: AppStrings.appName,
      theme: appTheme,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: _localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Dipakai main.dart saat SUPABASE_URL atau SUPABASE_ANON_KEY kosong.
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: AppStrings.appName,
      theme: appTheme,
      locale: _locale,
      supportedLocales: [_locale],
      localizationsDelegates: _localizationsDelegates,
      home: ConfigMissingPage(),
    );
  }
}
