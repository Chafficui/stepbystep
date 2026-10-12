import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/battery_optimization.dart';
import '../state/session_store.dart';
import 'event_screen.dart';

/// Schritt-für-Schritt Berechtigungs-Checkliste mit Live-Status.
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

enum _PermStatus { granted, denied, undetermined }

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  _PermStatus _locationAlways = _PermStatus.undetermined;
  _PermStatus _notifications = _PermStatus.undetermined;
  _PermStatus _camera = _PermStatus.undetermined;
  _PermStatus _microphone = _PermStatus.undetermined;
  _PermStatus _battery = _PermStatus.undetermined;
  bool _isAndroid = false;

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
    setState(() {
      _locationAlways = _map(always);
      _notifications = _map(notif);
      _camera = _map(cam);
      _microphone = _map(mic);
      _battery = battery.isGranted
          ? _PermStatus.granted
          : _PermStatus.undetermined;
    });
  }

  _PermStatus _map(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return _PermStatus.granted;
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return _PermStatus.denied;
      default:
        return _PermStatus.undetermined;
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

  Widget _tile(
    String title,
    String explanation,
    _PermStatus status,
    VoidCallback onRequest, {
    bool isBlocker = false,
  }) {
    final (icon, color) = switch (status) {
      _PermStatus.granted => (Icons.check_circle, Colors.green),
      _PermStatus.denied => (Icons.cancel, Colors.red),
      _PermStatus.undetermined => (Icons.help_outline, Colors.orange),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(explanation),
        isThreeLine: true,
        trailing: status == _PermStatus.granted
            ? null
            : FilledButton.tonal(
                onPressed: onRequest,
                child: const Text('Erlauben'),
              ),
      ),
    );
  }

  bool get _allGranted =>
      _locationAlways == _PermStatus.granted &&
      _notifications == _PermStatus.granted &&
      _camera == _PermStatus.granted &&
      _microphone == _PermStatus.granted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einrichtung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Damit die Ortung im Hintergrund zuverlässig funktioniert, '
            'braucht die App ein paar Berechtigungen. Bitte alle Punkte '
            'erledigen:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          _tile(
            '1. Standort „Immer"',
            'Die App muss deine Position auch auf dem Sperrbildschirm '
            'aufzeichnen können. Wähle im Systemdialog bzw. in den '
            'Einstellungen „Immer erlauben". Ohne diese Berechtigung '
            'kannst du das Tracking nicht starten.',
            _locationAlways,
            _requestLocation,
            isBlocker: true,
          ),
          _tile(
            '2. Benachrichtigungen',
            'Der Benachrichtigungs-Hinweis zum Check-in-Fenster und die '
            'andauernde Tracking-Anzeige erscheinen als '
            'Benachrichtigung.',
            _notifications,
            () async {
              await Permission.notification.request();
              await _refresh();
            },
          ),
          _tile(
            '3. Kamera & Mikrofon',
            'Für Foto- und Video-Check-ins braucht die App Zugriff auf '
            'Kamera und Mikrofon. Die Medien werden nur im Event '
            'verwendet.',
            (_camera == _PermStatus.granted && _microphone == _PermStatus.granted)
                ? _PermStatus.granted
                : _PermStatus.undetermined,
            () async {
              await [Permission.camera, Permission.microphone].request();
              await _refresh();
            },
          ),
          if (_isAndroid)
            _tile(
              '4. Akku-Optimierung ausnehmen (Android)',
              'Android beendet sonst im Hintergrund laufende Apps. Bitte '
              'in den App-Info-Einstellungen „Akku" → „Unbeschränkt" '
              'wählen, damit die Ortsaufzeichnung nicht abbricht.',
              _battery,
              _requestBattery,
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _allGranted
                ? () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            EventScreen(sessionStore: widget.sessionStore),
                      ),
                    )
                : null,
            child: const Text('Weiter zum Event'),
          ),
        ],
      ),
    );
  }
}
