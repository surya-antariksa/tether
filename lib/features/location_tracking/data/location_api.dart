import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_point.dart';

/// Kegagalan unggah. Pesan sengaja tidak memuat data titik (koordinat).
class LocationApiException implements Exception {
  const LocationApiException(this.message);

  final String message;

  @override
  String toString() => 'LocationApiException: $message';
}

/// Server menolak batch karena datanya tidak valid (SQLSTATE 22023): satu titik
/// buruk menggagalkan seluruh batch. Mengulang batch yang sama tidak pernah
/// berhasil, jadi pemanggil harus mengisolasi titik buruknya.
class InvalidBatchException extends LocationApiException {
  const InvalidBatchException(super.message);

  @override
  String toString() => 'InvalidBatchException: $message';
}

abstract class LocationApi {
  /// Mengirim satu batch dan mengembalikan jumlah titik yang masuk di server.
  /// Server idempoten, jadi kirim ulang batch yang sama aman.
  Future<int> uploadBatch(List<LocationPoint> points);
}

/// SQLSTATE invalid_parameter_value, dipakai upload_points untuk input buruk.
const String invalidDataSqlState = '22023';

/// SQLSTATE khusus upload_points: recorded_at terlalu jauh di masa depan (jam
/// perangkat maju). Sementara, bukan titik buruk: tetap di antrean.
const String clockSkewSqlState = 'TH001';

class SupabaseLocationApi implements LocationApi {
  SupabaseLocationApi(this._client);

  final SupabaseClient _client;

  @override
  Future<int> uploadBatch(List<LocationPoint> points) async {
    try {
      final res = await _client.rpc(
        'upload_points',
        params: {'p_points': points.map((p) => p.toJson()).toList()},
      );
      if (res is num) return res.toInt();
      throw const LocationApiException('respons upload_points tidak dikenal');
    } on PostgrestException catch (e) {
      // Pesan/detail Postgrest bisa memuat isi baris, jadi hanya kode.
      if (e.code == invalidDataSqlState) {
        throw const InvalidBatchException(
          'batch ditolak server (data tidak valid)',
        );
      }
      if (e.code == clockSkewSqlState) {
        throw const LocationApiException(
          'jam perangkat tidak sinkron, titik ditahan',
        );
      }
      throw LocationApiException('upload_points ditolak (kode ${e.code})');
    }
  }
}

/// Pembungkus untuk uji manual: saat [offline] true, semua unggahan gagal.
class FlakyLocationApi implements LocationApi {
  FlakyLocationApi(this._inner);

  final LocationApi _inner;
  bool offline = false;

  @override
  Future<int> uploadBatch(List<LocationPoint> points) async {
    if (offline) {
      throw const LocationApiException('jaringan diputus (simulasi)');
    }
    return _inner.uploadBatch(points);
  }
}
