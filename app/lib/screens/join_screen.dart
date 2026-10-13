import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../brand/sbs_colors.dart';
import '../brand/sbs_logo.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
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
  bool _codeInvalid = false;
  bool _nameInvalid = false;

  static const int codeLength = 8;

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
      setState(() {
        _error = 'Bitte Team-Code und Namen eingeben.';
        _codeInvalid = code.isEmpty;
        _nameInvalid = name.isEmpty;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _codeInvalid = false;
      _nameInvalid = false;
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
    final children = <Widget>[
      const Center(child: SbsLogo(width: 132)),
      const SizedBox(height: 28),
      const SbsHeading('Team beitreten', size: 32),
      const SizedBox(height: 8),
      Text(
        'Gib den Code deines Teams und deinen Namen ein.',
        style: SbsText.body(color: SbsColors.fgMuted),
      ),
      const SizedBox(height: 28),
      const SbsLabel('Team-Code'),
      const SizedBox(height: 8),
      TextField(
        controller: _codeController,
        enabled: !_busy,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        maxLength: codeLength,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
          const _UpperCaseFormatter(),
          LengthLimitingTextInputFormatter(codeLength),
        ],
        style: SbsText.number(30).copyWith(letterSpacing: 8),
        cursorColor: SbsColors.fg,
        onChanged: (_) {
          if (_codeInvalid) setState(() => _codeInvalid = false);
        },
        decoration: InputDecoration(
          hintText: 'ABC12345',
          hintStyle: SbsText.number(30, color: SbsColors.fgFaint)
              .copyWith(letterSpacing: 8),
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          errorText: _codeInvalid ? 'Bitte Team-Code eingeben.' : null,
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _codeController,
          builder: (context, v, _) =>
              TickRow(count: codeLength, lit: v.text.length, height: 12),
        ),
      ),
      const SizedBox(height: 24),
      const SbsLabel('Dein Name'),
      const SizedBox(height: 8),
      TextField(
        controller: _nameController,
        enabled: !_busy,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _busy ? null : _join(),
        onChanged: (_) {
          if (_nameInvalid) setState(() => _nameInvalid = false);
        },
        style: SbsText.body(size: 18, weight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Anzeigename im Team',
          errorText: _nameInvalid ? 'Bitte Namen eingeben.' : null,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
        onPressed: _busy ? null : _join,
        child: _busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: SbsColors.fg),
              )
            : Text('Beitreten'.toUpperCase(),
                style: SbsText.display(18, color: SbsColors.onFg)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 16),
        SbsCard(
          borderColor: SbsColors.signal,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline,
                  size: 20, color: SbsColors.signal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: SbsText.body(
                      weight: FontWeight.w600, color: SbsColors.signal),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 28),
      SbsCard(
        color: SbsColors.surface,
        padding: const EdgeInsets.all(14),
        child: Text(
          'Datenschutz-Hinweis: Während des Events werden dein '
          'Standort (GPS), Akkustand, deine Check-in-Fotos bzw. '
          '-Videos und das Teamfoto erfasst. Diese Daten sind nur für '
          'dein eigenes Team und die Organisation sichtbar – nicht für '
          'andere Teilnehmer. Das Teamfoto wird zusammen mit den '
          'Event-Daten gelöscht. Nach dem Event kannst du im Team '
          'verlangen, dass die Daten gelöscht werden.',
          style: SbsText.body(size: 12, color: SbsColors.fgMuted),
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sbsStagger(children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wandelt Eingaben in Großbuchstaben um (Team-Codes sind GROSS).
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
