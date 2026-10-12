import 'package:flutter/material.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Das Event ist beendet.',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Danke fürs Mitmachen! Check-ins werden nicht mehr '
                'benötigt.'),
            const Text(
                'Die Ortsaufzeichnung läuft weiter, damit deine Position '
                'für die Abholung bekannt bleibt.'),
            const SizedBox(height: 16),
            if (isRunning)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.stop),
                label:
                    const Text('Tracking beenden', style: TextStyle(fontSize: 18)),
                onPressed: () => _stopTracking(context),
              )
            else
              const Text('Tracking beendet.'),
          ],
        ),
      ),
    );
  }
}
