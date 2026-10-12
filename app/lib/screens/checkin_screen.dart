import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/slot_calc.dart';
import '../db/app_database.dart';
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

  String _fmtLocal(DateTime utc) =>
      DateFormat('dd.MM. HH:mm').format(utc.toLocal());

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final now = DateTime.now().toUtc();
    final over = config.isOver(now);
    final nextDue = _nextDue();
    final slot = SlotCalc.slotFor(now, config.startTime, config.checkinIntervalMin);

    return Center(
      child: ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextDue == null
                        ? 'Kein weiterer Check-in fällig'
                        : 'Nächster Check-in fällig: ${_fmtLocal(nextDue)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Aktueller Slot: $slot'),
                  Text('Offene Check-ins: ${_stats.unsentCheckins}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (over) ...[
            const Text(
              'Das Event ist beendet – Check-ins werden nicht mehr '
              'benötigt.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
              ),
              icon: const Icon(Icons.photo_camera, size: 32),
              label: const Text('Foto aufnehmen', style: TextStyle(fontSize: 20)),
              onPressed: _capturing ? null : () => _capture('photo'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
              ),
              icon: const Icon(Icons.videocam, size: 32),
              label: const Text('Video aufnehmen (max. 15 Sek.)',
                  style: TextStyle(fontSize: 20)),
              onPressed: _capturing ? null : () => _capture('video'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nur Kamera — keine Galerie. Das Video wird maximal 15 '
              'Sekunden lang aufgenommen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (_lastCheckinId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  (_lastCheckinSent ?? false)
                      ? 'Check-in gesendet ✓'
                      : 'Check-in gespeichert – wird gesendet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (_lastCheckinSent ?? false)
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
