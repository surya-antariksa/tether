import 'package:shared_preferences/shared_preferences.dart';

import '../domain/read_marker_store.dart';

/// Penanda "terakhir dibaca" di penyimpanan lokal perangkat, terpisah per
/// pengguna (perangkat bersama: penanda akun lain tidak boleh ikut terbawa).
/// Tanpa pengguna, tidak membaca dan tidak menulis.
class SharedPrefsReadMarkerStore implements ReadMarkerStore {
  SharedPrefsReadMarkerStore(this.userId);

  final String? userId;

  static String keyFor(String userId) => 'activity_last_read_at_$userId';

  @override
  Future<DateTime?> read() async {
    final uid = userId;
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(uid));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> write(DateTime time) async {
    final uid = userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(uid), time.toUtc().toIso8601String());
  }
}
