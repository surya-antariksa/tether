import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True selama pengguna baru saja masuk lewat formulir dan belum menekan
/// "Lanjutkan ke Peta" di halaman konfirmasi sesi. Sesi yang dipulihkan saat
/// aplikasi dibuka TIDAK memicunya.
class SessionConfirmPending extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() => state = false;
}

final sessionConfirmProvider = NotifierProvider<SessionConfirmPending, bool>(
  SessionConfirmPending.new,
);
