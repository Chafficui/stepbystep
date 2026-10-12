import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'config/api_config.dart';
import 'screens/join_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('de_DE', null);
  Intl.defaultLocale = 'de_DE';
  runApp(const StepByStepApp());
}

class StepByStepApp extends StatelessWidget {
  const StepByStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schritt für Schritt',
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const RootGate(),
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
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.hasApiUrl) {
      return const MissingConfigScreen();
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Server-URL fehlt (API_URL)',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Die App wurde ohne Server-Adresse gebaut. Bitte neu bauen '
                'mit: --dart-define=API_URL=https://<server>',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

