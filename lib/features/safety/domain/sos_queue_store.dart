import 'sos_models.dart';

/// Penyimpanan persisten antrean SOS (bertahan walau aplikasi ditutup).
abstract class SosQueueStore {
  /// Semua SOS tertunda, urut menurut triggeredAt naik.
  Future<List<PendingSos>> load();

  /// Menyimpan (mengganti bila clientId sudah ada).
  Future<void> add(PendingSos sos);

  /// Menghapus; clientId yang tidak ada diabaikan.
  Future<void> remove(String clientId);

  /// Menghapus semua SOS milik [userId] (mis. saat akun dihapus: koordinatnya
  /// tidak boleh tertinggal di perangkat).
  Future<void> removeForUser(String userId);
}

class InMemorySosQueueStore implements SosQueueStore {
  final Map<String, PendingSos> _items = {};

  @override
  Future<List<PendingSos>> load() async =>
      _items.values.toList()
        ..sort((a, b) => a.triggeredAt.compareTo(b.triggeredAt));

  @override
  Future<void> add(PendingSos sos) async => _items[sos.clientId] = sos;

  @override
  Future<void> remove(String clientId) async => _items.remove(clientId);

  @override
  Future<void> removeForUser(String userId) async =>
      _items.removeWhere((_, s) => s.userId == userId);
}
