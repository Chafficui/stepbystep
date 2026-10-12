import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tabellen
// ---------------------------------------------------------------------------

/// GPS-Punkte, die (noch) an den Server gesendet werden müssen.
class Points extends Table {
  TextColumn get id => text()(); // UUID, PK
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get accuracy => real()();
  RealColumn get speed => real().nullable()();
  IntColumn get battery => integer().nullable()(); // Prozent 0..100
  IntColumn get recordedAt => integer()(); // ms since epoch (UTC)
  IntColumn get sentAt => integer().nullable()(); // ms, null = unsent

  @override
  Set<Column> get primaryKey => {id};
}

/// Check-ins mit Foto/Video, die (noch) hochgeladen werden müssen.
class PendingCheckins extends Table {
  TextColumn get id => text()(); // UUID, PK
  IntColumn get capturedAt => integer()(); // ms since epoch (UTC)
  TextColumn get mediaType => text()(); // 'photo' | 'video'
  TextColumn get filePath => text()();
  IntColumn get sentAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// SOS-/Abbruch-Alarme, die (noch) gesendet werden müssen.
class PendingAlerts extends Table {
  TextColumn get id => text()(); // UUID, PK
  TextColumn get type => text()(); // 'sos' | 'abort'
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get createdAt => integer()(); // ms since epoch (UTC)
  IntColumn get sentAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Datenbank + DAO-Methoden
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Points, PendingCheckins, PendingAlerts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.connect(super.connection);

  @override
  int get schemaVersion => 1;

  // --- Points ---

  Future<void> insertPoint(PointsCompanion entry) =>
      into(points).insert(entry, mode: InsertMode.insertOrReplace);

  /// Alle ungesendeten Punkte, älteste zuerst, max. 200 (Batch-Größe).
  Future<List<Point>> unsentPoints({int limit = 200}) =>
      (select(points)
            ..where((t) => t.sentAt.isNull())
            ..orderBy([(u) => OrderingTerm.asc(u.recordedAt)])
            ..limit(limit))
          .get();

  Future<void> markPointsSent(List<String> ids) =>
      (update(points)..where((t) => t.id.isIn(ids)))
          .write(PointsCompanion(sentAt: Value(DateTime.now().millisecondsSinceEpoch)));

  /// Letzter (gesendeter oder ungesendeter) Punkt — als Startwert für den
  /// Sampler nach App-Restart.
  Future<Point?> lastPoint() async {
    final rows = await (select(points)
          ..orderBy([(u) => OrderingTerm.desc(u.recordedAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> unsentPointCount() async {
    final countExp = points.id.count();
    final query = selectOnly(points)
      ..addColumns([countExp])
      ..where(points.sentAt.isNull());
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // --- PendingCheckins ---

  Future<void> insertCheckin(PendingCheckinsCompanion entry) =>
      into(pendingCheckins).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<PendingCheckin>> unsentCheckins({int limit = 50}) =>
      (select(pendingCheckins)
            ..where((t) => t.sentAt.isNull())
            ..orderBy([(u) => OrderingTerm.asc(u.capturedAt)])
            ..limit(limit))
          .get();

  Future<void> markCheckinsSent(List<String> ids) =>
      (update(pendingCheckins)..where((t) => t.id.isIn(ids)))
          .write(PendingCheckinsCompanion(
              sentAt: Value(DateTime.now().millisecondsSinceEpoch)));

  Future<int> unsentCheckinCount() async {
    final countExp = pendingCheckins.id.count();
    final query = selectOnly(pendingCheckins)
      ..addColumns([countExp])
      ..where(pendingCheckins.sentAt.isNull());
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // --- PendingAlerts ---

  Future<void> insertAlert(PendingAlertsCompanion entry) =>
      into(pendingAlerts).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<PendingAlert>> unsentAlerts({int limit = 50}) =>
      (select(pendingAlerts)
            ..where((t) => t.sentAt.isNull())
            ..orderBy([(u) => OrderingTerm.asc(u.createdAt)])
            ..limit(limit))
          .get();

  Future<void> markAlertsSent(List<String> ids) =>
      (update(pendingAlerts)..where((t) => t.id.isIn(ids)))
          .write(PendingAlertsCompanion(
              sentAt: Value(DateTime.now().millisecondsSinceEpoch)));

  Future<int> unsentAlertCount() async {
    final countExp = pendingAlerts.id.count();
    final query = selectOnly(pendingAlerts)
      ..addColumns([countExp])
      ..where(pendingAlerts.sentAt.isNull());
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'stepbystep.sqlite3'));
    return NativeDatabase.createInBackground(file);
  });
}
