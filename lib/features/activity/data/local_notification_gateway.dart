import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_gateway.dart';

/// Notifikasi lokal lewat flutter_local_notifications (Android, Linux, iOS,
/// macOS). Bila plugin tidak tersedia (web, tes, platform lain) semua metode
/// diam tanpa galat.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const activityChannelId = 'tether_activity';
  static const sosChannelId = 'tether_sos';

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<bool>? _init;

  static bool get _platformSupported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.linux ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> initialize() async {
    await (_init ??= _doInitialize());
  }

  Future<bool> _doInitialize() async {
    if (!_platformSupported) return false;
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: 'Buka'),
          // Izin diminta lewat requestPermission, bukan saat inisialisasi.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null && !_taps.isClosed) _taps.add(payload);
        },
      );
      return ok ?? true;
    } catch (_) {
      // MissingPluginException, DBus tidak ada, dan sebagainya.
      return false;
    }
  }

  Future<bool> get _ready async => await (_init ??= _doInitialize());

  @override
  Future<bool> requestPermission() async {
    if (!await _ready) return false;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission() ??
              false;
        case TargetPlatform.iOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
        case TargetPlatform.macOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
        default:
          return true; // Linux: tidak ada izin runtime.
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show(LocalNotification n) async {
    if (!await _ready) return;
    final high = n.urgency == NotificationUrgency.high;
    try {
      await _plugin.show(
        id: n.id,
        title: n.title,
        body: n.body,
        payload: n.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            high ? sosChannelId : activityChannelId,
            high ? 'SOS' : 'Aktivitas Circle',
            channelDescription: high
                ? 'Peringatan SOS dari anggota Circle'
                : 'Tiba, pergi, dan perubahan anggota Circle',
            importance: high ? Importance.max : Importance.defaultImportance,
            priority: high ? Priority.high : Priority.defaultPriority,
            category: high ? AndroidNotificationCategory.alarm : null,
            visibility: NotificationVisibility.private,
          ),
          linux: LinuxNotificationDetails(
            urgency: high
                ? LinuxNotificationUrgency.critical
                : LinuxNotificationUrgency.normal,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: high
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
          macOS: DarwinNotificationDetails(
            interruptionLevel: high
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
        ),
      );
    } catch (_) {
      // Notifikasi gagal tidak boleh mengganggu aplikasi.
    }
  }
}
