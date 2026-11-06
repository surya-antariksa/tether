import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tether/features/map/data/shared_tile_provider.dart';

class _TrackingClient extends MockClient {
  _TrackingClient() : super((_) async => http.Response('', 200));

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test(
    'dispose (dipanggil TileLayer saat dilepas) tidak menutup klien HTTP',
    () async {
      final client = _TrackingClient();
      final provider = SharedNetworkTileProvider(client);

      // Simulasi ganti tipe peta berulang kali: TileLayer lama dilepas.
      await provider.dispose();
      await provider.dispose();
      expect(client.closed, isFalse);

      provider.close();
      expect(client.closed, isTrue);
    },
  );
}
