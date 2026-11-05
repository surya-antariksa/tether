import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/activity/data/local_notification_gateway.dart';
import 'package:tether/features/activity/domain/notification_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Di tes tidak ada plugin platform: semua pemanggilan harus diam, tanpa
  // galat (gateway nyata aman bila plugin tidak tersedia).
  test('inisialisasi, izin, dan tampil aman tanpa plugin', () async {
    final gateway = LocalNotificationGateway();
    await gateway.initialize();
    await gateway.initialize(); // berulang aman
    expect(await gateway.requestPermission(), isFalse);
    await gateway.show(
      const LocalNotification(
        id: 1,
        title: 'Keluarga',
        body: 'Sinta tiba di Rumah',
        payload: 'c1',
      ),
    );
    await gateway.show(
      const LocalNotification(
        id: 2,
        title: 'SOS dari Sinta',
        body: 'x',
        urgency: NotificationUrgency.high,
      ),
    );
  });

  test('taps adalah aliran siaran', () {
    final gateway = LocalNotificationGateway();
    expect(gateway.taps.isBroadcast, isTrue);
  });
}
