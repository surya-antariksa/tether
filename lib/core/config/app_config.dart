import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Konfigurasi dari --dart-define atau --dart-define-from-file=.env.
/// Tidak pernah disimpan di repo.
/// Contoh:
///   flutter run -d linux --dart-define-from-file=.env
///   atau: flutter run -d linux --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class AppConfig {
  const AppConfig({this.supabaseUrl = '', this.supabaseAnonKey = ''});

  const AppConfig.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL'),
      ),
      supabaseAnonKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: String.fromEnvironment(
          'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
          defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
        ),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);
