import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_repository.dart';

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_account');
    } catch (e) {
      throw mapAccountError(e);
    }
  }
}

/// Galat teknis -> [AccountFailure]. 28000: tanpa auth.uid; P0002: profil tak
/// ada (lihat 20261104130500_delete_account.sql).
AccountFailure mapAccountError(Object e) {
  if (e is AccountFailure) return e;
  if (e is SocketException ||
      e is TimeoutException ||
      e is AuthRetryableFetchException ||
      // ClientException milik paket http (tidak diimpor langsung).
      e.runtimeType.toString() == 'ClientException') {
    return const AccountFailure(AccountFailureKind.network);
  }
  if (e is PostgrestException) {
    if (e.code == '28000' || e.code == '42501' || e.code == 'PGRST301') {
      return const AccountFailure(AccountFailureKind.unauthorized);
    }
    if (e.code == 'P0002') {
      return const AccountFailure(AccountFailureKind.notFound);
    }
  }
  return const AccountFailure(AccountFailureKind.unknown);
}
