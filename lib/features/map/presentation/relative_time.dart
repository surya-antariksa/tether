/// Waktu relatif bahasa Indonesia: "baru saja", "2 mnt lalu", "3 jam lalu",
/// "2 hari lalu". Waktu di masa depan (selisih jam kecil) dianggap "baru saja".
String formatRelativeTime(DateTime time, DateTime now) {
  final d = now.difference(time);
  if (d < const Duration(minutes: 1)) return 'baru saja';
  if (d < const Duration(hours: 1)) return '${d.inMinutes} mnt lalu';
  if (d < const Duration(days: 1)) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

/// Jam lokal 'HH.mm' (untuk "Sampai pukul 14.30").
String formatClock(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}.${two(t.minute)}';
}
