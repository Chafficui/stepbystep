import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../state/services.dart';

/// Rangliste-Tab: eigener Platz des Teams (NICHT andere Teams, keine
/// Kilometer-Anzeige).
class RankScreen extends StatefulWidget {
  const RankScreen({super.key, this.api, this.token});

  /// Optional injizierbar (Tests); default: [AppServices.instance].
  final ApiClient? api;
  final String? token;

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  ApiClient get _api => widget.api ?? AppServices.instance.api;

  bool _loading = true;
  String? _error;
  int? _rank;
  int? _teamCount;
  DateTime? _computedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = widget.token ?? await AppServices.instance.session.token;
      final result = await _api.getMyRank(token);
      if (!mounted) return;
      setState(() {
        _rank = result.rank;
        _teamCount = result.teamCount;
        _computedAt = result.computedAt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Rangliste konnte nicht geladen werden.';
        _loading = false;
      });
    }
  }

  String? _computedLabel() {
    final t = _computedAt;
    if (t == null) return null;
    return DateFormat('dd.MM. yyyy, HH:mm').format(t.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
                onPressed: _load,
              ),
            ),
          ] else if (_rank == null) ...[
            const Text('Noch keine Rangliste', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
                onPressed: _load,
              ),
            ),
          ] else ...[
            Text(
              'Dein Team ist auf Platz $_rank von $_teamCount',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_computedLabel() != null)
              Text(
                'Stand: ${_computedLabel()}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
                onPressed: _load,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
