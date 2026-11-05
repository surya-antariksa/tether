/// Penyimpanan lokal penanda "terakhir dibaca" untuk lencana Aktivitas.
abstract interface class ReadMarkerStore {
  /// Waktu terakhir tab Aktivitas dibuka. Null bila belum pernah.
  Future<DateTime?> read();

  Future<void> write(DateTime time);
}
