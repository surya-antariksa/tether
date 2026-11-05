import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:tether/features/places/domain/place.dart';
import 'package:tether/features/places/domain/place_error.dart';
import 'package:tether/features/places/domain/place_repository.dart';

/// Tempat uji di sekitar Jakarta.
Place placeOf(
  String id, {
  String circleId = 'c1',
  String name = 'Rumah',
  LatLng center = const LatLng(-6.2088, 106.8456),
  int radiusM = 200,
  String? createdBy = 'u1',
}) => Place(
  id: id,
  circleId: circleId,
  name: name,
  center: center,
  radiusM: radiusM,
  createdBy: createdBy,
);

/// Repository tempat palsu yang meniru aturan RPC: batas 5 per Circle
/// (limitReached), hanya pembuat atau admin yang boleh ubah/hapus
/// (notAllowed), tempat tidak ada (notFound).
class FakePlaceRepository implements PlaceRepository {
  FakePlaceRepository({
    List<Place> places = const [],
    this.selfId = 'u1',
    this.admin = false,
  }) : all = [...places];

  final String selfId;
  bool admin;
  final List<Place> all;

  /// Bila diisi, pemanggilan terkait melempar ini.
  Object? placesFailure;
  Object? mutationFailure;

  /// Bila diisi, `places` menunggu completer ini.
  Completer<void>? placesGate;

  int placesCalls = 0;
  final created =
      <({String circleId, String name, LatLng center, int radiusM})>[];
  final updated = <({String placeId, String name, int radiusM})>[];
  final deleted = <String>[];
  int _seq = 0;

  @override
  Future<List<Place>> places(String circleId) async {
    placesCalls++;
    await placesGate?.future;
    if (placesFailure != null) throw placesFailure!;
    return [
      for (final p in all)
        if (p.circleId == circleId) p,
    ];
  }

  @override
  Future<bool> isAdmin(String circleId) async => admin;

  @override
  Future<String> createPlace({
    required String circleId,
    required String name,
    required LatLng center,
    required int radiusM,
  }) async {
    if (mutationFailure != null) throw mutationFailure!;
    if (all.where((p) => p.circleId == circleId).length >=
        PlaceLimits.maxPerCircle) {
      throw const PlaceError(PlaceErrorKind.limitReached);
    }
    created.add((
      circleId: circleId,
      name: name,
      center: center,
      radiusM: radiusM,
    ));
    final id = 'new-${_seq++}';
    all.add(
      placeOf(
        id,
        circleId: circleId,
        name: name,
        center: center,
        radiusM: radiusM,
        createdBy: selfId,
      ),
    );
    return id;
  }

  int _indexOf(String placeId) => all.indexWhere((p) => p.id == placeId);

  void _checkManage(Place p) {
    if (p.createdBy != selfId && !admin) {
      throw const PlaceError(PlaceErrorKind.notAllowed);
    }
  }

  @override
  Future<void> updatePlace({
    required String placeId,
    required String name,
    required int radiusM,
  }) async {
    if (mutationFailure != null) throw mutationFailure!;
    final i = _indexOf(placeId);
    if (i < 0) throw const PlaceError(PlaceErrorKind.notFound);
    _checkManage(all[i]);
    updated.add((placeId: placeId, name: name, radiusM: radiusM));
    final p = all[i];
    all[i] = placeOf(
      p.id,
      circleId: p.circleId,
      name: name,
      center: p.center,
      radiusM: radiusM,
      createdBy: p.createdBy,
    );
  }

  @override
  Future<void> deletePlace(String placeId) async {
    if (mutationFailure != null) throw mutationFailure!;
    final i = _indexOf(placeId);
    if (i < 0) throw const PlaceError(PlaceErrorKind.notFound);
    _checkManage(all[i]);
    deleted.add(placeId);
    all.removeAt(i);
  }
}
