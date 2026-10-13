import 'package:flutter_test/flutter_test.dart';
import 'package:stepbystep_app/api/api_client.dart';
import 'package:stepbystep_app/core/track_merge.dart';

TrackPoint pt(int sec, {double lat = 50, double lng = 8, String? who}) =>
    TrackPoint(
      lat: lat,
      lng: lng,
      recordedAt: DateTime.utc(2026, 1, 1, 0, 0, sec),
      participantId: who,
    );

void main() {
  group('TrackMerge.mergeServer', () {
    test('sortiert aufsteigend und entfernt Duplikate', () {
      final merged = TrackMerge.mergeServer(
        [pt(10), pt(20)],
        [pt(20), pt(15, lat: 51), pt(30)],
      );
      expect(merged.map((p) => p.recordedAt.second), [10, 15, 20, 30]);
    });

    test('begrenzt auf die letzten maxPoints', () {
      final many = [for (var i = 0; i < 5100; i++) pt(0, lat: i / 1000)];
      // gleiche Zeit, verschiedene lat -> keine Duplikate
      final merged = TrackMerge.mergeServer(const [], many);
      expect(merged.length, TrackMerge.maxPoints);
    });
  });

  group('TrackMerge.withLocal', () {
    test('nur lokale Punkte neuer als der letzte Server-Punkt', () {
      final merged = TrackMerge.withLocal(
        [pt(10), pt(20)],
        [pt(5, lat: 52), pt(20, lat: 53), pt(25, lat: 54), pt(30, lat: 55)],
      );
      expect(merged.map((p) => p.recordedAt.second), [10, 20, 25, 30]);
      expect(merged.last.lat, 55);
    });

    test('ohne Server-Spur (offline) zählen alle lokalen Punkte', () {
      final merged = TrackMerge.withLocal(const [], [pt(30), pt(10)]);
      expect(merged.map((p) => p.recordedAt.second), [10, 30]);
    });

    test('leer + leer ist leer', () {
      expect(TrackMerge.withLocal(const [], const []), isEmpty);
    });
  });

  test('since liefert den letzten Server-Zeitpunkt', () {
    expect(TrackMerge.since(const []), isNull);
    expect(
        TrackMerge.since([pt(10), pt(20)]), DateTime.utc(2026, 1, 1, 0, 0, 20));
  });

  test('TrackPoint.fromJson / MeResult.fromJson', () {
    final p = TrackPoint.fromJson({
      'lat': 50.1,
      'lng': 8.2,
      'recorded_at': '2026-01-01T00:00:10.000Z',
      'participant_id': 'abc',
    });
    expect(p.participantId, 'abc');
    expect(p.recordedAt.isUtc, isTrue);
    final me = MeResult.fromJson({
      'team_id': 't',
      'team_name': 'T',
      'team_status': 'active',
      'display_name': 'D',
      'team_photo_updated_at': '2026-01-01T00:00:10.000Z',
    });
    expect(me.teamPhotoUpdatedAt, DateTime.utc(2026, 1, 1, 0, 0, 10));
    expect(
        MeResult.fromJson({
          'team_id': 't',
          'team_name': 'T',
          'team_status': 'active',
          'display_name': 'D',
          'team_photo_updated_at': null,
        }).teamPhotoUpdatedAt,
        isNull);
  });
}
