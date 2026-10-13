import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../brand/sbs_colors.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
import '../models/event_config.dart';
import '../services/team_photo_service.dart';
import '../tracking/tracking_controller.dart';
import '../tracking/upload_service.dart';

/// Momentaufnahme aller Status-Werte (Chips + Detail-Sheet).
class StatusData {
  const StatusData({
    required this.tracking,
    required this.online,
    required this.stats,
    this.batteryPercent,
    this.stale = false,
  });

  final TrackingState tracking;
  final bool online;
  final UploadStats stats;
  final int? batteryPercent;
  final bool stale;

  int get unsentTotal =>
      stats.unsentPoints + stats.unsentAlerts + stats.unsentCheckins;

  bool get running => tracking.kind == TrackingStateKind.running;

  String get trackingLabel {
    switch (tracking.kind) {
      case TrackingStateKind.running:
        return 'Tracking aktiv';
      case TrackingStateKind.stopped:
        return 'Tracking pausiert';
      case TrackingStateKind.error:
        return 'Fehler: ${tracking.message ?? 'unbekannt'}';
    }
  }

  String get lastUploadLabel {
    final t = stats.lastSuccessAt;
    if (t == null) return 'noch keiner';
    return DateFormat('HH:mm').format(t.toLocal());
  }

  @override
  bool operator ==(Object other) =>
      other is StatusData &&
      other.tracking == tracking &&
      other.online == online &&
      other.batteryPercent == batteryPercent &&
      other.stale == stale &&
      other.stats.unsentPoints == stats.unsentPoints &&
      other.stats.unsentAlerts == stats.unsentAlerts &&
      other.stats.unsentCheckins == stats.unsentCheckins &&
      other.stats.lastSuccessAt == stats.lastSuccessAt;

  @override
  int get hashCode => Object.hash(tracking, online, batteryPercent, stale,
      stats.unsentPoints, stats.unsentAlerts, stats.unsentCheckins);
}

