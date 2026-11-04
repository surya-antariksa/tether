/// Teks UI tingkat aplikasi (bahasa Indonesia): tab bar dan halaman konfigurasi.
abstract final class AppStrings {
  static const appName = 'Tether';

  static const tabMap = 'Peta';
  static const tabCircle = 'Circle';
  static const tabActivity = 'Aktivitas';
  static const tabProfile = 'Profil';

  static const configMissingTitle = 'Konfigurasi belum lengkap';
  static const configMissingBody =
      'Aplikasi butuh alamat dan kunci publik Supabase. Jalankan ulang dengan '
      'dua nilai berikut lewat --dart-define.';
  static const configMissingExample =
      'flutter run -d linux \\\n'
      '  --dart-define=SUPABASE_URL=<alamat proyek> \\\n'
      '  --dart-define=SUPABASE_ANON_KEY=<kunci publik>';
  static const configMissingHint =
      'Untuk Supabase lokal, ambil nilainya dari `supabase status`. '
      'Jangan menyimpan kunci di repo.';
}
