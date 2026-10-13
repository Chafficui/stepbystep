import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../brand/sbs_logo.dart';
import '../models/event_config.dart';
import '../services/team_photo_service.dart';
import '../state/services.dart';
import '../state/session_store.dart';
import 'event_screen.dart';
import 'team_photo_screen.dart';

/// Pflicht-Teamfoto vor dem Event-Screen.
///
/// Regeln:
/// - Hat das Team ein Foto (auch vom Teamkollegen) → direkt Event-Screen.
/// - Server meldet „kein Foto" und das Event hat NOCH NICHT begonnen →
///   Teamfoto-Screen ohne Überspringen.
/// - Event läuft bereits (Spätbeitritt / Orga-Reset) → Teamfoto-Screen mit
///   „Später" (niemand wird mitten im Event ausgesperrt; SOS bleibt im
///   Event-Screen erreichbar).
/// - Server nicht erreichbar (offline/Fehler) → nicht blockieren, direkt
///   Event-Screen; der Live-Tab zeigt die Erinnerungskarte.
class TeamPhotoGate extends StatefulWidget {
  const TeamPhotoGate({super.key, required this.sessionStore});

  final SessionStore sessionStore;

  @override
  State<TeamPhotoGate> createState() => _TeamPhotoGateState();
}

enum _GateStep { checking, photo, event }

class _TeamPhotoGateState extends State<TeamPhotoGate> {
  _GateStep _step = _GateStep.checking;
  bool _allowSkip = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final services = AppServices.instanceOrNull;
    if (services == null) {
      _go(_GateStep.event);
      return;
    }
    final status = await services.teamPhoto.refresh().timeout(
          const Duration(seconds: 8),
          onTimeout: () => TeamPhotoStatus.unknown,
        );
    if (!mounted) return;
    if (status != TeamPhotoStatus.missing) {
      _go(_GateStep.event);
      return;
    }
    // Foto fehlt: Event-Start entscheidet, ob „Später" erlaubt ist.
    var skip = true; // Event-Zeit unbekannt → nicht aussperren
    try {
      final token = await widget.sessionStore.token;
      final cfg = EventConfig.fromJson(await services.api.getEvent(token));
      skip = !DateTime.now().toUtc().isBefore(cfg.startTime.toUtc());
    } on AuthException {
      AppServices.onAuthExpired?.call();
      return;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _allowSkip = skip;
      _step = _GateStep.photo;
    });
  }

  void _go(_GateStep s) {
    if (mounted) setState(() => _step = s);
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _GateStep.checking:
        return const Scaffold(body: Center(child: SbsLogo(width: 120)));
      case _GateStep.photo:
        return TeamPhotoScreen(
          allowSkip: _allowSkip,
          onDone: () => _go(_GateStep.event),
        );
      case _GateStep.event:
        return EventScreen(sessionStore: widget.sessionStore);
    }
  }
}
