import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Circle yang sedang dipilih pengguna (dipakai tab Peta, Aktivitas, dan lain-lain).
/// Null berarti belum dipilih. Fitur yang butuh nilai awal mengambil Circle
/// pertama pengguna sendiri lalu memanggil [SelectedCircleId.select].
class SelectedCircleId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? circleId) => state = circleId;
}

final selectedCircleIdProvider = NotifierProvider<SelectedCircleId, String?>(
  SelectedCircleId.new,
);
