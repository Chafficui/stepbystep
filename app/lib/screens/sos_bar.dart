import 'dart:async';

import 'package:flutter/material.dart';

import '../brand/sbs_colors.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';

/// Schlanke, auf jedem Tab sichtbare SOS-Leiste mit Halte-Auslösung (2 s).
///
/// Das Halten füllt einen Lünetten-Ring; Loslassen vor Ablauf setzt zurück
/// (nichts passiert). Die Statuszeile zeigt „gesendet" bzw. „gespeichert".
class SosBar extends StatelessWidget {
  const SosBar({
    super.key,
    required this.onTriggered,
    this.statusText,
    this.statusSent = false,
  });

  final VoidCallback onTriggered;

  /// Statuszeile zum zuletzt ausgelösten Alarm (null = keine).
  final String? statusText;
  final bool statusSent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SbsColors.surface,
        border: Border(top: BorderSide(color: SbsColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HoldToTriggerButton(onTriggered: onTriggered),
          if (statusText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(statusSent ? Icons.check_circle : Icons.schedule,
                      size: 14,
                      color: statusSent ? SbsColors.ok : SbsColors.warn),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusText!,
                      style: SbsText.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: statusSent ? SbsColors.ok : SbsColors.warn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// SOS-Halte-Button: Auslösen erst nach 2 Sekunden Halten. Loslassen oder
/// Abbruch vorher setzt den Fortschritt zurück (nichts passiert).
class HoldToTriggerButton extends StatefulWidget {
  const HoldToTriggerButton({super.key, required this.onTriggered});

  final VoidCallback onTriggered;
  static const holdDuration = Duration(seconds: 2);

  @override
  State<HoldToTriggerButton> createState() => _HoldToTriggerButtonState();
}

class _HoldToTriggerButtonState extends State<HoldToTriggerButton> {
  static const int _tickMs = 50;

  Timer? _timer;
  double _progress = 0.0;
  bool _fired = false;

  bool get _holding => _timer != null;

  void _start() {
    if (_holding) return;
    setState(() {
      _progress = 0.0;
      _fired = false;
    });
    _timer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (t) {
        final p = (t.tick * _tickMs) /
            HoldToTriggerButton.holdDuration.inMilliseconds;
        if (p >= 1.0) {
          _cancelTimer();
          if (mounted) {
            setState(() {
              _progress = 1.0;
              _fired = true;
            });
          }
          widget.onTriggered();
          // Nach kurzer Anzeige zurücksetzen.
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_holding) setState(() => _progress = 0.0);
          });
        } else if (mounted) {
          setState(() => _progress = p);
        }
      },
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _cancel() {
    if (!_holding) return;
    _cancelTimer();
    if (mounted && !_fired) {
      setState(() => _progress = 0.0);
    }
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _progress > 0;
    return Semantics(
      label: 'SOS senden: zwei Sekunden gedrückt halten',
      button: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _cancel(),
        onPointerCancel: (_) => _cancel(),
        child: Stack(
          children: [
            // Hintergrund füllt sich von links mit Signalfarbe.
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _progress.clamp(0.0, 1.0),
                  child: Container(
                      color: SbsColors.signal.withValues(alpha: 0.16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  StopwatchRing(
                    size: 52,
                    progress: _progress,
                    color: SbsColors.signal,
                    strokeWidth: 4,
                    ticks: 0,
                    sweepOnAppear: false,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? SbsColors.signal : Colors.transparent,
                        border: Border.all(
                            color: SbsColors.signal, width: 1.5),
                      ),
                      child: Text(
                        'SOS',
                        style: SbsText.display(13,
                            color: active
                                ? SbsColors.onFg
                                : SbsColors.signal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (_holding ? 'Weiter halten …' : 'SOS halten (2 s)')
                              .toUpperCase(),
                          style: SbsText.display(16,
                              color: active
                                  ? SbsColors.signal
                                  : SbsColors.fg),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Bei akuter Gefahr zuerst 112 anrufen!',
                          style: SbsText.body(
                              size: 12.5, color: SbsColors.fgMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
