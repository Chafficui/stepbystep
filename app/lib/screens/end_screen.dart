import 'package:flutter/material.dart';

import '../brand/sbs_colors.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
import '../tracking/tracking_controller.dart';

/// Abschluss-Seite nach Event-Ende (inline im Event-Screen eingebettet).
///
/// WICHTIG: Das Tracking läuft bewusst WEITER (Daten für die Abholung),
/// bis der Nutzer explizit „Tracking beenden" drückt.
class EndScreenBody extends StatelessWidget {
  const EndScreenBody({
    super.key,
    required this.tracking,
    required this.isRunning,
  });

  final TrackingController tracking;
  final bool isRunning;

  Future<void> _stopTracking(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tracking beenden'),
        content: const Text(
            'Soll die Aufzeichnung jetzt wirklich beendet werden? Die '
            'gesammelten Daten bleiben für die Abholung erhalten.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Beenden')),
        ],
      ),
    );
    if (confirm == true) await tracking.stop();
  }

  @override
  Widget build(BuildContext context) {
    return SbsCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TickRow(count: 5, lit: 5),
          const SizedBox(height: 16),
          const SbsHeading('Das Event ist beendet.', size: 26),
          const SizedBox(height: 10),
          Text(
            'Danke fürs Mitmachen! Check-ins werden nicht mehr benötigt.',
            style: SbsText.body(weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Die Ortsaufzeichnung läuft weiter, damit deine Position für die '
            'Abholung bekannt bleibt.',
            style: SbsText.body(color: SbsColors.fgMuted),
          ),
          const SizedBox(height: 20),
          if (isRunning)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Tracking beenden'),
              onPressed: () => _stopTracking(context),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: SbsColors.fgMuted),
                const SizedBox(width: 8),
                Text('Tracking beendet.',
                    style: SbsText.body(color: SbsColors.fgMuted)),
              ],
            ),
        ],
      ),
    );
  }
}
