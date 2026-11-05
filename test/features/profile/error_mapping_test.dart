import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tether/features/history/data/supabase_history_repository.dart';
import 'package:tether/features/history/domain/history_repository.dart';
import 'package:tether/features/profile/data/supabase_account_repository.dart';
import 'package:tether/features/profile/domain/account_repository.dart';

/// Meniru ClientException milik paket http (dipetakan menurut nama tipe).
class ClientException implements Exception {}

void main() {
  final network = <String, Object>{
    'SocketException': const SocketException('x'),
    'TimeoutException': TimeoutException('x'),
    'AuthRetryableFetchException': AuthRetryableFetchException(message: 'x'),
    'ClientException': ClientException(),
  };

  group('mapAccountError', () {
    for (final e in network.entries) {
      test('${e.key} -> network', () {
        expect(mapAccountError(e.value).kind, AccountFailureKind.network);
      });
    }
    test('PostgrestException 28000 -> unauthorized, lain -> unknown', () {
      expect(
        mapAccountError(
          const PostgrestException(message: 'm', code: '28000'),
        ).kind,
        AccountFailureKind.unauthorized,
      );
      expect(mapAccountError(Exception('x')).kind, AccountFailureKind.unknown);
    });
  });

  group('mapHistoryError', () {
    for (final e in network.entries) {
      test('${e.key} -> network', () {
        expect(mapHistoryError(e.value).kind, HistoryFailureKind.network);
      });
    }
    test('PostgrestException 42501 -> unauthorized, lain -> unknown', () {
      expect(
        mapHistoryError(
          const PostgrestException(message: 'm', code: '42501'),
        ).kind,
        HistoryFailureKind.unauthorized,
      );
      expect(mapHistoryError(Exception('x')).kind, HistoryFailureKind.unknown);
    });
  });
}