String formatHms(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _localTime(DateTime utc) =>
    DateFormat('dd.MM. HH:mm').format(utc.toLocal());

/// Live-Tab: Event-Ring, Tracking-Schalter, Status-Chips, nächster
/// Check-in, Event-Infos und Notfall-Bereich.
class LiveTab extends StatelessWidget {
  const LiveTab({
    super.key,
    required this.config,
    required this.now,
    required this.status,
    required this.onToggleTracking,
    required this.onAbort,
    required this.onRefresh,
    required this.onOpenStatus,
    required this.onOpenCheckin,
    this.nextCheckin,
    this.error,
    this.driftWarning = false,
    this.endSection,
    this.teamPhoto,
    this.onTeamPhoto,
  });

  final EventConfig? config;
  final DateTime now;
  final StatusData status;
  final VoidCallback onToggleTracking;
  final VoidCallback onAbort;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenStatus;
  final VoidCallback onOpenCheckin;

  /// Nächster fälliger Check-in (UTC) oder null.
  final DateTime? nextCheckin;
  final String? error;
  final bool driftWarning;

  /// Abschluss-Inhalt (EndScreenBody), nur nach Event-Ende.
  final Widget? endSection;

  /// Stand des Teamfotos (null = Karte ausgeblendet, z. B. in Tests).
  final TeamPhotoState? teamPhoto;

  /// Öffnet den Teamfoto-Screen (Aufnehmen / Neu aufnehmen).
  final VoidCallback? onTeamPhoto;

  @override
  Widget build(BuildContext context) {
    final cfg = config;
    final over = cfg != null && cfg.isOver(now);
    var i = 0;
    final children = <Widget>[
      if (error != null)
        _Banner(text: error!, color: SbsColors.signal, icon: Icons.error_outline),
      if (driftWarning)
        const _Banner(
          text: 'Uhrzeit des Handys prüfen – sie weicht deutlich von der '
              'Serverzeit ab.',
          color: SbsColors.warn,
          icon: Icons.schedule,
        ),
      if (status.stale)
        const _Banner(
          text: 'Seit 10 Minuten kein neuer Punkt – Tracking prüfen!',
          color: SbsColors.signal,
          icon: Icons.warning_amber_rounded,
        ),
      if (teamPhoto != null && teamPhoto!.missing && !over)
        _TeamPhotoMissingCard(onTap: onTeamPhoto),
      if (cfg == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        _Hero(config: cfg, now: now),
        const SizedBox(height: 20),
        if (!over) _TrackingButton(running: status.running, onTap: onToggleTracking),
        if (!over) const SizedBox(height: 16),
        _ChipsRow(status: status, onTap: onOpenStatus),
        const SizedBox(height: 16),
        if (over && endSection != null) ...[
          endSection!,
          const SizedBox(height: 16),
        ] else ...[
          _NextCheckinCard(
            config: cfg,
            now: now,
            next: nextCheckin,
            onTap: onOpenCheckin,
          ),
          const SizedBox(height: 16),
        ],
        if (teamPhoto != null && !teamPhoto!.missing) ...[
          _TeamPhotoCard(photo: teamPhoto!, onRetake: onTeamPhoto),
          const SizedBox(height: 16),
        ],
        _InfoCard(config: cfg),
      ],
      const SizedBox(height: 28),
      _EmergencySection(onAbort: onAbort),
      const SizedBox(height: 12),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: SbsColors.fg,
      backgroundColor: SbsColors.surface2,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          for (final c in children)
            if (c is SizedBox) c else SlideIn(index: i++, child: c),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SbsCard(
        borderColor: color,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: SbsText.body(
                      size: 14, weight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero: Event-Fortschritt als Stoppuhr-Ring.
class _Hero extends StatelessWidget {
  const _Hero({required this.config, required this.now});

  final EventConfig config;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cfg = config;
    final n = now.toUtc();
    String title;
    String subtitle;
    String center;
    double progress;
    Color color = SbsColors.fg;

    if (cfg.isOver(n)) {
      title = 'Event beendet';
      center = 'Ziel!';
      subtitle = 'Ende: ${_localTime(cfg.endTime)}';
      progress = 1;
      color = SbsColors.fgMuted;
    } else if (cfg.isBeforeReveal(n)) {
      final total = cfg.revealTime.difference(cfg.serverNow);
      final left = cfg.revealTime.difference(n);
      title = 'Enthüllung der Route in';
      center = left.isNegative ? 'Jetzt!' : formatHms(left);
      subtitle = 'Enthüllung: ${_localTime(cfg.revealTime)}';
      progress = total.inSeconds <= 0
          ? 0
          : 1 - left.inSeconds / total.inSeconds;
    } else if (n.isBefore(cfg.startTime.toUtc())) {
      final total = cfg.startTime.difference(cfg.revealTime);
      final left = cfg.startTime.difference(n);
      title = 'Start in';
      center = left.isNegative ? 'Jetzt!' : formatHms(left);
      subtitle = 'Start: ${_localTime(cfg.startTime)}';
      progress = total.inSeconds <= 0
          ? 0
          : 1 - left.inSeconds / total.inSeconds;
    } else {
      final total = cfg.endTime.difference(cfg.startTime);
      final left = cfg.endTime.difference(n);
      title = 'Event endet in';
      center = formatHms(left.isNegative ? Duration.zero : left);
      subtitle = 'Ende: ${_localTime(cfg.endTime)}';
      progress = total.inSeconds <= 0
          ? 1
          : 1 - left.inSeconds / total.inSeconds;
    }
    progress = progress.clamp(0.0, 1.0);

    final w = MediaQuery.sizeOf(context).width;
    final size = (w - 56).clamp(220.0, 300.0);
    return Center(
      child: StopwatchRing(
        size: size,
        progress: progress,
        color: color,
        strokeWidth: 7,
        child: Padding(
          padding: EdgeInsets.all(size * 0.2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SbsLabel(title),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(center, style: SbsText.number(44, color: color)),
              ),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: SbsText.body(size: 13, color: SbsColors.fgMuted)),
              if (!cfg.isOver(n) && !cfg.isBeforeReveal(n) &&
                  !n.isBefore(cfg.startTime.toUtc()))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${(progress * 100).floor()} % geschafft',
                    style: SbsText.body(size: 13, color: SbsColors.fgFaint),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingButton extends StatelessWidget {
  const _TrackingButton({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded,
        size: 28);
    final label = Text(
      (running ? 'Tracking stoppen' : 'Tracking starten').toUpperCase(),
      style: SbsText.display(18, color: running ? SbsColors.fg : SbsColors.onFg),
    );
    if (running) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
        icon: icon,
        label: label,
        onPressed: onTap,
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
      icon: icon,
      label: label,
      onPressed: onTap,
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.status, required this.onTap});

  final StatusData status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = status.tracking.kind;
    final trackColor = switch (t) {
      TrackingStateKind.running => SbsColors.ok,
      TrackingStateKind.stopped => SbsColors.fgFaint,
      TrackingStateKind.error => SbsColors.signal,
    };
    final trackText = switch (t) {
      TrackingStateKind.running => 'Tracking aktiv',
      TrackingStateKind.stopped => 'Pausiert',
      TrackingStateKind.error => 'GPS-Fehler',
    };
    final bat = status.batteryPercent;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusChip(color: trackColor, label: trackText, onTap: onTap),
        StatusChip(
          color: status.online ? SbsColors.ok : SbsColors.signal,
          label: status.online ? 'Online' : 'Offline',
          onTap: onTap,
        ),
        StatusChip(
          color: status.unsentTotal == 0 ? SbsColors.ok : SbsColors.warn,
          label: status.unsentTotal == 0
              ? 'Upload ok'
              : 'Upload: ${status.unsentTotal} offen',
          onTap: onTap,
        ),
        if (bat != null)
          StatusChip(
            color: bat <= 20 ? SbsColors.warn : SbsColors.fgMuted,
            label: 'Akku $bat %',
            onTap: onTap,
          ),
      ],
    );
  }
}

/// Kompakter Status-Chip mit Farbpunkt.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.color,
    required this.label,
    this.onTap,
  });

  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SbsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: SbsColors.lineStrong),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label,
                  style: SbsText.body(size: 13, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextCheckinCard extends StatelessWidget {
  const _NextCheckinCard({
    required this.config,
    required this.now,
    required this.next,
    required this.onTap,
  });

  final EventConfig config;
  final DateTime now;
  final DateTime? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = next;
    final intervalSec = config.checkinIntervalMin * 60;
    Duration? left;
    double progress = 0;
    if (n != null) {
      left = n.difference(now.toUtc());
      if (left.isNegative) left = Duration.zero;
      progress = intervalSec <= 0
          ? 0
          : (1 - left.inSeconds / intervalSec).clamp(0.0, 1.0);
    }
    return Material(
      color: SbsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: SbsColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              StopwatchRing(
                size: 64,
                progress: progress,
                strokeWidth: 4,
                ticks: 0,
                child: const Icon(Icons.photo_camera_outlined, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SbsLabel('Nächster Check-in'),
                    const SizedBox(height: 4),
                    if (n == null)
                      Text('Kein weiterer Check-in fällig',
                          style: SbsText.body(weight: FontWeight.w600))
                    else ...[
                      Text(formatHms(left!), style: SbsText.number(26)),
                      const SizedBox(height: 2),
                      Text('fällig ${_localTime(n)}',
                          style: SbsText.body(
                              size: 13, color: SbsColors.fgMuted)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SbsColors.fgFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Warnkarte: Teamfoto fehlt (Pflicht vor dem Start).
class _TeamPhotoMissingCard extends StatelessWidget {
  const _TeamPhotoMissingCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SbsCard(
        borderColor: SbsColors.warn,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_front_outlined,
                    color: SbsColors.warn, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Teamfoto fehlt – vor dem Start Pflicht',
                      style: SbsText.body(
                          size: 15,
                          weight: FontWeight.w700,
                          color: SbsColors.warn)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ohne Foto erkennt euch die Orga nicht und euer Pin auf der '
              'Karte bleibt leer.',
              style: SbsText.body(size: 13.5, color: SbsColors.fgMuted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SbsColors.warn,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onTap,
              child: Text('Teamfoto aufnehmen'.toUpperCase(),
                  style: SbsText.display(16, color: SbsColors.onFg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Teamfoto-Karte: Vorschau + „Neu aufnehmen".
class _TeamPhotoCard extends StatelessWidget {
  const _TeamPhotoCard({required this.photo, required this.onRetake});

  final TeamPhotoState photo;
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.bytes;
    return SbsCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SbsColors.surface2,
              border: Border.all(color: SbsColors.fg, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes == null
                ? const Icon(Icons.groups_outlined, color: SbsColors.fgFaint)
                : Image.memory(bytes,
                    fit: BoxFit.cover, cacheWidth: 192, gaplessPlayback: true),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SbsLabel('Teamfoto'),
                const SizedBox(height: 4),
                Text('Euer Pin auf der Karte',
                    style: SbsText.body(weight: FontWeight.w600)),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: onRetake,
            child: const Text('Neu aufnehmen'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.config});

  final EventConfig config;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: SbsLabel(k)),
              Text(v, style: SbsText.number(15)),
            ],
          ),
        );
    return SbsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          row('Check-in alle', '${config.checkinIntervalMin} Min'),
          const Divider(),
          row('Check-in-Fenster', '${config.checkinWindowMin} Min'),
          const Divider(),
          row('Orga-Telefon', config.orgaPhone),
        ],
      ),
    );
  }
}

class _EmergencySection extends StatelessWidget {
  const _EmergencySection({required this.onAbort});

  final VoidCallback onAbort;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SbsLabel('Notfall', color: SbsColors.warn),
            SizedBox(width: 12),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Kannst du nicht mehr weiter? Die Orga erfährt deine Position und '
          'holt dich ab.',
          style: SbsText.body(size: 13.5, color: SbsColors.fgMuted),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: SbsColors.warn,
            side: const BorderSide(color: SbsColors.warn),
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Aufgeben und abholen lassen'),
          onPressed: onAbort,
        ),
      ],
    );
  }
}

/// Bottom-Sheet mit den detaillierten Status-Werten.
class StatusSheet extends StatelessWidget {
  const StatusSheet({super.key, required this.data});

  final ValueListenable<StatusData> data;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final s = data.value;
          Widget row(String k, String v, {Color? color}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: SbsLabel(k)),
                    Expanded(
                      flex: 4,
                      child: Text(v,
                          textAlign: TextAlign.right,
                          style: SbsText.body(
                              weight: FontWeight.w600,
                              color: color ?? SbsColors.fg)),
                    ),
                  ],
                ),
              );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SbsHeading('Status', size: 22),
                const SizedBox(height: 8),
                row('Tracking', s.trackingLabel,
                    color: s.running
                        ? SbsColors.ok
                        : s.tracking.kind == TrackingStateKind.error
                            ? SbsColors.signal
                            : null),
                const Divider(),
                row('Netz', s.online ? 'Online' : 'Offline',
                    color: s.online ? SbsColors.ok : SbsColors.signal),
                const Divider(),
                row('Ungesendete Punkte', '${s.stats.unsentPoints}'),
                row('Ungesendete Alarme', '${s.stats.unsentAlerts}'),
                row('Ungesendete Check-ins', '${s.stats.unsentCheckins}'),
                const Divider(),
                row('Letzter Upload', s.lastUploadLabel),
                if (s.batteryPercent != null) ...[
                  const Divider(),
                  row('Akkustand', '${s.batteryPercent} %',
                      color: s.batteryPercent! <= 20 ? SbsColors.warn : null),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
