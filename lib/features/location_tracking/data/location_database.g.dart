// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_database.dart';

// ignore_for_file: type=lint
class $QueuedPointsTable extends QueuedPoints
    with TableInfo<$QueuedPointsTable, QueuedPointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMMeta = const VerificationMeta(
    'accuracyM',
  );
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
    'accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMpsMeta = const VerificationMeta(
    'speedMps',
  );
  @override
  late final GeneratedColumn<double> speedMps = GeneratedColumn<double>(
    'speed_mps',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batteryPctMeta = const VerificationMeta(
    'batteryPct',
  );
  @override
  late final GeneratedColumn<int> batteryPct = GeneratedColumn<int>(
    'battery_pct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMovingMeta = const VerificationMeta(
    'isMoving',
  );
  @override
  late final GeneratedColumn<bool> isMoving = GeneratedColumn<bool>(
    'is_moving',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_moving" IN (0, 1))',
    ),
  );
  static const VerificationMeta _recordedAtUsMeta = const VerificationMeta(
    'recordedAtUs',
  );
  @override
  late final GeneratedColumn<int> recordedAtUs = GeneratedColumn<int>(
    'recorded_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lat,
    lng,
    accuracyM,
    speedMps,
    batteryPct,
    isMoving,
    recordedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueuedPointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(
        _accuracyMMeta,
        accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta),
      );
    }
    if (data.containsKey('speed_mps')) {
      context.handle(
        _speedMpsMeta,
        speedMps.isAcceptableOrUnknown(data['speed_mps']!, _speedMpsMeta),
      );
    }
    if (data.containsKey('battery_pct')) {
      context.handle(
        _batteryPctMeta,
        batteryPct.isAcceptableOrUnknown(data['battery_pct']!, _batteryPctMeta),
      );
    }
    if (data.containsKey('is_moving')) {
      context.handle(
        _isMovingMeta,
        isMoving.isAcceptableOrUnknown(data['is_moving']!, _isMovingMeta),
      );
    } else if (isInserting) {
      context.missing(_isMovingMeta);
    }
    if (data.containsKey('recorded_at_us')) {
      context.handle(
        _recordedAtUsMeta,
        recordedAtUs.isAcceptableOrUnknown(
          data['recorded_at_us']!,
          _recordedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueuedPointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedPointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      accuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy_m'],
      ),
      speedMps: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_mps'],
      ),
      batteryPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery_pct'],
      ),
      isMoving: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_moving'],
      )!,
      recordedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_us'],
      )!,
    );
  }

  @override
  $QueuedPointsTable createAlias(String alias) {
    return $QueuedPointsTable(attachedDatabase, alias);
  }
}

class QueuedPointRow extends DataClass implements Insertable<QueuedPointRow> {
  final int id;
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final int? batteryPct;
  final bool isMoving;
  final int recordedAtUs;
  const QueuedPointRow({
    required this.id,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.batteryPct,
    required this.isMoving,
    required this.recordedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<double>(accuracyM);
    }
    if (!nullToAbsent || speedMps != null) {
      map['speed_mps'] = Variable<double>(speedMps);
    }
    if (!nullToAbsent || batteryPct != null) {
      map['battery_pct'] = Variable<int>(batteryPct);
    }
    map['is_moving'] = Variable<bool>(isMoving);
    map['recorded_at_us'] = Variable<int>(recordedAtUs);
    return map;
  }

  QueuedPointsCompanion toCompanion(bool nullToAbsent) {
    return QueuedPointsCompanion(
      id: Value(id),
      lat: Value(lat),
      lng: Value(lng),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      speedMps: speedMps == null && nullToAbsent
          ? const Value.absent()
          : Value(speedMps),
      batteryPct: batteryPct == null && nullToAbsent
          ? const Value.absent()
          : Value(batteryPct),
      isMoving: Value(isMoving),
      recordedAtUs: Value(recordedAtUs),
    );
  }

