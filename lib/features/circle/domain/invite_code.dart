/// Kode undangan: 6 karakter dari alfabet tanpa karakter ambigu (0, O, 1, I, L).
abstract final class InviteCode {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 6;

  /// Huruf besar, buang spasi dan karakter di luar alfabet, potong ke 6.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final ch in raw.toUpperCase().split('')) {
      if (alphabet.contains(ch)) buffer.write(ch);
    }
    final s = buffer.toString();
    return s.length > length ? s.substring(0, length) : s;
  }

  static bool isComplete(String normalized) => normalized.length == length;
}
