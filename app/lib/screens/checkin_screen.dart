import 'dart:async';

import 'package:flutter/material.dart';

import '../brand/sbs_colors.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
import '../core/slot_calc.dart';
import '../db/app_database.dart';
import '../core/event_time.dart';
import '../models/event_config.dart';
import '../services/checkin_service.dart';
import '../state/services.dart';
import '../tracking/upload_service.dart';

/// Check-in-Tab: nächster fälliger Check-in, aktueller Slot, offene
/// Check-ins in der Queue und Aufnahme über die Kamera (Foto/Video).
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({
    super.key,
    required this.config,
    this.upload,
    this.service,
  });

  final EventConfig config;

  /// Optional injizierbar (Tests); default: [AppServices.instance].
  final UploadService? upload;
  final CheckinService? service;

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  UploadService get _upload => widget.upload ?? AppServices.instance.upload;
  CheckinService get _service =>
      widget.service ??
      CheckinService(
        db: AppServices.instance.db,
        api: AppServices.instance.api,
        upload: widget.upload ?? AppServices.instance.upload,
      );

  UploadStats _stats = const UploadStats(
      unsentPoints: 0, unsentAlerts: 0, unsentCheckins: 0);
  StreamSubscription<UploadStats>? _statsSub;

  /// Zuletzt aufgenommener Check-in (für den Status „wird gesendet/gesendet").
  String? _lastCheckinId;
  bool? _lastCheckinSent;
  bool _capturing = false;
  Timer? _sentPollTimer;

  @override
  void initState() {
    super.initState();
    _stats = _upload.currentStats;
    _statsSub = _upload.stats.listen((s) {
      if (mounted) setState(() => _stats = s);
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _sentPollTimer?.cancel();
    super.dispose();
  }

  /// Nächster fälliger Check-in (erste Erinnerungszeit nach jetzt), null
  /// wenn keine mehr kommen.
  DateTime? _nextDue() {
    final now = DateTime.now().toUtc();
    for (final t in SlotCalc.reminderTimes(widget.config)) {
      if (t.isAfter(now)) return t;
    }
    return null;
  }

  Future<void> _capture(String mediaType) async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final id = await _service.captureCheckin(mediaType: mediaType);
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aufnahme abgebrochen.')),
        );
        return;
      }
      setState(() {
        _lastCheckinId = id;
        _lastCheckinSent = null;
      });
      // Status „gesendet" erkennen: Zeile auf sentAt prüfen (jede Sekunde,
      // bis der Upload sie bestätigt hat).
      _sentPollTimer?.cancel();
      _sentPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final row = await _lookupCheckin(_lastCheckinId!);
        if (!mounted) return;
        final sent = row?.sentAt != null;
        if (sent != _lastCheckinSent) {
          setState(() => _lastCheckinSent = sent);
        }
        if (sent) _sentPollTimer?.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aufnahme fehlgeschlagen (${e.runtimeType}).')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<PendingCheckin?> _lookupCheckin(String id) {
    final db = AppServices.instance.db;
    return (db.select(db.pendingCheckins)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final now = DateTime.now().toUtc();
    return CheckinView(
      nextDue: _nextDue(),
      now: now,
      intervalMin: config.checkinIntervalMin,
      slot: SlotCalc.slotFor(now, config.startTime, config.checkinIntervalMin),
      unsentCheckins: _stats.unsentCheckins,
      over: config.isOver(now),
      capturing: _capturing,
      hasLast: _lastCheckinId != null,
      lastSent: _lastCheckinSent ?? false,
      onCapture: _capture,
    );
  }
}

/// Präsentation des Check-in-Tabs (reine Daten, testbar).
class CheckinView extends StatelessWidget {
  const CheckinView({
    super.key,
    required this.nextDue,
    required this.now,
    required this.intervalMin,
    required this.slot,
    required this.unsentCheckins,
    required this.over,
    required this.capturing,
    required this.hasLast,
    required this.lastSent,
    required this.onCapture,
  });

  final DateTime? nextDue;
  final DateTime now;
  final int intervalMin;
  final int slot;
  final int unsentCheckins;
  final bool over;
  final bool capturing;
  final bool hasLast;
  final bool lastSent;
  final void Function(String mediaType) onCapture;

  @override
  Widget build(BuildContext context) {
    final due = nextDue;
    double progress = 0;
    String countdown = '–';
    if (due != null) {
      var left = due.difference(now);
      if (left.isNegative) left = Duration.zero;
      final total = intervalMin * 60;
      progress = total <= 0 ? 0 : (1 - left.inSeconds / total).clamp(0.0, 1.0);
      final h = left.inHours;
      final m = left.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = left.inSeconds.remainder(60).toString().padLeft(2, '0');
      countdown = '$h:$m:$s';
    }
    final children = <Widget>[
      SbsCard(
        child: Row(
          children: [
            StopwatchRing(
              size: 92,
              progress: progress,
              strokeWidth: 5,
              ticks: 0,
              child: Text(over ? '–' : '#$slot', style: SbsText.number(20)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SbsLabel('Nächster Check-in'),
                  const SizedBox(height: 4),
                  if (due == null)
                    Text('Kein weiterer Check-in fällig',
                        style: SbsText.body(weight: FontWeight.w600))
                  else ...[
                    Text(countdown, style: SbsText.number(30)),
                    const SizedBox(height: 2),
                    Text(
                      'Fällig: '
                      '${fmtEventDateTime(due)}',
                      style: SbsText.body(size: 13, color: SbsColors.fgMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Aktueller Slot: $slot · Offen: $unsentCheckins',
                    style: SbsText.body(size: 13, color: SbsColors.fgMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (over)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Das Event ist beendet – Check-ins werden nicht mehr benötigt.',
            textAlign: TextAlign.center,
            style: SbsText.body(color: SbsColors.fgMuted),
          ),
        )
      else ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(72)),
          icon: const Icon(Icons.photo_camera, size: 28),
          label: Text('Foto aufnehmen'.toUpperCase(),
              style: SbsText.display(18, color: SbsColors.onFg)),
          onPressed: capturing ? null : () => onCapture('photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(72)),
          icon: const Icon(Icons.videocam_outlined, size: 28),
          label: Text('Video (max. 15 Sek.)'.toUpperCase(),
              style: SbsText.display(18)),
          onPressed: capturing ? null : () => onCapture('video'),
        ),
        const SizedBox(height: 12),
        Text(
          'Nur Kamera — keine Galerie. Das Video wird maximal 15 Sekunden '
          'lang aufgenommen.',
          textAlign: TextAlign.center,
          style: SbsText.body(size: 12.5, color: SbsColors.fgFaint),
        ),
        if (hasLast)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SbsCard(
              padding: const EdgeInsets.all(12),
              borderColor: lastSent ? SbsColors.ok : SbsColors.warn,
              child: Row(
                children: [
                  Icon(lastSent ? Icons.check_circle : Icons.schedule,
                      size: 18,
                      color: lastSent ? SbsColors.ok : SbsColors.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lastSent
                          ? 'Check-in gesendet ✓'
                          : 'Check-in gespeichert – wird gesendet',
                      style: SbsText.body(
                        weight: FontWeight.w600,
                        color: lastSent ? SbsColors.ok : SbsColors.warn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: sbsStagger(children),
    );
  }
}
