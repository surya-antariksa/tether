import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Mengurai kolom `geography(Point, 4326)` dari PostgREST/Realtime menjadi
/// [LatLng]. Bentuk yang dikenali (diverifikasi ke Supabase lokal):
/// - EWKB hex (bawaan PostgREST dan payload Realtime), mis.
///   '0101000020E6100000...': byte order, tipe (+ flag SRID), SRID, lon, lat.
/// - GeoJSON `{"type":"Point","coordinates":[lon,lat]}` (header
///   `Accept: application/geo+json`, atau GeoJSON yang sudah di-decode).
/// Mengembalikan null untuk nilai kosong, bukan Point, atau di luar rentang.
/// Tidak pernah mencatat atau menyertakan koordinat dalam galat.
LatLng? parseGeographyPoint(Object? raw) {
  if (raw is Map) return _fromGeoJson(raw);
  if (raw is String) return _fromWkbHex(raw.trim());
  return null;
}

LatLng? _fromGeoJson(Map raw) {
  if (raw['type'] != 'Point') return null;
  final c = raw['coordinates'];
  if (c is! List || c.length < 2) return null;
  final lon = c[0], lat = c[1];
  if (lon is! num || lat is! num) return null;
  return _valid(lat.toDouble(), lon.toDouble());
}

LatLng? _fromWkbHex(String hex) {
  // Minimal: 1 byte order + 4 tipe + 16 koordinat = 21 byte.
  if (hex.length < 42 || hex.length.isOdd) return null;
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final b = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (b == null) return null;
    bytes.add(b);
  }
  final order = bytes[0];
  if (order != 0 && order != 1) return null;
  final endian = order == 1 ? Endian.little : Endian.big;
  final data = ByteData.sublistView(Uint8List.fromList(bytes));

  final type = data.getUint32(1, endian);
  const hasZ = 0x80000000, hasM = 0x40000000, hasSrid = 0x20000000;
  if (type & 0x0FFFFFFF != 1) return null; // bukan Point
  var offset = 5;
  if (type & hasSrid != 0) offset += 4;
  final dims = 2 + (type & hasZ != 0 ? 1 : 0) + (type & hasM != 0 ? 1 : 0);
  if (data.lengthInBytes < offset + dims * 8) return null;
  final lon = data.getFloat64(offset, endian);
  final lat = data.getFloat64(offset + 8, endian);
  return _valid(lat, lon);
}

LatLng? _valid(double lat, double lon) {
  if (!lat.isFinite || !lon.isFinite) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return LatLng(lat, lon);
}
