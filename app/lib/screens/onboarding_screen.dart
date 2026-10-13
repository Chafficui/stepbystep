import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../brand/sbs_colors.dart';
import '../brand/sbs_logo.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
import '../services/battery_optimization.dart';
import '../state/session_store.dart';
import 'team_photo_gate.dart';

/// Schrittweise Berechtigungs-Checkliste mit Live-Status.
///
/// Reihenfolge:
/// 1. Standort „Immer" (Blocker – ohne das bleibt „Tracking starten" aus)
/// 2. Benachrichtigungen
/// 3. Kamera & Mikrofon
/// 4. Nur Android: Akku-Optimierung ausnehmen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.sessionStore});

  final SessionStore sessionStore;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum PermStatus { granted, denied, undetermined }

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  PermStatus _locationAlways = PermStatus.undetermined;
  PermStatus _notifications = PermStatus.undetermined;
  PermStatus _camera = PermStatus.undetermined;
  PermStatus _microphone = PermStatus.undetermined;
  PermStatus _battery = PermStatus.undetermined;
  bool _isAndroid = false;
  int _step = 0;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isAndroid = Platform.isAndroid;
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Live-Status: erneut prüfen, wenn die App in den Vordergrund kommt
    // (nachdem der Nutzer die Systemeinstellungen besucht hat).
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final always = await Permission.locationAlways.status;
    final notif = await Permission.notification.status;
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final battery = _isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : PermissionStatus.granted;
    if (!mounted) return;
    final before = _statuses();
    setState(() {
      _locationAlways = _map(always);
      _notifications = _map(notif);
      _camera = _map(cam);
      _microphone = _map(mic);
      _battery = battery.isGranted
          ? PermStatus.granted
          : PermStatus.undetermined;
      // Erster Lauf: zum ersten offenen Schritt springen. Danach nur
      // weiterspringen, wenn der aktuelle Schritt gerade erteilt wurde.
      final now = _statuses();
      if (!_initialised) {
        _initialised = true;
        final firstOpen =
            now.indexWhere((s) => s != PermStatus.granted);
        _step = firstOpen == -1 ? now.length - 1 : firstOpen;
      } else if (_step < now.length &&
          _step < before.length &&
          before[_step] != PermStatus.granted &&
          now[_step] == PermStatus.granted &&
          _step < now.length - 1) {
        _step++;
      }
    });
  }

  PermStatus get _cameraMic =>
      (_camera == PermStatus.granted && _microphone == PermStatus.granted)
          ? PermStatus.granted
          : PermStatus.undetermined;

  List<PermStatus> _statuses() => [
        _locationAlways,
        _notifications,
        _cameraMic,
        if (_isAndroid) _battery,
      ];

  PermStatus _map(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return PermStatus.granted;
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return PermStatus.denied;
      default:
        return PermStatus.undetermined;
    }
  }

  /// Zweistufig auf beiden Plattformen: erst Vordergrund-Standort, dann
  /// Upgrade auf „Immer". Android (ab 11) ignoriert die Anfrage komplett,
  /// wenn Vorder- und Hintergrund-Standort gemeinsam angefragt werden.
  Future<void> _requestLocation() async {
    if (_isAndroid) {
      final foreground = await Permission.location.request();
      if (foreground.isGranted) {
        final always = await Permission.locationAlways.request();
        if (always.isPermanentlyDenied) await openAppSettings();
      } else if (foreground.isPermanentlyDenied) {
        await openAppSettings();
      }
    } else {
      // iOS: "While using" zuerst anfragen, danach gezielt auf "Immer"
      // upgraden (zweiter Systemdialog).
      final whenInUse = await Permission.locationWhenInUse.request();
      if (whenInUse.isGranted) {
        await Permission.locationAlways.request();
      }
    }
    await _refresh();
  }

  Future<void> _requestBattery() async {
    // Android: Battery-Optimierung per System-Intent ausnehmen (Method-
    // Channel); falls das fehlschlägt, Fallback in die App-Einstellungen.
    final ok = await BatteryOptimization.requestIgnoreBatteryOptimizations();
    if (!ok) await Geolocator.openAppSettings();
    await _refresh();
  }

  Future<void> _requestNotifications() async {
    await Permission.notification.request();
    await _refresh();
  }

  Future<void> _requestCameraMic() async {
    await [Permission.camera, Permission.microphone].request();
    await _refresh();
  }

  bool get _allGranted =>
      _locationAlways == PermStatus.granted &&
      _notifications == PermStatus.granted &&
      _camera == PermStatus.granted &&
      _microphone == PermStatus.granted;

  void _finish() => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TeamPhotoGate(sessionStore: widget.sessionStore),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = _statuses();
    final steps = <OnboardingStep>[
      OnboardingStep(
        title: 'Standort „Immer"',
        icon: Icons.location_on_outlined,
        body: 'Die App muss deine Position auch auf dem Sperrbildschirm '
            'aufzeichnen können. Wähle im Systemdialog bzw. in den '
            'Einstellungen „Immer erlauben". Ohne diese Berechtigung '
            'kannst du das Tracking nicht starten.',
        status: st[0],
        required: true,
        onRequest: _requestLocation,
      ),
      OnboardingStep(
        title: 'Benachrichtigungen',
        icon: Icons.notifications_none,
        body: 'Der Benachrichtigungs-Hinweis zum Check-in-Fenster und die '
            'andauernde Tracking-Anzeige erscheinen als Benachrichtigung.',
        status: st[1],
        required: true,
        onRequest: _requestNotifications,
      ),
      OnboardingStep(
        title: 'Kamera & Mikrofon',
        icon: Icons.photo_camera_outlined,
        body: 'Für Foto- und Video-Check-ins braucht die App Zugriff auf '
            'Kamera und Mikrofon. Die Medien werden nur im Event '
            'verwendet.',
        status: st[2],
        required: true,
        onRequest: _requestCameraMic,
      ),
      if (_isAndroid)
        OnboardingStep(
          title: 'Akku-Optimierung ausnehmen',
          icon: Icons.battery_charging_full,
          body: 'Android beendet sonst im Hintergrund laufende Apps. Bitte '
              'in den App-Info-Einstellungen „Akku" → „Unbeschränkt" '
              'wählen, damit die Ortsaufzeichnung nicht abbricht.',
          status: st[3],
          required: false,
          onRequest: _requestBattery,
        ),
    ];
    return OnboardingView(
      steps: steps,
      current: _step.clamp(0, steps.length - 1),
      canFinish: _allGranted,
      onSelect: (i) => setState(() => _step = i),
      onNext: () => setState(() => _step++),
      onFinish: _finish,
    );
  }
}

