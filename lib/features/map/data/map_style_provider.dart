import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/map_style.dart';

const _prefsKey = 'map_style';

/// Tipe peta pilihan pengguna, disimpan di perangkat. Gagal membaca atau
/// menulis penyimpanan tidak mengganggu peta (tetap memakai pilihan di memori).
class MapStyleNotifier extends Notifier<MapStyle> {
  @override
  MapStyle build() {
    _load();
    return MapStyle.auto;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = MapStyle.fromWire(prefs.getString(_prefsKey));
      if (ref.mounted && saved != state) state = saved;
    } catch (_) {}
  }

  Future<void> select(MapStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, style.wire);
    } catch (_) {}
  }
}

final mapStyleProvider = NotifierProvider<MapStyleNotifier, MapStyle>(
  MapStyleNotifier.new,
);
