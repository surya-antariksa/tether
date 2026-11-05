import 'circle.dart';

export 'circle_error.dart';

/// Semua metode melempar CircleError bila gagal.
abstract interface class CircleRepository {
  /// Circle milik pengguna, yang paling lama dibuat lebih dulu.
  Future<List<Circle>> myCircles();

  /// Anggota satu Circle, yang paling lama bergabung lebih dulu.
  Future<List<CircleMember>> members(String circleId);

  /// Membuat Circle (nama 1..40 karakter); pembuat menjadi admin. Mengembalikan id.
  Future<String> createCircle(String name);

  /// Admin saja. Mencabut undangan aktif sebelumnya.
  Future<CircleInvite> createInvite(String circleId);

  /// Null bila kode tidak valid (penyebab tidak dibedakan).
  Future<InvitePreview?> previewInvite(String code);

  /// Id Circle, atau null bila kode tidak valid (penyebab tidak dibedakan).
  Future<String?> joinCircle(String code);

  Future<void> leaveCircle(String circleId);

  /// Admin saja, tidak untuk diri sendiri.
  Future<void> removeMember(String circleId, String userId);

  /// Sakelar berbagi jangka panjang milik sendiri untuk Circle ini.
  Future<void> setSharingEnabled(String circleId, bool enabled);

  /// Emit tiap ada perubahan keanggotaan atau jeda di Circle ini (dari tabel
  /// events), sebagai isyarat untuk mengambil ulang [members].
  Stream<void> memberChanges(String circleId);
}
