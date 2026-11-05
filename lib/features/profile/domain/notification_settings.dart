class NotificationSettings {
  const NotificationSettings({
    this.arriveLeave = true,
    this.checkin = true,
    this.memberChanges = true,
  });

  final bool arriveLeave;
  final bool checkin;
  final bool memberChanges;

  NotificationSettings copyWith({
    bool? arriveLeave,
    bool? checkin,
    bool? memberChanges,
  }) => NotificationSettings(
    arriveLeave: arriveLeave ?? this.arriveLeave,
    checkin: checkin ?? this.checkin,
    memberChanges: memberChanges ?? this.memberChanges,
  );
}

enum NotificationSettingsFailureKind { network, unauthenticated, unknown }

/// Galat pengaturan notifikasi yang sudah dipetakan, tanpa detail teknis.
class NotificationSettingsFailure implements Exception {
  const NotificationSettingsFailure(this.kind);

  final NotificationSettingsFailureKind kind;

  @override
  String toString() => 'NotificationSettingsFailure($kind)';
}

abstract interface class NotificationSettingsRepository {
  /// Baris milik pengguna yang sedang masuk. Baris dibuat trigger profil,
  /// jadi praktisnya selalu ada; bila belum ada, nilai bawaan (semua nyala).
  Future<NotificationSettings> fetch();

  /// Simpan nilai sakelar milik pengguna. Melempar
  /// [NotificationSettingsFailure].
  Future<void> save(NotificationSettings settings);
}
