import '../domain/activity_event.dart';

/// Baris events (REST atau payload Realtime) menjadi [ActivityEvent].
/// Null bila baris tidak lengkap atau tipenya tidak ditampilkan.
ActivityEvent? activityEventFromRow(Map<dynamic, dynamic> row) {
  final id = row['id'];
  final circleId = row['circle_id'];
  final userId = row['user_id'];
  final type = ActivityType.parse(row['type']);
  final createdRaw = row['created_at'];
  final createdAt = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
  if (id is! String ||
      circleId is! String ||
      userId is! String ||
      type == null ||
      createdAt == null) {
    return null;
  }
  final payload = row['payload'] is Map
      ? row['payload'] as Map<dynamic, dynamic>
      : const <dynamic, dynamic>{};
  final name = payload['display_name'];
  final place = payload['place_name'];
  final triggered = payload['triggered_at'];
  final lat = payload['lat'];
  final lng = payload['lng'];
  final hasCoords =
      type == ActivityType.sos &&
      lat is num &&
      lng is num &&
      lat.isFinite &&
      lng.isFinite;
  return ActivityEvent(
    id: id,
    circleId: circleId,
    userId: userId,
    type: type,
    createdAt: createdAt,
    displayName: name is String && name.trim().isNotEmpty ? name : null,
    placeName: place is String && place.trim().isNotEmpty ? place : null,
    pausedMinutes: type == ActivityType.paused && payload['minutes'] is num
        ? (payload['minutes'] as num).toInt()
        : null,
    checkinKind: type == ActivityType.checkin
        ? switch (payload['kind']) {
            'arrived' => CheckinKind.arrived,
            'safe' => CheckinKind.safe,
            _ => null,
          }
        : null,
    sharingEnabled:
        type == ActivityType.sharingChanged && payload['enabled'] is bool
        ? payload['enabled'] as bool
        : null,
    clientId: type == ActivityType.sos && payload['client_id'] is String
        ? payload['client_id'] as String
        : null,
    lat: hasCoords ? lat.toDouble() : null,
    lng: hasCoords ? lng.toDouble() : null,
    triggeredAt: type == ActivityType.sos && triggered is String
        ? DateTime.tryParse(triggered)
        : null,
  );
}
