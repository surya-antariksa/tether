import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tether/features/activity/data/shared_prefs_read_marker_store.dart';

void main() {
  final t1 = DateTime.utc(2026, 11, 5, 10);
  final t2 = DateTime.utc(2026, 11, 5, 11);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('penanda terpisah per pengguna', () async {
    await SharedPrefsReadMarkerStore('u1').write(t1);
    expect(await SharedPrefsReadMarkerStore('u1').read(), t1);
    expect(await SharedPrefsReadMarkerStore('u2').read(), isNull);
    await SharedPrefsReadMarkerStore('u2').write(t2);
    expect(await SharedPrefsReadMarkerStore('u1').read(), t1);
    expect(await SharedPrefsReadMarkerStore('u2').read(), t2);
  });

  test('kunci memuat id pengguna', () async {
    await SharedPrefsReadMarkerStore('u1').write(t1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {SharedPrefsReadMarkerStore.keyFor('u1')});
    expect(SharedPrefsReadMarkerStore.keyFor('u1'), contains('u1'));
  });

  test('tanpa pengguna: tidak membaca dan tidak menulis', () async {
    final store = SharedPrefsReadMarkerStore(null);
    await store.write(t1);
    expect(await store.read(), isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
