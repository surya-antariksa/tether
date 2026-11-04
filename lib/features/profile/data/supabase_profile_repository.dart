import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, display_name, color, avatar_url';

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const ProfileFailure(ProfileFailureKind.notFound);
    return id;
  }

  @override
  Future<Profile> fetchOwn() async {
    try {
      final row = await _client
          .from('profiles')
          .select(_columns)
          .eq('id', _uid)
          .single();
      return _fromRow(row);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<Profile> updateOwn({String? displayName, String? color}) async {
    final changes = <String, dynamic>{
      'display_name': ?displayName?.trim(),
      'color': ?color,
    };
    if (changes.isEmpty) return fetchOwn();
    try {
      final row = await _client
          .from('profiles')
          .update(changes)
          .eq('id', _uid)
          .select(_columns)
          .single();
      return _fromRow(row);
    } catch (e) {
      throw _map(e);
    }
  }

  Profile _fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    displayName: row['display_name'] as String,
    color: row['color'] as String,
    avatarUrl: row['avatar_url'] as String?,
  );

  ProfileFailure _map(Object e) {
    if (e is ProfileFailure) return e;
    if (e is SocketException || e is TimeoutException) {
      return const ProfileFailure(ProfileFailureKind.network);
    }
    // PGRST116: tidak ada baris (RLS atau profil belum dibuat).
    if (e is PostgrestException && e.code == 'PGRST116') {
      return const ProfileFailure(ProfileFailureKind.notFound);
    }
    return const ProfileFailure(ProfileFailureKind.unknown);
  }
}
