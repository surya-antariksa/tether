import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/place.dart';
import '../domain/place_error.dart';
import '../domain/place_repository.dart';
import 'place_mappers.dart';

class SupabasePlaceRepository implements PlaceRepository {
  SupabasePlaceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Place>> places(String circleId) async {
    try {
      final rows = await _client
          .from('places')
          .select('id, circle_id, name, center, radius_m, created_by')
          .eq('circle_id', circleId)
          .order('created_at', ascending: true);
      return [for (final r in rows) ?placeFromRow(r)];
    } catch (e) {
      throw mapPlaceError(e, forbidden: PlaceErrorKind.notMember);
    }
  }

  @override
  Future<bool> isAdmin(String circleId) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw const PlaceError(PlaceErrorKind.notSignedIn);
      final row = await _client
          .from('circle_members')
          .select('role')
          .eq('circle_id', circleId)
          .eq('user_id', uid)
          .maybeSingle();
      return row?['role'] == 'admin';
    } catch (e) {
      throw mapPlaceError(e, forbidden: PlaceErrorKind.notMember);
    }
  }

  @override
  Future<String> createPlace({
    required String circleId,
    required String name,
    required LatLng center,
    required int radiusM,
  }) async {
    try {
      final id = await _client.rpc(
        'create_place',
        params: {
          'p_circle_id': circleId,
          'p_name': name,
          'p_lat': center.latitude,
          'p_lng': center.longitude,
          'p_radius_m': radiusM,
        },
      );
      return id as String;
    } catch (e) {
      throw mapPlaceError(e, forbidden: PlaceErrorKind.notMember);
    }
  }

  @override
  Future<void> updatePlace({
    required String placeId,
    required String name,
    required int radiusM,
  }) async {
    try {
      await _client.rpc(
        'update_place',
        params: {'p_place_id': placeId, 'p_name': name, 'p_radius_m': radiusM},
      );
    } catch (e) {
      throw mapPlaceError(e);
    }
  }

  @override
  Future<void> deletePlace(String placeId) async {
    try {
      await _client.rpc('delete_place', params: {'p_place_id': placeId});
    } catch (e) {
      throw mapPlaceError(e);
    }
  }
}
