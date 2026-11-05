import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tether/features/safety/data/file_sos_queue_store.dart';
import 'package:tether/features/safety/domain/sos_models.dart';

import 'safety_fakes.dart';

PendingSos sos(String id, int minute) => PendingSos(
  clientId: id,
  userId: 'u1',
  triggeredAt: DateTime.utc(2026, 11, 5, 10, minute),
  fix: jakarta,
);

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tether_sos_q');
    file = File(p.join(dir.path, 'q.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('kosong bila berkas belum ada', () async {
    expect(await FileSosQueueStore(file).load(), isEmpty);
  });

  test(
    'tersimpan lintas instance (aplikasi ditutup dan dibuka lagi)',
    () async {
      await FileSosQueueStore(file).add(sos('b', 2));
      await FileSosQueueStore(file).add(sos('a', 1));
      final loaded = await FileSosQueueStore(file).load();
      expect(loaded.map((s) => s.clientId), ['a', 'b']); // urut triggeredAt
      expect(loaded.first.fix.lat, jakarta.lat);
      expect(loaded.first.triggeredAt, DateTime.utc(2026, 11, 5, 10, 1));
    },
  );

  test('add dengan clientId sama mengganti, remove menghapus', () async {
    final store = FileSosQueueStore(file);
    await store.add(sos('a', 1));
    await store.add(sos('a', 1));
    expect(await store.load(), hasLength(1));
    await store.remove('tidak-ada');
    await store.remove('a');
    expect(await store.load(), isEmpty);
  });

  test('berkas rusak dibaca kosong dan bisa ditulis ulang', () async {
    file.writeAsStringSync('{bukan json');
    final store = FileSosQueueStore(file);
    expect(await store.load(), isEmpty);
    await store.add(sos('a', 1));
    expect(await store.load(), hasLength(1));
  });

  test('berkas tak terbaca tidak ditimpa: dipindah ke .corrupt', () async {
    file.writeAsStringSync('{bukan json');
    final store = FileSosQueueStore(file);
    await store.add(sos('a', 1));
    final saved = File('${file.path}.corrupt');
    expect(saved.existsSync(), isTrue);
    expect(saved.readAsStringSync(), '{bukan json');
    expect((await store.load()).map((s) => s.clientId), ['a']);
  });

  test('add gagal (berkas tak bisa diamankan) tidak menimpa berkas', () async {
    // Jalur .corrupt berupa direktori tak kosong: rename berkas gagal.
    file.writeAsStringSync('{bukan json');
    Directory('${file.path}.corrupt/isi').createSync(recursive: true);
    final store = FileSosQueueStore(file);
    await expectLater(store.add(sos('a', 1)), throwsA(anything));
    expect(file.readAsStringSync(), '{bukan json');
  });

  test('removeForUser hanya menghapus entri milik pengguna itu', () async {
    final store = FileSosQueueStore(file);
    await store.add(sos('a', 1));
    await store.add(
      PendingSos(
        clientId: 'b',
        userId: 'u2',
        triggeredAt: DateTime.utc(2026, 11, 5, 10, 2),
        fix: jakarta,
      ),
    );
    await store.removeForUser('u1');
    expect((await store.load()).map((s) => s.clientId), ['b']);
  });

  test('entri rusak dilewati, entri sehat tetap terbaca', () async {
    final store = FileSosQueueStore(file);
    await store.add(sos('a', 1));
    final raw = file.readAsStringSync();
    file.writeAsStringSync('[{"client_id":1},${raw.substring(1)}');
    expect((await store.load()).map((s) => s.clientId), ['a']);
  });

  test('penulisan bersamaan diserialkan tanpa kehilangan entri', () async {
    final store = FileSosQueueStore(file);
    await Future.wait([for (var i = 0; i < 20; i++) store.add(sos('id$i', i))]);
    expect(await store.load(), hasLength(20));
  });
}
