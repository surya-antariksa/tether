import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/app.dart';
import 'package:tether/app/config_missing_page.dart';
import 'package:tether/core/config/app_config.dart';

void main() {
  test('isConfigured hanya bila URL dan kunci keduanya terisi', () {
    expect(const AppConfig().isConfigured, isFalse);
    expect(const AppConfig(supabaseUrl: 'http://x').isConfigured, isFalse);
    expect(const AppConfig(supabaseAnonKey: 'k').isConfigured, isFalse);
    expect(
      const AppConfig(
        supabaseUrl: 'http://x',
        supabaseAnonKey: 'k',
      ).isConfigured,
      isTrue,
    );
  });

  test('tanpa --dart-define konfigurasi bawaan kosong', () {
    expect(const AppConfig.fromEnvironment().isConfigured, isFalse);
    expect(const AppConfig.fromEnvironment().supabaseUrl, isEmpty);
    expect(const AppConfig.fromEnvironment().supabaseAnonKey, isEmpty);
  });

  testWidgets('ConfigMissingApp menampilkan penjelasan tanpa crash', (
    tester,
  ) async {
    await tester.pumpWidget(const ConfigMissingApp());
    expect(find.byType(ConfigMissingPage), findsOneWidget);
    expect(find.text('Konfigurasi belum lengkap'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
