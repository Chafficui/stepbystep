import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/session_store.dart';
import 'onboarding_screen.dart';

/// Team-Beitritt per Code + Anzeigename.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.sessionStore, this.onJoined});

  final SessionStore sessionStore;
  final VoidCallback? onJoined;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _api = ApiClient();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Bitte Team-Code und Namen eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deviceId = await widget.sessionStore.getOrCreateDeviceId();
      final result = await _api.join(
        code: code,
        displayName: name,
        deviceId: deviceId,
      );
      await widget.sessionStore.saveSession(
        token: result.token,
        teamName: result.teamName,
        displayName: result.displayName,
      );
      // Sitzung gespeichert; lokale Daten bleiben bei späterem 401 erhalten.
      if (!mounted) return;
      widget.onJoined?.call();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingScreen(sessionStore: widget.sessionStore),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Verbindung fehlgeschlagen. Bitte erneut versuchen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team beitreten')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Team-Code',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'z. B. ABC123',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dein Name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Anzeigename im Team',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _join,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Beitreten'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Datenschutz-Hinweis: Während des Events werden dein '
                  'Standort (GPS), Akkustand und deine Check-in-Fotos bzw. '
                  '-Videos erfasst. Diese Daten sind nur für dein eigenes '
                  'Team und die Organisation sichtbar – nicht für andere '
                  'Teilnehmer. Nach dem Event kannst du im Team verlangen, '
                  'dass die Daten gelöscht werden.'
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


