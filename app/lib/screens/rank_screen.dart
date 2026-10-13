import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../brand/sbs_colors.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
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
      if (token == null) throw StateError('Kein Token vorhanden.');
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
    return RankView(
      loading: _loading,
      error: _error,
      rank: _rank,
      teamCount: _teamCount,
      computedLabel: _computedLabel(),
      onRefresh: _load,
    );
  }
}

/// Präsentation des Rang-Tabs (reine Daten, testbar).
class RankView extends StatelessWidget {
  const RankView({
    super.key,
    required this.loading,
    required this.error,
    required this.rank,
    required this.teamCount,
    required this.computedLabel,
    required this.onRefresh,
  });

  final bool loading;
  final String? error;
  final int? rank;
  final int? teamCount;
  final String? computedLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final refresh = OutlinedButton.icon(
      icon: const Icon(Icons.refresh),
      label: const Text('Aktualisieren'),
      onPressed: onRefresh,
    );
    final List<Widget> children;
    if (loading) {
      children = const [Center(child: CircularProgressIndicator())];
    } else if (error != null) {
      children = [
        const Center(
            child: Icon(Icons.cloud_off, size: 36, color: SbsColors.signal)),
        const SizedBox(height: 12),
        Text(error!,
            textAlign: TextAlign.center,
            style: SbsText.body(color: SbsColors.signal)),
        const SizedBox(height: 20),
        refresh,
      ];
    } else if (rank == null) {
      children = [
        const SbsHeading('Noch keine Rangliste',
            size: 22, align: TextAlign.center),
        const SizedBox(height: 20),
        refresh,
      ];
    } else {
      children = [
        const Center(child: SbsLabel('Dein Team')),
        const SizedBox(height: 14),
        Center(
            child: StopwatchRing(
          size: 230,
          progress: (teamCount == null || teamCount! <= 1)
              ? 1
              : 1 - (rank! - 1) / (teamCount! - 1),
          strokeWidth: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SbsLabel('Platz'),
              Text('$rank', style: SbsText.number(76)),
              Text('von $teamCount',
                  style: SbsText.body(size: 15, color: SbsColors.fgMuted)),
            ],
          ),
        )),
        const SizedBox(height: 20),
        Text(
          'Dein Team ist auf Platz $rank von $teamCount',
          textAlign: TextAlign.center,
          style: SbsText.body(size: 15, weight: FontWeight.w600),
        ),
        if (computedLabel != null) ...[
          const SizedBox(height: 6),
          Text('Stand: $computedLabel',
              textAlign: TextAlign.center,
              style: SbsText.body(size: 13, color: SbsColors.fgMuted)),
        ],
        const SizedBox(height: 20),
        refresh,
      ];
    }
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          ...sbsStagger(children),
        ],
      ),
    );
  }
}
