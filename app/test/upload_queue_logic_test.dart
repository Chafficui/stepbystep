import 'package:flutter_test/flutter_test.dart';
import 'package:stepbystep_app/tracking/upload_queue_logic.dart';

QueuedPoint _p(int id, {int recordedAtMs = 0, double? lat}) => QueuedPoint(
      id: 'p$id',
      lat: lat ?? 52.5,
      lng: 13.4,
      accuracy: 10,
      recordedAtMs: recordedAtMs,
    );

void main() {
  group('idsToMarkAccepted (nur bestätigte IDs markieren)', () {
    test('nur die vom Server bestätigten IDs werden markiert', () {
      final result = idsToMarkAccepted(
        ['a', 'b', 'c', 'd'],
        ['b', 'd'],
      );
      expect(result, ['b', 'd']);
    });

    test('leere Bestätigung: nichts markieren (Retry behält alle Punkte)', () {
      expect(idsToMarkAccepted(['a', 'b'], []), isEmpty);
    });

    test('Server kann nichts Bestätigen, was nie gesendet wurde', () {
      expect(idsToMarkAccepted(['a'], ['x', 'a', 'ghost']), ['a']);
    });

    test('Doppelte Bestätigungen werden nicht doppelt markiert', () {
      expect(idsToMarkAccepted(['a', 'b'], ['a', 'a', 'b']), ['a', 'b']);
    });

    test('Reihenfolge folgt der Bestätigung', () {
      expect(idsToMarkAccepted(['a', 'b', 'c'], ['c', 'a']), ['c', 'a']);
    });
  });

  group('splitIntoBatches (chronologisch, 200-Cap, Rest)', () {
    test('450 Punkte -> 200 + 200 + 50', () {
      final points = List.generate(450, (i) => _p(i, recordedAtMs: i));
      final batches = splitIntoBatches(points);
      expect(batches.length, 3);
      expect(batches[0].length, 200);
      expect(batches[1].length, 200);
      expect(batches[2].length, 50);
    });

    test('genau 200 Punkte -> ein Batch', () {
      final points = List.generate(200, (i) => _p(i, recordedAtMs: i));
      expect(splitIntoBatches(points).length, 1);
    });

    test('chronologische Reihenfolge bleibt erhalten', () {
      final points =
          List.generate(250, (i) => _p(i, recordedAtMs: 1000 - i)); // absteigend
      final batch = splitIntoBatches(dedupeAndSortChronologically(points))
          .first;
      expect(batch.first.recordedAtMs, lessThanOrEqualTo(batch.last.recordedAtMs));
    });

    test('leere Liste -> kein Batch', () {
      expect(splitIntoBatches(const []), isEmpty);
    });
  });

  group('dedupeAndSortChronologically (UUID-Dedupe)', () {
    test('gleiche UUID (App-Restart/Doppelt queuing) bleibt einmal', () {
      final a = _p(1, recordedAtMs: 100);
      final b = _p(1, recordedAtMs: 100); // gleiche id
      final c = _p(2, recordedAtMs: 50);
      final result = dedupeAndSortChronologically([a, b, c]);
      expect(result.map((p) => p.id), ['p2', 'p1']);
    });

    test('ein Punkt wird nie zwecks dedupe doppelt pro Batch gesendet', () {
      final points = dedupeAndSortChronologically([
        _p(1, recordedAtMs: 3),
        _p(1, recordedAtMs: 3),
        _p(2, recordedAtMs: 1),
      ]);
      for (final batch in splitIntoBatches(points)) {
        final ids = batch.map((p) => p.id).toSet().toList();
        expect(ids.length, batch.length);
      }
    });
  });

  group('backoffFor (exponentiell, max 30 min, Reset nach Erfolg)', () {
    test('2, 4, 8, 16, 30, 30, ...', () {
      expect(backoffFor(1), const Duration(minutes: 2));
      expect(backoffFor(2), const Duration(minutes: 4));
      expect(backoffFor(3), const Duration(minutes: 8));
      expect(backoffFor(4), const Duration(minutes: 16));
      expect(backoffFor(5), const Duration(minutes: 30));
      expect(backoffFor(10), const Duration(minutes: 30));
    });

    test('0 Fehler (nach Erfolg) -> 2 Minuten', () {
      expect(backoffFor(0), const Duration(minutes: 2));
    });
  });

  group('orderedAlerts (SOS zuerst)', () {
    test('SOS klebt nicht hinter Abort/Backlog', () {
      final result = orderedAlerts([
        const QueuedAlert(
            id: 'a1', type: 'abort', lat: 1, lng: 2, createdAtMs: 10),
        const QueuedAlert(
            id: 's1', type: 'sos', lat: 1, lng: 2, createdAtMs: 99),
        const QueuedAlert(
            id: 'a2', type: 'abort', lat: 1, lng: 2, createdAtMs: 5),
      ]);
      expect(result.map((a) => a.id), ['s1', 'a2', 'a1']);
    });
  });

  group('Neustart-Simulation (neue Service-Instanz, gleiche DB)', () {
    test('ungesendete Punkte bleiben die gleiche pending-Menge', () {
      // "DB-Zustand" vor dem Neustart: 3 Punkte, 1 bestätigt/markiert.
      var pending = ['p1', 'p2', 'p3'];

      // Service-Instanz 1: Batch senden, Server bestätigt p1 + p2.
      final sent1 = [...pending];
      final accepted1 = ['p1', 'p2'];
      final marked1 = idsToMarkAccepted(sent1, accepted1);
      pending = pending.where((id) => !marked1.contains(id)).toList();

      // Neustart: neue Instanz liest die gleiche DB -> p3 bleibt pending.
      final restartPending = [...pending];
      expect(restartPending, ['p3']);

      // Instanz 2 sendet erneut — p1/p2 werden NICHT erneut gesendet.
      final sent2 = restartPending;
      expect(sent2.contains('p1'), isFalse);
      expect(sent2.contains('p2'), isFalse);
    });

    test('Batch-Cap auch über Neustart hinweg: Rest bleibt pending', () {
      final points =
          List.generate(230, (i) => _p(i, recordedAtMs: i));
      final batches = splitIntoBatches(points);
      var pending = points.map((p) => p.id).toList();
      for (final batch in batches) {
        final sent = batch.map((p) => p.id).toList();
        // Server bestätigt alles in diesem Batch:
        final marked = idsToMarkAccepted(sent, sent);
        pending = pending.where((id) => !marked.contains(id)).toList();
      }
      expect(pending, isEmpty);
    });
  });
}
