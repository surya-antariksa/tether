/// Nilai `circle_members.paused_until`: null (tidak dijeda), waktu tertentu,
/// atau 'infinity' (dijeda sampai dinyalakan lagi). Jeda yang sudah lewat tidak
/// mengubah baris, jadi status dihitung dari [activeAt].
class PausedUntil {
  const PausedUntil._(this.until, this.indefinite);

  static const none = PausedUntil._(null, false);
  static const indefinitely = PausedUntil._(null, true);

  factory PausedUntil.at(DateTime until) => PausedUntil._(until, false);

  /// Waktu berakhir; null bila tidak dijeda atau [indefinite].
  final DateTime? until;
  final bool indefinite;

  /// Terima null, string ISO 8601, 'infinity', atau '+infinity'. '-infinity'
  /// dan nilai tak terbaca dianggap tidak dijeda.
  factory PausedUntil.parse(Object? raw) {
    if (raw is! String) return none;
    final s = raw.trim().toLowerCase();
    if (s == 'infinity' || s == '+infinity') return indefinitely;
    final parsed = DateTime.tryParse(raw.trim());
    return parsed == null ? none : PausedUntil.at(parsed);
  }

  bool activeAt(DateTime now) =>
      indefinite || (until != null && until!.isAfter(now));
}