  factory QueuedPointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedPointRow(
      id: serializer.fromJson<int>(json['id']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      accuracyM: serializer.fromJson<double?>(json['accuracyM']),
      speedMps: serializer.fromJson<double?>(json['speedMps']),
      batteryPct: serializer.fromJson<int?>(json['batteryPct']),
      isMoving: serializer.fromJson<bool>(json['isMoving']),
      recordedAtUs: serializer.fromJson<int>(json['recordedAtUs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'accuracyM': serializer.toJson<double?>(accuracyM),
      'speedMps': serializer.toJson<double?>(speedMps),
      'batteryPct': serializer.toJson<int?>(batteryPct),
      'isMoving': serializer.toJson<bool>(isMoving),
      'recordedAtUs': serializer.toJson<int>(recordedAtUs),
    };
  }

  QueuedPointRow copyWith({
    int? id,
    double? lat,
    double? lng,
    Value<double?> accuracyM = const Value.absent(),
    Value<double?> speedMps = const Value.absent(),
    Value<int?> batteryPct = const Value.absent(),
    bool? isMoving,
    int? recordedAtUs,
  }) => QueuedPointRow(
    id: id ?? this.id,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
    speedMps: speedMps.present ? speedMps.value : this.speedMps,
    batteryPct: batteryPct.present ? batteryPct.value : this.batteryPct,
    isMoving: isMoving ?? this.isMoving,
    recordedAtUs: recordedAtUs ?? this.recordedAtUs,
  );
  QueuedPointRow copyWithCompanion(QueuedPointsCompanion data) {
    return QueuedPointRow(
      id: data.id.present ? data.id.value : this.id,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      speedMps: data.speedMps.present ? data.speedMps.value : this.speedMps,
      batteryPct: data.batteryPct.present
          ? data.batteryPct.value
          : this.batteryPct,
      isMoving: data.isMoving.present ? data.isMoving.value : this.isMoving,
      recordedAtUs: data.recordedAtUs.present
          ? data.recordedAtUs.value
          : this.recordedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedPointRow(')
          ..write('id: $id, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('speedMps: $speedMps, ')
          ..write('batteryPct: $batteryPct, ')
          ..write('isMoving: $isMoving, ')
          ..write('recordedAtUs: $recordedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lat,
    lng,
    accuracyM,
    speedMps,
    batteryPct,
    isMoving,
    recordedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedPointRow &&
          other.id == this.id &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.accuracyM == this.accuracyM &&
          other.speedMps == this.speedMps &&
          other.batteryPct == this.batteryPct &&
          other.isMoving == this.isMoving &&
          other.recordedAtUs == this.recordedAtUs);
}

class QueuedPointsCompanion extends UpdateCompanion<QueuedPointRow> {
  final Value<int> id;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double?> accuracyM;
  final Value<double?> speedMps;
  final Value<int?> batteryPct;
  final Value<bool> isMoving;
  final Value<int> recordedAtUs;
  const QueuedPointsCompanion({
    this.id = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.speedMps = const Value.absent(),
    this.batteryPct = const Value.absent(),
    this.isMoving = const Value.absent(),
    this.recordedAtUs = const Value.absent(),
  });
  QueuedPointsCompanion.insert({
    this.id = const Value.absent(),
    required double lat,
    required double lng,
    this.accuracyM = const Value.absent(),
    this.speedMps = const Value.absent(),
    this.batteryPct = const Value.absent(),
    required bool isMoving,
    required int recordedAtUs,
  }) : lat = Value(lat),
       lng = Value(lng),
       isMoving = Value(isMoving),
       recordedAtUs = Value(recordedAtUs);
  static Insertable<QueuedPointRow> custom({
    Expression<int>? id,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? accuracyM,
    Expression<double>? speedMps,
    Expression<int>? batteryPct,
    Expression<bool>? isMoving,
    Expression<int>? recordedAtUs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (speedMps != null) 'speed_mps': speedMps,
      if (batteryPct != null) 'battery_pct': batteryPct,
      if (isMoving != null) 'is_moving': isMoving,
      if (recordedAtUs != null) 'recorded_at_us': recordedAtUs,
    });
  }

  QueuedPointsCompanion copyWith({
    Value<int>? id,
    Value<double>? lat,
    Value<double>? lng,
    Value<double?>? accuracyM,
    Value<double?>? speedMps,
    Value<int?>? batteryPct,
    Value<bool>? isMoving,
    Value<int>? recordedAtUs,
  }) {
    return QueuedPointsCompanion(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyM: accuracyM ?? this.accuracyM,
      speedMps: speedMps ?? this.speedMps,
      batteryPct: batteryPct ?? this.batteryPct,
      isMoving: isMoving ?? this.isMoving,
      recordedAtUs: recordedAtUs ?? this.recordedAtUs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (speedMps.present) {
      map['speed_mps'] = Variable<double>(speedMps.value);
    }
    if (batteryPct.present) {
      map['battery_pct'] = Variable<int>(batteryPct.value);
    }
    if (isMoving.present) {
      map['is_moving'] = Variable<bool>(isMoving.value);
    }
    if (recordedAtUs.present) {
      map['recorded_at_us'] = Variable<int>(recordedAtUs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedPointsCompanion(')
          ..write('id: $id, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('speedMps: $speedMps, ')
          ..write('batteryPct: $batteryPct, ')
          ..write('isMoving: $isMoving, ')
          ..write('recordedAtUs: $recordedAtUs')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocationDatabase extends GeneratedDatabase {
  _$LocationDatabase(QueryExecutor e) : super(e);
  $LocationDatabaseManager get managers => $LocationDatabaseManager(this);
  late final $QueuedPointsTable queuedPoints = $QueuedPointsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [queuedPoints];
}

typedef $$QueuedPointsTableCreateCompanionBuilder =
    QueuedPointsCompanion Function({
      Value<int> id,
      required double lat,
      required double lng,
      Value<double?> accuracyM,
      Value<double?> speedMps,
      Value<int?> batteryPct,
      required bool isMoving,
      required int recordedAtUs,
    });
typedef $$QueuedPointsTableUpdateCompanionBuilder =
    QueuedPointsCompanion Function({
      Value<int> id,
      Value<double> lat,
      Value<double> lng,
      Value<double?> accuracyM,
      Value<double?> speedMps,
      Value<int?> batteryPct,
      Value<bool> isMoving,
      Value<int> recordedAtUs,
    });

class $$QueuedPointsTableFilterComposer
    extends Composer<_$LocationDatabase, $QueuedPointsTable> {
  $$QueuedPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedMps => $composableBuilder(
    column: $table.speedMps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batteryPct => $composableBuilder(
    column: $table.batteryPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMoving => $composableBuilder(
    column: $table.isMoving,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueuedPointsTableOrderingComposer
    extends Composer<_$LocationDatabase, $QueuedPointsTable> {
  $$QueuedPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedMps => $composableBuilder(
    column: $table.speedMps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batteryPct => $composableBuilder(
    column: $table.batteryPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMoving => $composableBuilder(
    column: $table.isMoving,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueuedPointsTableAnnotationComposer
    extends Composer<_$LocationDatabase, $QueuedPointsTable> {
  $$QueuedPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<double> get speedMps =>
      $composableBuilder(column: $table.speedMps, builder: (column) => column);

  GeneratedColumn<int> get batteryPct => $composableBuilder(
    column: $table.batteryPct,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMoving =>
      $composableBuilder(column: $table.isMoving, builder: (column) => column);

  GeneratedColumn<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => column,
  );
}

class $$QueuedPointsTableTableManager
    extends
        RootTableManager<
          _$LocationDatabase,
          $QueuedPointsTable,
          QueuedPointRow,
          $$QueuedPointsTableFilterComposer,
          $$QueuedPointsTableOrderingComposer,
          $$QueuedPointsTableAnnotationComposer,
          $$QueuedPointsTableCreateCompanionBuilder,
          $$QueuedPointsTableUpdateCompanionBuilder,
          (
            QueuedPointRow,
            BaseReferences<
              _$LocationDatabase,
              $QueuedPointsTable,
              QueuedPointRow
            >,
          ),
          QueuedPointRow,
          PrefetchHooks Function()
        > {
  $$QueuedPointsTableTableManager(
    _$LocationDatabase db,
    $QueuedPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<double?> accuracyM = const Value.absent(),
                Value<double?> speedMps = const Value.absent(),
                Value<int?> batteryPct = const Value.absent(),
                Value<bool> isMoving = const Value.absent(),
                Value<int> recordedAtUs = const Value.absent(),
              }) => QueuedPointsCompanion(
                id: id,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                speedMps: speedMps,
                batteryPct: batteryPct,
                isMoving: isMoving,
                recordedAtUs: recordedAtUs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required double lat,
                required double lng,
                Value<double?> accuracyM = const Value.absent(),
                Value<double?> speedMps = const Value.absent(),
                Value<int?> batteryPct = const Value.absent(),
                required bool isMoving,
                required int recordedAtUs,
              }) => QueuedPointsCompanion.insert(
                id: id,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                speedMps: speedMps,
                batteryPct: batteryPct,
                isMoving: isMoving,
                recordedAtUs: recordedAtUs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QueuedPointsTable, QueuedPointRow>(table),
                  BaseReferences<
                    _$LocationDatabase,
                    $QueuedPointsTable,
                    QueuedPointRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueuedPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocationDatabase,
      $QueuedPointsTable,
      QueuedPointRow,
      $$QueuedPointsTableFilterComposer,
      $$QueuedPointsTableOrderingComposer,
      $$QueuedPointsTableAnnotationComposer,
      $$QueuedPointsTableCreateCompanionBuilder,
      $$QueuedPointsTableUpdateCompanionBuilder,
      (
        QueuedPointRow,
        BaseReferences<_$LocationDatabase, $QueuedPointsTable, QueuedPointRow>,
      ),
      QueuedPointRow,
      PrefetchHooks Function()
    >;

class $LocationDatabaseManager {
  final _$LocationDatabase _db;
  $LocationDatabaseManager(this._db);
  $$QueuedPointsTableTableManager get queuedPoints =>
      $$QueuedPointsTableTableManager(_db, _db.queuedPoints);
}
