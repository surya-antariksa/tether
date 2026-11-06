import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Penyedia ubin jaringan yang DIPAKAI BERSAMA seluruh peta.
///
/// `TileLayer` memanggil `tileProvider.dispose()` tiap kali ia dilepas (ganti
/// tipe peta, pindah halaman, ganti tema). `NetworkTileProvider` bawaan lalu
/// menutup klien HTTP-nya, padahal objeknya dipakai peta lain: ubin berikutnya
/// gagal dimuat dan peta tampak kosong atau ubin hilang saat zoom. Di sini
/// `dispose()` tidak menutup apa pun; klien baru ditutup lewat [close] saat
/// aplikasi berakhir.
class SharedNetworkTileProvider extends NetworkTileProvider {
  SharedNetworkTileProvider._(this._client) : super(httpClient: _client);

  factory SharedNetworkTileProvider([http.Client? client]) =>
      SharedNetworkTileProvider._(client ?? RetryClient(http.Client()));

  final http.Client _client;

  @override
  Future<void> dispose() async {
    // Sengaja kosong: lihat dokumentasi kelas.
  }

  /// Menutup klien HTTP; hanya dipanggil saat provider Riverpod dibuang.
  void close() => _client.close();
}
