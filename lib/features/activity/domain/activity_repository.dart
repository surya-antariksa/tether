import 'activity_event.dart';

enum ActivityFailureKind { network, unauthenticated, unknown }

/// Galat tab Aktivitas yang sudah dipetakan, tanpa detail teknis.
class ActivityFailure implements Exception {
  const ActivityFailure(this.kind);

  final ActivityFailureKind kind;

  @override
  String toString() => 'ActivityFailure($kind)';
}

/// Kejadian realtime yang sudah dinormalisasi.
sealed class ActivityRealtime {
  const ActivityRealtime();
}

/// INSERT pada events yang terlihat oleh pengguna (RLS).
class EventInserted extends ActivityRealtime {
  const EventInserted(this.event);

  final ActivityEvent event;
}

class ActivityConnectionChanged extends ActivityRealtime {
  const ActivityConnectionChanged({required this.connected});

  final bool connected;
}

abstract interface class ActivityRepository {
  /// Event Circle, terbaru dulu. [before] membatasi ke event yang lebih lama
  /// dari waktu itu (paginasi). Melempar [ActivityFailure].
  Future<List<ActivityEvent>> fetchEvents(
    String circleId, {
    DateTime? before,
    int limit = 30,
  });

  /// Nama anggota saat ini (id pengguna ke nama tampilan).
  Future<Map<String, String>> fetchMemberNames(String circleId);

  /// Nama Circle, null bila tidak ditemukan.
  Future<String?> fetchCircleName(String circleId);

  /// Id event orang lain setelah [since] di semua Circle pengguna, paling
  /// banyak [cap].
  Future<List<String>> fetchEventIdsSince(
    DateTime since, {
    required String excludeUserId,
    int cap = 100,
  });

  /// INSERT events baru. Tanpa [circleId]: semua Circle pengguna (RLS).
  /// Berhenti saat langganan stream dibatalkan.
  Stream<ActivityRealtime> realtimeEvents({String? circleId});
}
