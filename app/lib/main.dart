import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'brand/sbs_colors.dart';
import 'brand/sbs_logo.dart';
import 'brand/sbs_theme.dart';
import 'brand/sbs_widgets.dart';
import 'config/api_config.dart';
import 'screens/join_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/services.dart';
import 'state/session_store.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('de_DE', null);
  Intl.defaultLocale = 'de_DE';
  AppServices.onAuthExpired = _handleAuthExpired;
  unawaited(_bootstrap());
  runApp(const StepByStepApp());
}

/// Service-Start + Auto-Resume: Upload-Service läuft, sobald der Prozess
/// lebt; Tracking wird fortgesetzt, wenn `tracking_active` noch gesetzt war.
Future<void> _bootstrap() async {
  final services = await AppServices.init();
  services.upload.start();

  final active = await services.session.getTrackingActive();
  final hasSession = await services.session.hasSession();
  if (active && hasSession) {
    // Still fortsetzen (auch ohne geöffneten Event-Screen).
    await services.tracking.start();
  }
}

/// 401 vom Server: zurück zum Join-Screen. Die drift-Datenbank und
/// ausstehende Medien bleiben bewusst erhalten.
void _handleAuthExpired() {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final store = AppServices.instance.session;
  nav.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => JoinScreen(
        sessionStore: store,
        onJoined: () {
          AppServices.instance.upload.resume();
          nav.pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => OnboardingScreen(sessionStore: store),
            ),
            (route) => false,
          );
        },
      ),
    ),
    (route) => false,
  );
}

class StepByStepApp extends StatelessWidget {
  const StepByStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schritt für Schritt',
      navigatorKey: navigatorKey,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildSbsTheme(),
      darkTheme: buildSbsTheme(),
      themeMode: ThemeMode.dark,
      home: const SplashGate(),
    );
  }
}

/// Logo-Intro beim Kaltstart (einmal), danach weicher Übergang in [RootGate].
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SbsColors.bg,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _introDone
            ? const RootGate(key: ValueKey('root'))
            : Scaffold(
                key: const ValueKey('intro'),
                backgroundColor: SbsColors.bg,
                body: SbsLogoIntro(
                  onFinished: () {
                    if (mounted) setState(() => _introDone = true);
                  },
                ),
              ),
      ),
    );
  }
}

/// Entscheidet beim Start: Fehlerbildschirm (keine API_URL), Join oder
/// Onboarding/Event bei bestehender Sitzung.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final SessionStore _store = SessionStore();
  bool _loading = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final hasSession = await _store.hasSession();
    if (!mounted) return;
    setState(() {
      _hasSession = hasSession;
      _loading = false;
    });
    if (hasSession) {
      // Nach erfolgreichem Join (bzw. Session-Restore) Uploads wieder
      // anwerfen: Der Service wurde beim Start ggf. ohne Token still gelegt
      // und würde sonst erst beim nächsten Timer-Lauf wieder starten.
      final services = AppServices.instanceOrNull;
      if (services != null) services.upload.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.hasApiUrl) {
      return const MissingConfigScreen();
    }
    if (_loading) {
      return const Scaffold(body: Center(child: SbsLogo(width: 120)));
    }
    return _hasSession
        ? OnboardingScreen(sessionStore: _store)
        : JoinScreen(sessionStore: _store, onJoined: _restore);
  }
}

/// Fehlerbildschirm, wenn `--dart-define=API_URL=...` fehlt.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sbsStagger([
                const SbsLogo(width: 120),
                const SizedBox(height: 28),
                const Icon(Icons.error_outline,
                    size: 40, color: SbsColors.signal),
                const SizedBox(height: 12),
                const SbsHeading('Server-URL fehlt (API_URL)',
                    size: 22, align: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'Die App wurde ohne Server-Adresse gebaut. Bitte neu bauen '
                  'mit: --dart-define=API_URL=https://<server>',
                  textAlign: TextAlign.center,
                  style: SbsText.body(color: SbsColors.fgMuted),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
