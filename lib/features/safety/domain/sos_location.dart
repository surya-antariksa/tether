import 'sos_models.dart';

/// Sumber posisi untuk SOS. Tidak pernah melempar: null berarti tidak ada.
abstract class SosLocationProvider {
  /// Posisi saat ini (bisa lama bila GPS lambat; pemanggil memberi batas waktu).
  Future<SosFix?> current();

  /// Posisi terakhir yang diketahui perangkat.
  Future<SosFix?> lastKnown();
}
