// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PointsTable extends Points with TableInfo<$PointsTable, Point> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _accuracyMeta =
      const VerificationMeta('accuracy');
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
      'accuracy', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
      'speed', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _batteryMeta =
      const VerificationMeta('battery');
  @override
  late final GeneratedColumn<int> battery = GeneratedColumn<int>(
      'battery', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<int> recordedAt = GeneratedColumn<int>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
      'sent_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, lat, lng, accuracy, speed, battery, recordedAt, sentAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'points';
  @override
  VerificationContext validateIntegrity(Insertable<Point> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(_accuracyMeta,
          accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta));
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
          _speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('battery')) {
      context.handle(_batteryMeta,
          battery.isAcceptableOrUnknown(data['battery']!, _batteryMeta));
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(_sentAtMeta,
          sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Point map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Point(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat'])!,
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng'])!,
      accuracy: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}accuracy'])!,
      speed: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}speed']),
      battery: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}battery']),
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}recorded_at'])!,
      sentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sent_at']),
    );
  }

  @override
  $PointsTable createAlias(String alias) {
    return $PointsTable(attachedDatabase, alias);
  }
}

class Point extends DataClass implements Insertable<Point> {
  final String id;
  final double lat;
  final double lng;
  final double accuracy;
  final double? speed;
  final int? battery;
  final int recordedAt;
  final int? sentAt;
  const Point(
      {required this.id,
      required this.lat,
      required this.lng,
      required this.accuracy,
      this.speed,
      this.battery,
      required this.recordedAt,
      this.sentAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['accuracy'] = Variable<double>(accuracy);
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    if (!nullToAbsent || battery != null) {
      map['battery'] = Variable<int>(battery);
    }
    map['recorded_at'] = Variable<int>(recordedAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<int>(sentAt);
    }
    return map;
  }

  PointsCompanion toCompanion(bool nullToAbsent) {
    return PointsCompanion(
      id: Value(id),
      lat: Value(lat),
      lng: Value(lng),
      accuracy: Value(accuracy),
      speed:
          speed == null && nullToAbsent ? const Value.absent() : Value(speed),
      battery: battery == null && nullToAbsent
          ? const Value.absent()
          : Value(battery),
      recordedAt: Value(recordedAt),
      sentAt:
          sentAt == null && nullToAbsent ? const Value.absent() : Value(sentAt),
    );
  }

  factory Point.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Point(
      id: serializer.fromJson<String>(json['id']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      speed: serializer.fromJson<double?>(json['speed']),
      battery: serializer.fromJson<int?>(json['battery']),
      recordedAt: serializer.fromJson<int>(json['recordedAt']),
      sentAt: serializer.fromJson<int?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'accuracy': serializer.toJson<double>(accuracy),
      'speed': serializer.toJson<double?>(speed),
      'battery': serializer.toJson<int?>(battery),
      'recordedAt': serializer.toJson<int>(recordedAt),
      'sentAt': serializer.toJson<int?>(sentAt),
    };
  }

  Point copyWith(
          {String? id,
          double? lat,
          double? lng,
          double? accuracy,
          Value<double?> speed = const Value.absent(),
          Value<int?> battery = const Value.absent(),
          int? recordedAt,
          Value<int?> sentAt = const Value.absent()}) =>
      Point(
        id: id ?? this.id,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        accuracy: accuracy ?? this.accuracy,
        speed: speed.present ? speed.value : this.speed,
        battery: battery.present ? battery.value : this.battery,
        recordedAt: recordedAt ?? this.recordedAt,
        sentAt: sentAt.present ? sentAt.value : this.sentAt,
      );
  Point copyWithCompanion(PointsCompanion data) {
    return Point(
      id: data.id.present ? data.id.value : this.id,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      speed: data.speed.present ? data.speed.value : this.speed,
      battery: data.battery.present ? data.battery.value : this.battery,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Point(')
          ..write('id: $id, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed, ')
          ..write('battery: $battery, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lat, lng, accuracy, speed, battery, recordedAt, sentAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Point &&
          other.id == this.id &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.accuracy == this.accuracy &&
          other.speed == this.speed &&
          other.battery == this.battery &&
          other.recordedAt == this.recordedAt &&
          other.sentAt == this.sentAt);
}

class PointsCompanion extends UpdateCompanion<Point> {
  final Value<String> id;
  final Value<double> lat;
  final Value<double> lng;
  final Value<double> accuracy;
  final Value<double?> speed;
  final Value<int?> battery;
  final Value<int> recordedAt;
  final Value<int?> sentAt;
  final Value<int> rowid;
  const PointsCompanion({
    this.id = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.speed = const Value.absent(),
    this.battery = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PointsCompanion.insert({
    required String id,
    required double lat,
    required double lng,
    required double accuracy,
    this.speed = const Value.absent(),
    this.battery = const Value.absent(),
    required int recordedAt,
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        lat = Value(lat),
        lng = Value(lng),
        accuracy = Value(accuracy),
        recordedAt = Value(recordedAt);
  static Insertable<Point> custom({
    Expression<String>? id,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<double>? accuracy,
    Expression<double>? speed,
    Expression<int>? battery,
    Expression<int>? recordedAt,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      if (battery != null) 'battery': battery,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PointsCompanion copyWith(
      {Value<String>? id,
      Value<double>? lat,
      Value<double>? lng,
      Value<double>? accuracy,
      Value<double?>? speed,
      Value<int?>? battery,
      Value<int>? recordedAt,
      Value<int?>? sentAt,
      Value<int>? rowid}) {
    return PointsCompanion(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      battery: battery ?? this.battery,
      recordedAt: recordedAt ?? this.recordedAt,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (battery.present) {
      map['battery'] = Variable<int>(battery.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<int>(recordedAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PointsCompanion(')
          ..write('id: $id, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed, ')
          ..write('battery: $battery, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingCheckinsTable extends PendingCheckins
    with TableInfo<$PendingCheckinsTable, PendingCheckin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingCheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _capturedAtMeta =
      const VerificationMeta('capturedAt');
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
      'captured_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
      'sent_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, capturedAt, mediaType, filePath, sentAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_checkins';
  @override
  VerificationContext validateIntegrity(Insertable<PendingCheckin> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
          _capturedAtMeta,
          capturedAt.isAcceptableOrUnknown(
              data['captured_at']!, _capturedAtMeta));
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(_sentAtMeta,
          sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingCheckin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingCheckin(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      capturedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}captured_at'])!,
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      sentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sent_at']),
    );
  }

  @override
  $PendingCheckinsTable createAlias(String alias) {
    return $PendingCheckinsTable(attachedDatabase, alias);
  }
}

class PendingCheckin extends DataClass implements Insertable<PendingCheckin> {
  final String id;
  final int capturedAt;
  final String mediaType;
  final String filePath;
  final int? sentAt;
  const PendingCheckin(
      {required this.id,
      required this.capturedAt,
      required this.mediaType,
      required this.filePath,
      this.sentAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['captured_at'] = Variable<int>(capturedAt);
    map['media_type'] = Variable<String>(mediaType);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<int>(sentAt);
    }
    return map;
  }

  PendingCheckinsCompanion toCompanion(bool nullToAbsent) {
    return PendingCheckinsCompanion(
      id: Value(id),
      capturedAt: Value(capturedAt),
      mediaType: Value(mediaType),
      filePath: Value(filePath),
      sentAt:
          sentAt == null && nullToAbsent ? const Value.absent() : Value(sentAt),
    );
  }

  factory PendingCheckin.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingCheckin(
      id: serializer.fromJson<String>(json['id']),
      capturedAt: serializer.fromJson<int>(json['capturedAt']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sentAt: serializer.fromJson<int?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'capturedAt': serializer.toJson<int>(capturedAt),
      'mediaType': serializer.toJson<String>(mediaType),
      'filePath': serializer.toJson<String>(filePath),
      'sentAt': serializer.toJson<int?>(sentAt),
    };
  }

  PendingCheckin copyWith(
          {String? id,
          int? capturedAt,
          String? mediaType,
          String? filePath,
          Value<int?> sentAt = const Value.absent()}) =>
      PendingCheckin(
        id: id ?? this.id,
        capturedAt: capturedAt ?? this.capturedAt,
        mediaType: mediaType ?? this.mediaType,
        filePath: filePath ?? this.filePath,
        sentAt: sentAt.present ? sentAt.value : this.sentAt,
      );
  PendingCheckin copyWithCompanion(PendingCheckinsCompanion data) {
    return PendingCheckin(
      id: data.id.present ? data.id.value : this.id,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingCheckin(')
          ..write('id: $id, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('mediaType: $mediaType, ')
          ..write('filePath: $filePath, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, capturedAt, mediaType, filePath, sentAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCheckin &&
          other.id == this.id &&
          other.capturedAt == this.capturedAt &&
          other.mediaType == this.mediaType &&
          other.filePath == this.filePath &&
          other.sentAt == this.sentAt);
}

class PendingCheckinsCompanion extends UpdateCompanion<PendingCheckin> {
  final Value<String> id;
  final Value<int> capturedAt;
  final Value<String> mediaType;
  final Value<String> filePath;
  final Value<int?> sentAt;
  final Value<int> rowid;
  const PendingCheckinsCompanion({
    this.id = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingCheckinsCompanion.insert({
    required String id,
    required int capturedAt,
    required String mediaType,
    required String filePath,
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        capturedAt = Value(capturedAt),
        mediaType = Value(mediaType),
        filePath = Value(filePath);
  static Insertable<PendingCheckin> custom({
    Expression<String>? id,
    Expression<int>? capturedAt,
    Expression<String>? mediaType,
    Expression<String>? filePath,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (mediaType != null) 'media_type': mediaType,
      if (filePath != null) 'file_path': filePath,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingCheckinsCompanion copyWith(
      {Value<String>? id,
      Value<int>? capturedAt,
      Value<String>? mediaType,
      Value<String>? filePath,
      Value<int?>? sentAt,
      Value<int>? rowid}) {
    return PendingCheckinsCompanion(
      id: id ?? this.id,
      capturedAt: capturedAt ?? this.capturedAt,
      mediaType: mediaType ?? this.mediaType,
      filePath: filePath ?? this.filePath,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingCheckinsCompanion(')
          ..write('id: $id, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('mediaType: $mediaType, ')
          ..write('filePath: $filePath, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingAlertsTable extends PendingAlerts
    with TableInfo<$PendingAlertsTable, PendingAlert> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingAlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
      'lat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
      'lng', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
      'sent_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, type, lat, lng, createdAt, sentAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_alerts';
  @override
  VerificationContext validateIntegrity(Insertable<PendingAlert> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
          _latMeta, lat.isAcceptableOrUnknown(data['lat']!, _latMeta));
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
          _lngMeta, lng.isAcceptableOrUnknown(data['lng']!, _lngMeta));
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(_sentAtMeta,
          sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAlert map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAlert(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      lat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lat'])!,
      lng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}lng'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      sentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sent_at']),
    );
  }

  @override
  $PendingAlertsTable createAlias(String alias) {
    return $PendingAlertsTable(attachedDatabase, alias);
  }
}

class PendingAlert extends DataClass implements Insertable<PendingAlert> {
  final String id;
  final String type;
  final double lat;
  final double lng;
  final int createdAt;
  final int? sentAt;
  const PendingAlert(
      {required this.id,
      required this.type,
      required this.lat,
      required this.lng,
      required this.createdAt,
      this.sentAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<int>(sentAt);
    }
    return map;
  }

  PendingAlertsCompanion toCompanion(bool nullToAbsent) {
    return PendingAlertsCompanion(
      id: Value(id),
      type: Value(type),
      lat: Value(lat),
      lng: Value(lng),
      createdAt: Value(createdAt),
      sentAt:
          sentAt == null && nullToAbsent ? const Value.absent() : Value(sentAt),
    );
  }

  factory PendingAlert.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAlert(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      sentAt: serializer.fromJson<int?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'createdAt': serializer.toJson<int>(createdAt),
      'sentAt': serializer.toJson<int?>(sentAt),
    };
  }

  PendingAlert copyWith(
          {String? id,
          String? type,
          double? lat,
          double? lng,
          int? createdAt,
          Value<int?> sentAt = const Value.absent()}) =>
      PendingAlert(
        id: id ?? this.id,
        type: type ?? this.type,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        createdAt: createdAt ?? this.createdAt,
        sentAt: sentAt.present ? sentAt.value : this.sentAt,
      );
  PendingAlert copyWithCompanion(PendingAlertsCompanion data) {
    return PendingAlert(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAlert(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, lat, lng, createdAt, sentAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAlert &&
          other.id == this.id &&
          other.type == this.type &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.createdAt == this.createdAt &&
          other.sentAt == this.sentAt);
}

class PendingAlertsCompanion extends UpdateCompanion<PendingAlert> {
  final Value<String> id;
  final Value<String> type;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int> createdAt;
  final Value<int?> sentAt;
  final Value<int> rowid;
  const PendingAlertsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingAlertsCompanion.insert({
    required String id,
    required String type,
    required double lat,
    required double lng,
    required int createdAt,
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        lat = Value(lat),
        lng = Value(lng),
        createdAt = Value(createdAt);
  static Insertable<PendingAlert> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? createdAt,
    Expression<int>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (createdAt != null) 'created_at': createdAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingAlertsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<double>? lat,
      Value<double>? lng,
      Value<int>? createdAt,
      Value<int?>? sentAt,
      Value<int>? rowid}) {
    return PendingAlertsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingAlertsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PointsTable points = $PointsTable(this);
  late final $PendingCheckinsTable pendingCheckins =
      $PendingCheckinsTable(this);
  late final $PendingAlertsTable pendingAlerts = $PendingAlertsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [points, pendingCheckins, pendingAlerts];
}

typedef $$PointsTableCreateCompanionBuilder = PointsCompanion Function({
  required String id,
  required double lat,
  required double lng,
  required double accuracy,
  Value<double?> speed,
  Value<int?> battery,
  required int recordedAt,
  Value<int?> sentAt,
  Value<int> rowid,
});
typedef $$PointsTableUpdateCompanionBuilder = PointsCompanion Function({
  Value<String> id,
  Value<double> lat,
  Value<double> lng,
  Value<double> accuracy,
  Value<double?> speed,
  Value<int?> battery,
  Value<int> recordedAt,
  Value<int?> sentAt,
  Value<int> rowid,
});

class $$PointsTableFilterComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracy => $composableBuilder(
      column: $table.accuracy, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get battery => $composableBuilder(
      column: $table.battery, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnFilters(column));
}

class $$PointsTableOrderingComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracy => $composableBuilder(
      column: $table.accuracy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get battery => $composableBuilder(
      column: $table.battery, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnOrderings(column));
}

class $$PointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PointsTable> {
  $$PointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<int> get battery =>
      $composableBuilder(column: $table.battery, builder: (column) => column);

  GeneratedColumn<int> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$PointsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PointsTable,
    Point,
    $$PointsTableFilterComposer,
    $$PointsTableOrderingComposer,
    $$PointsTableAnnotationComposer,
    $$PointsTableCreateCompanionBuilder,
    $$PointsTableUpdateCompanionBuilder,
    (Point, BaseReferences<_$AppDatabase, $PointsTable, Point>),
    Point,
    PrefetchHooks Function()> {
  $$PointsTableTableManager(_$AppDatabase db, $PointsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<double> lat = const Value.absent(),
            Value<double> lng = const Value.absent(),
            Value<double> accuracy = const Value.absent(),
            Value<double?> speed = const Value.absent(),
            Value<int?> battery = const Value.absent(),
            Value<int> recordedAt = const Value.absent(),
            Value<int?> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PointsCompanion(
            id: id,
            lat: lat,
            lng: lng,
            accuracy: accuracy,
            speed: speed,
            battery: battery,
            recordedAt: recordedAt,
            sentAt: sentAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required double lat,
            required double lng,
            required double accuracy,
            Value<double?> speed = const Value.absent(),
            Value<int?> battery = const Value.absent(),
            required int recordedAt,
            Value<int?> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PointsCompanion.insert(
            id: id,
            lat: lat,
            lng: lng,
            accuracy: accuracy,
            speed: speed,
            battery: battery,
            recordedAt: recordedAt,
            sentAt: sentAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PointsTable, Point>(table),
                    BaseReferences<_$AppDatabase, $PointsTable, Point>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PointsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PointsTable,
    Point,
    $$PointsTableFilterComposer,
    $$PointsTableOrderingComposer,
    $$PointsTableAnnotationComposer,
    $$PointsTableCreateCompanionBuilder,
    $$PointsTableUpdateCompanionBuilder,
    (Point, BaseReferences<_$AppDatabase, $PointsTable, Point>),
    Point,
    PrefetchHooks Function()>;
typedef $$PendingCheckinsTableCreateCompanionBuilder = PendingCheckinsCompanion
    Function({
  required String id,
  required int capturedAt,
  required String mediaType,
  required String filePath,
  Value<int?> sentAt,
  Value<int> rowid,
});
typedef $$PendingCheckinsTableUpdateCompanionBuilder = PendingCheckinsCompanion
    Function({
  Value<String> id,
  Value<int> capturedAt,
  Value<String> mediaType,
  Value<String> filePath,
  Value<int?> sentAt,
  Value<int> rowid,
});

class $$PendingCheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingCheckinsTable> {
  $$PendingCheckinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnFilters(column));
}

class $$PendingCheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingCheckinsTable> {
  $$PendingCheckinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingCheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingCheckinsTable> {
  $$PendingCheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$PendingCheckinsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingCheckinsTable,
    PendingCheckin,
    $$PendingCheckinsTableFilterComposer,
    $$PendingCheckinsTableOrderingComposer,
    $$PendingCheckinsTableAnnotationComposer,
    $$PendingCheckinsTableCreateCompanionBuilder,
    $$PendingCheckinsTableUpdateCompanionBuilder,
    (
      PendingCheckin,
      BaseReferences<_$AppDatabase, $PendingCheckinsTable, PendingCheckin>
    ),
    PendingCheckin,
    PrefetchHooks Function()> {
  $$PendingCheckinsTableTableManager(
      _$AppDatabase db, $PendingCheckinsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingCheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingCheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingCheckinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> capturedAt = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int?> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingCheckinsCompanion(
            id: id,
            capturedAt: capturedAt,
            mediaType: mediaType,
            filePath: filePath,
            sentAt: sentAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int capturedAt,
            required String mediaType,
            required String filePath,
            Value<int?> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingCheckinsCompanion.insert(
            id: id,
            capturedAt: capturedAt,
            mediaType: mediaType,
            filePath: filePath,
            sentAt: sentAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingCheckinsTable, PendingCheckin>(table),
                    BaseReferences<_$AppDatabase, $PendingCheckinsTable,
                        PendingCheckin>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingCheckinsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingCheckinsTable,
    PendingCheckin,
    $$PendingCheckinsTableFilterComposer,
    $$PendingCheckinsTableOrderingComposer,
    $$PendingCheckinsTableAnnotationComposer,
    $$PendingCheckinsTableCreateCompanionBuilder,
    $$PendingCheckinsTableUpdateCompanionBuilder,
    (
      PendingCheckin,
      BaseReferences<_$AppDatabase, $PendingCheckinsTable, PendingCheckin>
    ),
    PendingCheckin,
    PrefetchHooks Function()>;
typedef $$PendingAlertsTableCreateCompanionBuilder = PendingAlertsCompanion
    Function({
  required String id,
  required String type,
  required double lat,
  required double lng,
  required int createdAt,
  Value<int?> sentAt,
  Value<int> rowid,
});
typedef $$PendingAlertsTableUpdateCompanionBuilder = PendingAlertsCompanion
    Function({
  Value<String> id,
  Value<String> type,
  Value<double> lat,
  Value<double> lng,
  Value<int> createdAt,
  Value<int?> sentAt,
  Value<int> rowid,
});

class $$PendingAlertsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingAlertsTable> {
  $$PendingAlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnFilters(column));
}

class $$PendingAlertsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingAlertsTable> {
  $$PendingAlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lat => $composableBuilder(
      column: $table.lat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lng => $composableBuilder(
      column: $table.lng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingAlertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingAlertsTable> {
  $$PendingAlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$PendingAlertsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingAlertsTable,
    PendingAlert,
    $$PendingAlertsTableFilterComposer,
    $$PendingAlertsTableOrderingComposer,
    $$PendingAlertsTableAnnotationComposer,
    $$PendingAlertsTableCreateCompanionBuilder,
    $$PendingAlertsTableUpdateCompanionBuilder,
    (
      PendingAlert,
      BaseReferences<_$AppDatabase, $PendingAlertsTable, PendingAlert>
    ),
    PendingAlert,
    PrefetchHooks Function()> {
  $$PendingAlertsTableTableManager(_$AppDatabase db, $PendingAlertsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingAlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingAlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingAlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<double> lat = const Value.absent(),
            Value<double> lng = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int?> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingAlertsCompanion(
            id: id,
            type: type,
            lat: lat,
            lng: lng,
            createdAt: createdAt,
            sentAt: sentAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required double lat,
            required double lng,
            required int createdAt,
            Value<int?> sentAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingAlertsCompanion.insert(
            id: id,
            type: type,
            lat: lat,
            lng: lng,
            createdAt: createdAt,
            sentAt: sentAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingAlertsTable, PendingAlert>(table),
                    BaseReferences<_$AppDatabase, $PendingAlertsTable,
                        PendingAlert>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingAlertsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingAlertsTable,
    PendingAlert,
    $$PendingAlertsTableFilterComposer,
    $$PendingAlertsTableOrderingComposer,
    $$PendingAlertsTableAnnotationComposer,
    $$PendingAlertsTableCreateCompanionBuilder,
    $$PendingAlertsTableUpdateCompanionBuilder,
    (
      PendingAlert,
      BaseReferences<_$AppDatabase, $PendingAlertsTable, PendingAlert>
    ),
    PendingAlert,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PointsTableTableManager get points =>
      $$PointsTableTableManager(_db, _db.points);
  $$PendingCheckinsTableTableManager get pendingCheckins =>
      $$PendingCheckinsTableTableManager(_db, _db.pendingCheckins);
  $$PendingAlertsTableTableManager get pendingAlerts =>
      $$PendingAlertsTableTableManager(_db, _db.pendingAlerts);
}
