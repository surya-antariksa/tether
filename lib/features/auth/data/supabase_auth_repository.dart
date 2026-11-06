import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // Trigger di database membaca kunci ini untuk membuat baris profiles.
        data: {'display_name': displayName.trim()},
      );
      return res.session != null
          ? SignUpOutcome.signedIn
          : SignUpOutcome.confirmationRequired;
    } catch (e) {
      throw _map(e, signUp: true);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw _map(e, signUp: false);
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw _map(e, signUp: false);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw _map(e, signUp: false);
    }
  }

  AuthFailure _map(Object e, {required bool signUp}) {
    if (e is AuthFailure) return e;
    if (e is SocketException || e is TimeoutException) {
      return const AuthFailure(AuthFailureKind.network);
    }
    if (e is AuthRetryableFetchException) {
      return const AuthFailure(AuthFailureKind.network);
    }
    if (e is AuthException) {
      switch (e.code) {
        case 'invalid_credentials':
          return const AuthFailure(AuthFailureKind.invalidCredentials);
        case 'email_not_confirmed':
          return const AuthFailure(AuthFailureKind.emailNotConfirmed);
        case 'weak_password':
          return const AuthFailure(AuthFailureKind.weakPassword);
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return const AuthFailure(AuthFailureKind.rateLimited);
        case 'email_exists':
        case 'user_already_exists':
        case 'signup_disabled':
        case 'validation_failed':
          return const AuthFailure(AuthFailureKind.signUpFailed);
      }
      if (e.statusCode == '429') {
        return const AuthFailure(AuthFailureKind.rateLimited);
      }
      if (signUp) return const AuthFailure(AuthFailureKind.signUpFailed);
      // Kode 'invalid_credentials' tidak ada di enum paket; server membalas 400.
      if (e.statusCode == '400') {
        return const AuthFailure(AuthFailureKind.invalidCredentials);
      }
    }
    return const AuthFailure(AuthFailureKind.unknown);
  }
}
