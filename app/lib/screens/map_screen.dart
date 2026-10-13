import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../api/api_client.dart';
import '../brand/sbs_colors.dart';
import '../brand/sbs_logo.dart';
import '../core/geo.dart';
import '../core/track_merge.dart';
import '../models/event_config.dart';
import '../services/team_photo_service.dart';
import '../state/services.dart';
import '../tracking/tracking_service.dart';

/// Holt Team-Punkte vom Server (`since` = letzter bekannter Punkt).
typedef TrackFetcher = Future<List<TrackPoint>> Function(DateTime? since);

/// Liefert die lokal gespeicherten Punkte (aufsteigend).
typedef LocalTrackLoader = Future<List<TrackPoint>> Function();

/// Karte (OpenStreetMap) mit der Team-Spur, dem aktuellen Standpunkt
/// (Teamfoto als Pin) und dem Startpunkt (nur nach Enthüllung).
///
/// - Spur: Server-Spur des Teams (`/api/my-track`, alle Geräte, alle 30 s
///   inkrementell) + lokale Punkte, die neuer sind als der letzte
///   Server-Punkt (offline / noch nicht gesendet). KEINE Interpolation.
/// - Funktioniert offline: Tiles bleiben ggf. leer, Polylinie/Marker
///   rendern trotzdem (dann nur mit lokalen Punkten).
/// - Zeigt bewusst KEINE Distanz zum Startpunkt an.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.config,
    this.tracking,
    this.photo,
    this.fetchTrack,
    this.loadLocal,
  });

  final EventConfig? config;

  /// Optional injizierbar (Tests); default: [AppServices.instance.tracking].
  final TrackingService? tracking;

  /// Teamfoto für den Pin; default: [AppServices.instance.teamPhoto].
  final ValueListenable<TeamPhotoState>? photo;

  /// Server-Spur / lokale Punkte; default: echte API bzw. drift-DB.
  final TrackFetcher? fetchTrack;
  final LocalTrackLoader? loadLocal;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  TrackingService? get _tracking =>
      widget.tracking ?? AppServices.instanceOrNull?.tracking;

  ValueListenable<TeamPhotoState>? get _photo =>
      widget.photo ?? AppServices.instanceOrNull?.teamPhoto.state;

  final MapController _map = MapController();
  bool _mapReady = false;

  List<TrackPoint> _server = const [];
  List<TrackPoint> _local = const [];
  List<TrackPoint> _merged = const [];
  bool _loaded = false;
  bool _fitted = false;

  /// Folgt die Kamera der Position? Wird bei Nutzer-Gesten abgeschaltet.
  bool _follow = true;
  LatLng? _lastCentered;

  Timer? _localTimer;
  Timer? _serverTimer;

  @override
  void initState() {
    super.initState();
    _photo?.addListener(_onPhoto);
    _loadLocal();
    _loadServer();
    // Lokale Punkte moderat nachladen, Server-Spur alle 30 s.
    _localTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _loadLocal());
    _serverTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadServer());
  }

  @override
  void dispose() {
    _photo?.removeListener(_onPhoto);
    _localTimer?.cancel();
    _serverTimer?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onPhoto() {
    if (mounted) setState(() {});
  }

  Future<List<TrackPoint>> _defaultLocal() async {
    final db = AppServices.instance.db;
    final rows = await (db.select(db.points)
          ..orderBy([(u) => OrderingTerm.asc(u.recordedAt)]))
        .get();
    return [
      for (final r in rows)
        TrackPoint(
          lat: r.lat,
          lng: r.lng,
          recordedAt:
              DateTime.fromMillisecondsSinceEpoch(r.recordedAt, isUtc: true),
        ),
    ];
  }

  Future<List<TrackPoint>> _defaultFetch(DateTime? since) async {
    final services = AppServices.instance;
    final token = await services.session.token;
    if (token == null || token.isEmpty) return const [];
    try {
      return await services.api.getMyTrack(token, since: since);
    } on AuthException {
      AppServices.onAuthExpired?.call();
      rethrow;
    }
  }

  /// Lädt alle lokalen Punkte (chronologisch); nur echte Punkte.
  Future<void> _loadLocal() async {
    try {
      final pts = await (widget.loadLocal ?? _defaultLocal)();
      if (!mounted) return;
      _local = pts;
      _remerge();
    } catch (_) {
      if (mounted && !_loaded) setState(() => _loaded = true);
    }
  }

  /// Inkrementeller Server-Abruf; Fehler (offline) werden still ignoriert,
  /// die lokalen Punkte tragen die Karte dann allein.
  Future<void> _loadServer() async {
    try {
      final since = TrackMerge.since(_server);
      final fresh = await (widget.fetchTrack ?? _defaultFetch)(since);
      if (!mounted) return;
      _server = TrackMerge.mergeServer(_server, fresh);
      _remerge();
    } catch (_) {
      // offline / Serverfehler — lokale Punkte reichen.
    }
  }

  void _remerge() {
    setState(() {
      _merged = TrackMerge.withLocal(_server, _local);
      _loaded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyCamera());
  }

  LatLng? get _currentPosition {
    final raw = _tracking?.lastRawPosition;
    if (raw != null) return LatLng(raw.latitude, raw.longitude);
    if (_merged.isNotEmpty) {
      return LatLng(_merged.last.lat, _merged.last.lng);
    }
    return null;
  }

  /// Erst-Ausschnitt: ganze Spur; danach der Position folgen (solange der
  /// Nutzer die Karte nicht selbst bewegt hat).
  void _applyCamera() {
    if (!mounted || !_mapReady) return;
    final cur = _currentPosition;
    if (!_fitted) {
      if (_merged.length >= 2) {
        _fitted = true;
        _map.fitCamera(CameraFit.coordinates(
          coordinates: [for (final p in _merged) LatLng(p.lat, p.lng)],
          padding: const EdgeInsets.fromLTRB(48, 96, 48, 96),
          maxZoom: 17,
        ));
        _lastCentered = cur;
        return;
      }
      if (cur != null) {
        _fitted = true;
        _map.move(cur, 16);
        _lastCentered = cur;
        return;
      }
      return;
    }
    if (_follow && cur != null && cur != _lastCentered) {
      _lastCentered = cur;
      _map.move(cur, _map.camera.zoom);
    }
  }

  void _recenter() {
    final cur = _currentPosition;
    if (cur == null) return;
    setState(() => _follow = true);
    _lastCentered = cur;
    _map.move(cur, math.max(_map.camera.zoom, 16));
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
    return MapView(
      track: [for (final p in _merged) LatLng(p.lat, p.lng)],
      start: _startPoint(config, now),
      current: _currentPosition,
      loaded: _loaded,
      photoBytes: _photo?.value.bytes,
      controller: _map,
      following: _follow,
      onMapReady: () {
        _mapReady = true;
        _applyCamera();
      },
      onUserMoved: () {
        if (_follow) setState(() => _follow = false);
      },
      onRecenter: _recenter,
    );
  }
}

/// Präsentation der Karte (reine Daten, testbar). Dunkle Kacheln via
/// invertierter Graustufen-Matrix; Attribution bleibt sichtbar.
class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.track,
    required this.start,
    required this.current,
    required this.loaded,
    this.photoBytes,
    this.controller,
    this.following = true,
    this.onMapReady,
    this.onUserMoved,
    this.onRecenter,
  });

  final List<LatLng> track;
  final LatLng? start;
  final LatLng? current;
  final bool loaded;

  /// Teamfoto als Pin; null = Logo-Fallback.
  final Uint8List? photoBytes;
  final MapController? controller;
  final bool following;
  final VoidCallback? onMapReady;
  final VoidCallback? onUserMoved;
  final VoidCallback? onRecenter;

  /// Invertiert + entsättigt + abgedunkelt: OSM-Kacheln im Dunkel-Look.
  static const ColorFilter darkTiles = ColorFilter.matrix(<double>[
    -0.19, -0.64, -0.065, 0, 232, //
    -0.19, -0.64, -0.065, 0, 233, //
    -0.19, -0.64, -0.065, 0, 230, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final center = current ??
        start ??
        (track.isNotEmpty ? track.last : null);

    // Peilung Start -> aktuelle Position für den Richtungs-Pfeil.
    double? bearing;
    if (start != null && current != null) {
      bearing = Geo.bearingDeg(start!.latitude, start!.longitude,
          current!.latitude, current!.longitude);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: center ?? const LatLng(51.165691, 10.451526),
            initialZoom: center != null ? 15.0 : 6.0,
            backgroundColor: SbsColors.bg,
            onMapReady: onMapReady,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) onUserMoved?.call();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.example.stepbystep',
              tileBuilder: (context, tile, image) =>
                  ColorFiltered(colorFilter: darkTiles, child: tile),
            ),
            PolylineLayer(
              polylines: [
                if (track.length >= 2)
                  Polyline(
                    points: track,
                    strokeWidth: 4,
                    color: SbsColors.fg,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (start != null)
                  Marker(
                    point: start!,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.flag,
                        color: SbsColors.ok, size: 32),
                  ),
                if (current != null)
                  Marker(
                    point: current!,
                    width: TeamPin.width,
                    height: TeamPin.height,
                    // Spitze des Pins sitzt auf der Koordinate.
                    alignment: Alignment.topCenter,
                    child: TeamPin(photoBytes: photoBytes),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap-Mitwirkende'),
              backgroundColor: Color(0xCC050605),
            ),
          ],
        ),
        if (!loaded)
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
        if (onRecenter != null)
          Positioned(
            right: 12,
            bottom: 40,
            child: Tooltip(
              message: 'Auf mich zentrieren',
              child: Material(
                color: SbsColors.surface,
                shape: CircleBorder(
                  side: BorderSide(
                      color: following ? SbsColors.fg : SbsColors.lineStrong),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: current == null ? null : onRecenter,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                        following ? Icons.my_location : Icons.location_searching,
                        size: 24,
                        color: following ? SbsColors.fg : SbsColors.fgMuted),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Positions-Pin: rundes Teamfoto mit knochenweißem Ring, Schatten und
/// kleiner Spitze. Ohne Foto: SBS24-Logo im dunklen Kreis.
class TeamPin extends StatelessWidget {
  const TeamPin({super.key, this.photoBytes});

  static const double diameter = 52;
  static const double width = diameter;
  static const double height = diameter + 9;

  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Spitze (Dreieck) unter dem Kreis.
          const Positioned(
            bottom: 0,
            child: CustomPaint(
              size: Size(16, 12),
              painter: _PinTipPainter(),
            ),
          ),
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SbsColors.surface,
              border: Border.all(color: SbsColors.fg, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Image.memory(bytes,
                    fit: BoxFit.cover, cacheWidth: 160, gaplessPlayback: true)
                : const Center(child: SbsLogo(width: 30)),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  const _PinTipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0xFF000000), 3, true);
    canvas.drawPath(path, Paint()..color = SbsColors.fg);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) => false;
}

/// Kleiner Richtungs-Pfeil (Start -> aktuelle Position), rein dekorativ.
class _BearingArrow extends StatelessWidget {
  const _BearingArrow({required this.bearingDeg});

  /// 0 = Norden, 90 = Osten (Azimut in Grad).
  final double bearingDeg;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SbsColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: SbsColors.lineStrong),
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
      ..color = SbsColors.fg
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