/// Daten eines Einrichtungsschritts.
class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.icon,
    required this.body,
    required this.status,
    required this.required,
    required this.onRequest,
  });

  final String title;
  final IconData icon;
  final String body;
  final PermStatus status;
  final bool required;
  final VoidCallback onRequest;
}

/// Präsentation der Einrichtung: ein Schritt pro Seite, Strich-Anzeige.
class OnboardingView extends StatelessWidget {
  const OnboardingView({
    super.key,
    required this.steps,
    required this.current,
    required this.canFinish,
    required this.onSelect,
    required this.onNext,
    required this.onFinish,
  });

  final List<OnboardingStep> steps;
  final int current;
  final bool canFinish;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final step = steps[current];
    final granted = step.status == PermStatus.granted;
    final isLast = current == steps.length - 1;
    final doneCount =
        steps.where((s) => s.status == PermStatus.granted).length;

    final (statusIcon, statusColor, statusText) = switch (step.status) {
      PermStatus.granted => (Icons.check_circle, SbsColors.ok, 'Erteilt'),
      PermStatus.denied =>
        (Icons.cancel, SbsColors.signal, 'Abgelehnt – in den Einstellungen ändern'),
      PermStatus.undetermined =>
        (Icons.radio_button_unchecked, SbsColors.warn, 'Noch offen'),
    };

    String primaryLabel;
    VoidCallback? primary;
    if (!granted) {
      primaryLabel = 'Erlauben';
      primary = step.onRequest;
    } else if (!isLast) {
      primaryLabel = 'Weiter';
      primary = onNext;
    } else {
      primaryLabel = 'Weiter zum Event';
      primary = canFinish ? onFinish : null;
    }

    final children = <Widget>[
      Row(
        children: [
          const SbsLogo(width: 44),
          const Spacer(),
          SbsLabel('Schritt ${current + 1} von ${steps.length}'),
        ],
      ),
      const SizedBox(height: 28),
      const SbsHeading('Einrichtung', size: 32),
      const SizedBox(height: 8),
      Text(
        'Damit die Ortung im Hintergrund zuverlässig funktioniert, braucht '
        'die App ein paar Berechtigungen.',
        style: SbsText.body(color: SbsColors.fgMuted),
      ),
      const SizedBox(height: 22),
      // Strich-Anzeige: erledigte Schritte leuchten, aktueller ist markiert.
      Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Transform(
                      transform: Matrix4.skewX(-0.25),
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        height: i == current ? 22 : 14,
                        width: 6,
                        color: steps[i].status == PermStatus.granted
                            ? SbsColors.fg
                            : i == current
                                ? SbsColors.fgMuted
                                : SbsColors.lineStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      SbsCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(step.icon, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: SbsHeading(step.title, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(step.body, style: SbsText.body(size: 15)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText + (step.required ? '' : ' · optional'),
                    style: SbsText.body(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    children: sbsStagger(children),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(58)),
                        onPressed: primary,
                        child: Text(primaryLabel.toUpperCase(),
                            style: SbsText.display(18,
                                color: primary == null
                                    ? SbsColors.fgFaint
                                    : SbsColors.onFg)),
                      ),
                      if (!granted && !step.required && canFinish)
                        TextButton(
                          onPressed: onFinish,
                          child: const Text('Überspringen – weiter zum Event'),
                        ),
                      if (isLast && !canFinish)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Erst alle Pflicht-Schritte erledigen '
                            '($doneCount von ${steps.length}).',
                            textAlign: TextAlign.center,
                            style: SbsText.body(
                                size: 12.5, color: SbsColors.fgFaint),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
