/// Tipe aktivitas berkendara atau mobilitas anggota Circle.
enum VehicleType {
  /// Diam / tidak ada pergerakan bermakna.
  none,

  /// Berjalan kaki / bergerak pelan (< 15 km/jam).
  walking,

  /// Sepeda motor (15 - 45 km/jam).
  motorcycle,

  /// Mobil / kendaraan cepat (>= 45 km/jam).
  car;

  /// Apakah anggota sedang berkendara (motor atau mobil).
  bool get isDriving => this == motorcycle || this == car;

  /// Label deskriptif bahasa Indonesia.
  String get label => switch (this) {
    none => 'Diam',
    walking => 'Berjalan',
    motorcycle => 'Motor',
    car => 'Mobil',
  };
}

/// Menentukan [VehicleType] dari kecepatan (m/s) dan status [isMoving].
VehicleType detectVehicle({
  required double? speedMps,
  required bool? isMoving,
}) {
  if (isMoving == false) return VehicleType.none;
  if (speedMps == null) return VehicleType.none;
  final kmh = speedMps * 3.6;
  if (kmh < 1.5) return VehicleType.none;
  if (kmh < 15.0) return VehicleType.walking;
  if (kmh < 45.0) return VehicleType.motorcycle;
  return VehicleType.car;
}

/// Konversi kecepatan dari meter per detik (m/s) ke kilometer per jam (km/jam).
double? speedMpsToKmh(double? speedMps) =>
    speedMps != null ? speedMps * 3.6 : null;

/// Format angka km/jam menjadi teks rapi (contoh: "45 km/jam").
String formatSpeedKmh(double kmh) => '${kmh.round()} km/jam';
