import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'location_database.g.dart';

/// Antrean titik lokal. Waktu disimpan sebagai mikrodetik UTC (int) agar
/// presisi tidak hilang seperti penyimpanan DateTime bawaan (detik).
@DataClassName('QueuedPointRow')
class QueuedPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get accuracyM => real().nullable()();
  RealColumn get speedMps => real().nullable()();
  IntColumn get batteryPct => integer().nullable()();
  BoolColumn get isMoving => boolean()();
  IntColumn get recordedAtUs => integer()();
}

@DriftDatabase(tables: [QueuedPoints])
class LocationDatabase extends _$LocationDatabase {
  LocationDatabase(super.e);

  /// Database berkas di direktori data aplikasi. Di Linux ini mengikuti
  /// XDG_DATA_HOME, sehingga dua instance dengan XDG_DATA_HOME berbeda tidak
  /// berbagi antrean (direktori dokumen dipakai bersama dan tidak cocok).
  static Future<LocationDatabase> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    return openInDirectory(dir.path);
  }

  /// Database berkas di [directory] (harus sudah ada).
  static LocationDatabase openInDirectory(String directory) {
    final file = File(p.join(directory, 'tether_location_queue.sqlite'));
    return LocationDatabase(NativeDatabase.createInBackground(file));
  }

  /// Database sementara di memori (untuk tes).
  factory LocationDatabase.inMemory() =>
      LocationDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
