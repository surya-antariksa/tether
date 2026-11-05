import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sos_models.dart';
import '../domain/sos_queue_store.dart';

/// Antrean SOS persisten sebagai satu berkas JSON kecil (antrean paling banyak
/// beberapa entri, jadi SQLite tidak perlu). Penulisan atomik (tulis ke berkas
/// sementara lalu rename) dan diserialkan. Berkas yang tidak terbaca tidak
/// pernah ditimpa: dipindah ke `.corrupt` (lalu antrean dianggap kosong); bila
/// pemindahan gagal, galat diteruskan sehingga add gagal dan berkas utuh.
/// Berisi koordinat; entri dihapus begitu terkirim, ditolak, atau kedaluwarsa.
class FileSosQueueStore implements SosQueueStore {
  FileSosQueueStore(this._file);

  /// Berkas di direktori data aplikasi (sama dengan antrean titik lokasi).
  static Future<FileSosQueueStore> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    return FileSosQueueStore(File(p.join(dir.path, 'tether_sos_queue.json')));
  }

  final File _file;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final r = _tail.then((_) => op());
    _tail = r.then((_) {}, onError: (Object _) {});
    return r;
  }

  Future<Map<String, PendingSos>> _read() async {
    try {
      if (!await _file.exists()) return {};
      final raw = jsonDecode(await _file.readAsString());
      if (raw is! List) throw const FormatException('bukan daftar');
      final out = <String, PendingSos>{};
      for (final e in raw) {
        try {
          final s = PendingSos.fromJson(Map<String, dynamic>.from(e as Map));
          out[s.clientId] = s;
        } catch (_) {
          // entri rusak dilewati
        }
      }
      return out;
    } catch (_) {
      // Jangan biarkan add menimpa berkas yang tidak terbaca (entri lain bisa
      // hilang): amankan dulu. Gagal mengamankan = lempar ulang.
      await _file.rename('${_file.path}.corrupt');
      return {};
    }
  }

  Future<void> _write(Map<String, PendingSos> items) async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode([for (final s in items.values) s.toJson()]),
      flush: true,
    );
    await tmp.rename(_file.path);
  }

  @override
  Future<List<PendingSos>> load() => _serial(() async {
    return (await _read()).values.toList()
      ..sort((a, b) => a.triggeredAt.compareTo(b.triggeredAt));
  });

  @override
  Future<void> add(PendingSos sos) => _serial(() async {
    final items = await _read();
    items[sos.clientId] = sos;
    await _write(items);
  });

  @override
  Future<void> remove(String clientId) => _serial(() async {
    final items = await _read();
    if (items.remove(clientId) != null) await _write(items);
  });

  @override
  Future<void> removeForUser(String userId) => _serial(() async {
    final items = await _read();
    final before = items.length;
    items.removeWhere((_, s) => s.userId == userId);
    if (items.length != before) await _write(items);
  });
}
