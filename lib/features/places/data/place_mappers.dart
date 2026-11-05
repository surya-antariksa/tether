import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../map/domain/geography.dart';
import '../domain/place.dart';
import '../domain/place_error.dart';

/// Baris tabel `places` menjadi [Place]. Null bila id, nama, titik, atau radius
/// tidak valid. Tidak pernah mencatat atau menyertakan koordinat dalam galat.
Place? placeFromRow(Map<dynamic, dynamic> r) {
  final id = r['id'];
  final circleId = r['circle_id'];
  final name = r['name'];
  final radius = r['radius_m'];
  final center = parseGeographyPoint(r['center']);
  if (id is! String ||
      circleId is! String ||
      name is! String ||
      radius is! num ||
      center == null) {
    return null;
  }
  return Place(
    id: id,
    circleId: circleId,
    name: name,
    center: center,
    radiusM: radius.toInt(),
    createdBy: r['created_by'] as String?,
  );
}

/// Memetakan galat apa pun ke [PlaceError]. SQLSTATE 42501 bermakna lain per
/// operasi, jadi pemanggil memberi [forbidden]. Pesan asli tidak diteruskan.
PlaceError mapPlaceError(
  Object e, {
  PlaceErrorKind forbidden = PlaceErrorKind.notAllowed,
}) {
  if (e is PlaceError) return e;
  if (e is SocketException ||
      e is TimeoutException ||
      e is AuthRetryableFetchException ||
      // ClientException milik paket http (tidak diimpor langsung).
      e.runtimeType.toString() == 'ClientException') {
    return const PlaceError(PlaceErrorKind.network);
  }
  if (e is PostgrestException) {
    return PlaceError(switch (e.code) {
      'TH005' => PlaceErrorKind.limitReached,
      '42501' => forbidden,
      'P0002' => PlaceErrorKind.notFound,
      '22023' => PlaceErrorKind.invalid,
      '28000' => PlaceErrorKind.notSignedIn,
      _ => PlaceErrorKind.unknown,
    });
  }
  return const PlaceError(PlaceErrorKind.unknown);
}
