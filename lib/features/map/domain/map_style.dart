/// Tipe peta yang bisa dipilih pengguna.
///
/// [auto] mengikuti mode sistem (terang = standar, gelap = gelap). Semua tipe
/// bersumber dari OpenStreetMap atau turunannya, jadi atribusinya tertera.
enum MapStyle {
  auto('auto'),
  standard('standard'),
  dark('dark'),
  topo('topo');

  const MapStyle(this.wire);

  /// Nilai yang disimpan di perangkat.
  final String wire;

  static MapStyle fromWire(String? v) =>
      MapStyle.values.where((s) => s.wire == v).firstOrNull ?? MapStyle.auto;
}
