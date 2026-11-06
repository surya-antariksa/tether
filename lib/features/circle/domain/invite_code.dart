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

  /// Tautan yang dikodekan di QR dan bisa dibuka sebagai deep link:
  /// `tether://join?code=ABC234`.
  static String link(String code) => Uri(
    scheme: 'tether',
    host: 'join',
    queryParameters: {'code': code},
  ).toString();

  /// Membaca isi QR atau tempelan: tautan Tether atau kode polos. Null bila
  /// tidak memuat kode 6 karakter yang valid.
  static String? fromScan(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    final candidate =
        (uri != null && uri.scheme == 'tether' && uri.host == 'join')
        ? uri.queryParameters['code'] ?? ''
        : text;
    // Ketat: setelah buang spasi, harus tepat 6 karakter alfabet kode. Teks
    // lain (mis. tautan situs) tidak boleh "dipungut" hurufnya.
    final code = candidate.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final ok = code.length == length && code.split('').every(alphabet.contains);
    return ok ? code : null;
  }
}
