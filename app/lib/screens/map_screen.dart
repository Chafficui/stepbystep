import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/geo.dart';
import '../models/event_config.dart';
import '../state/services.dart';
import '../tracking/tracking_service.dart';

/// Karte (OpenStreetMap) mit der eigenen Route, dem aktuellen Standpunkt
/// und dem Startpunkt (nur nach Enthüllung).
///
/// - Track: nur echte lokal gespeicherte Punkte (KEINE Interpolation von
///   Lücken zwischen den Punkten).
/// - Funktioniert offline: Tiles bleiben ggf. leer, Polylinie/Marker
///   rendern trotzdem.
/// - Zeigt bewusst KEINE Distanz zum Startpunkt an.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.config, this.tracking});

  final EventConfig? config;

  /// Optional injizierbar (Tests); default: [AppServices.instance.tracking].
  final TrackingService? tracking;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  TrackingService get _tracking =>
      widget.tracking ?? AppServices.instance.tracking;

  List<LatLng> _track = const [];
  bool _loaded = false;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    _loadTrack();
    // Neue Punkte nachladen (kein Per-Punkt-Event; moderates Intervall).
    _reloadTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadTrack();
    });
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    super.dispose();
  }

  /// Lädt alle lokalen Punkte (chronologisch); nur echte Punkte, keine
  /// Interpolation. Bei jedem neuen Tracking-Punkt neu geladen.
  Future<void> _loadTrack() async {
    final db = AppServices.instance.db;
    final rows = await (db.select(db.points)
          ..orderBy([(u) => OrderingTerm.asc(u.recordedAt)]))
        .get();
    if (!mounted) return;
    setState(() {
      _track = [for (final r in rows) LatLng(r.lat, r.lng)];
      _loaded = true;
    });
  }

  LatLng? get _currentPosition {
    final raw = _tracking.lastRawPosition;
    if (raw != null) return LatLng(raw.latitude, raw.longitude);
    if (_track.isNotEmpty) return _track.last;
    return null;
  }

  /// Startpunkt nur, wenn die Route bereits enthüllt wurde und das Event
  /// Koordinaten liefert (null-tolerant — kein Crash ohne Koordinaten).
  LatLng? _startPoint(EventConfig? config, DateTime now) {
    if (config == null || config.isBeforeReveal(now)) return null;
    final lat = config.startLat;
    final lng = config.startLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final now = DateTime.now();
    final start = _startPoint(config, now);
    final current = _currentPosition;

    // Karte: Startpunkt (falls bekannt), sonst aktuelle Position, sonst
    // erster Track-Punkt; ohne Koordinaten neutraler Fallback-Zoom.
    final center = start ?? current ?? (_track.isNotEmpty ? _track.first : null);

    // Peilung Start -> aktuelle Position für den Richtungs-Pfeil.
    double? bearing;
    if (start != null && current != null) {
      bearing = Geo.bearingDeg(
          start.latitude, start.longitude, current.latitude, current.longitude);
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center ?? const LatLng(51.165691, 10.451526),
            initialZoom: center != null ? 15.0 : 6.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.example.stepbystep',
            ),
            PolylineLayer(
              polylines: [
                if (_track.length >= 2)
                  Polyline(
                    points: _track,
                    strokeWidth: 4,
                    color: Colors.blue,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (start != null)
                  Marker(
                    point: start,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.flag, color: Colors.green, size: 32),
                  ),
                if (current != null)
                  Marker(
                    point: current,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.my_location,
                        color: Colors.red, size: 32),
                  ),
              ],
            ),
          ],
        ),
        if (!_loaded)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (bearing != null)
          Positioned(
            top: 12,
            right: 12,
            child: _BearingArrow(bearingDeg: bearing),
          ),
      ],
    );
  }
}

/// Kleiner Richtungs-Pfeil (Start -> aktuelle Position), rein dekorativ.
class _BearingArrow extends StatelessWidget {
  const _BearingArrow({required this.bearingDeg});

  /// 0 = Norden, 90 = Osten (Azimut in Grad).
  final double bearingDeg;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(
          painter: _ArrowPainter(rotationRad: bearingDeg * math.pi / 180.0),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.rotationRad});

  final double rotationRad;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final c = size.center(Offset.zero);
    final len = size.shortestSide / 2 - 2;
    final tip = Offset(
      c.dx + math.sin(rotationRad) * len,
      c.dy - math.cos(rotationRad) * len,
    );
    final left = Offset(
      c.dx + math.sin(rotationRad + 2.5) * (len * 0.6),
      c.dy - math.cos(rotationRad + 2.5) * (len * 0.6),
    );
    final right = Offset(
      c.dx + math.sin(rotationRad - 2.5) * (len * 0.6),
      c.dy - math.cos(rotationRad - 2.5) * (len * 0.6),
    );

    canvas.drawCircle(c, 2.5, paint);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.rotationRad != rotationRad;
}
