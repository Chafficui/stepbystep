import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../brand/sbs_colors.dart';
import '../brand/sbs_theme.dart';
import '../brand/sbs_widgets.dart';
import '../services/team_photo_service.dart';
import '../state/services.dart';

/// Teamfoto aufnehmen und hochladen.
///
/// - [allowSkip] false: Pflicht vor dem Start (kein „Später", kein Zurück).
/// - [retake] true: Neuaufnahme aus dem Live-Tab (Zurück-Pfeil, zeigt das
///   aktuelle Foto als Vorschau).
/// - [onDone]: nach erfolgreichem Upload bzw. „Später"; ohne Callback
///   wird der Screen geschlossen.
class TeamPhotoScreen extends StatefulWidget {
  const TeamPhotoScreen({
    super.key,
    this.allowSkip = false,
    this.retake = false,
    this.onDone,
    this.service,
  });

  final bool allowSkip;
  final bool retake;
  final VoidCallback? onDone;

  /// Optional injizierbar (Tests); default: [AppServices.instance].
  final TeamPhotoService? service;

  @override
  State<TeamPhotoScreen> createState() => _TeamPhotoScreenState();
}

class _TeamPhotoScreenState extends State<TeamPhotoScreen> {
  TeamPhotoService get _service =>
      widget.service ?? AppServices.instance.teamPhoto;

  File? _file;
  Uint8List? _bytes;

  /// Eine ID pro Aufnahme — dieselbe bei Retry (Idempotenz am Server).
  String? _id;
  bool _uploading = false;
  String? _error;

  Future<void> _capture() async {
    try {
      final f = await _service.capture();
      if (f == null || !mounted) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = f;
        _bytes = bytes;
        _id = const Uuid().v4();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Kamera konnte nicht geöffnet werden. '
          'Bitte Kamera-Berechtigung prüfen.');
    }
  }

  Future<void> _upload() async {
    final f = _file;
    final id = _id;
    if (f == null || id == null || _uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await _service.upload(file: f, id: id);
      if (!mounted) return;
      // Erst entsperren, dann schließen (PopScope sperrt beim Upload).
      setState(() => _uploading = false);
      _finish();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = switch (e.status) {
          0 => 'Keine Verbindung – bitte Netz prüfen und erneut versuchen.',
          415 => 'Dieses Bildformat wird nicht unterstützt (nur JPG/PNG).',
          _ => 'Upload fehlgeschlagen (${e.message}).',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Upload fehlgeschlagen. Bitte erneut versuchen.';
      });
    }
  }

  void _finish() {
    final cb = widget.onDone;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _service.state.value.bytes;
    return PopScope(
      // Pflicht-Modus: kein Zurück (System-Geste ebenfalls gesperrt).
      canPop: widget.retake && !_uploading,
      child: TeamPhotoView(
        previewBytes: _bytes ?? (widget.retake ? existing : null),
        hasNewCapture: _file != null,
        uploading: _uploading,
        error: _error,
        retake: widget.retake,
        allowSkip: widget.allowSkip,
        onCapture: _capture,
        onUpload: _upload,
        onSkip: widget.allowSkip ? _finish : null,
        onClose: widget.retake ? () => Navigator.of(context).maybePop() : null,
      ),
    );
  }
}

/// Präsentation des Teamfoto-Screens (reine Daten, testbar).
class TeamPhotoView extends StatelessWidget {
  const TeamPhotoView({
    super.key,
    required this.previewBytes,
    required this.hasNewCapture,
    required this.uploading,
    required this.error,
    required this.retake,
    required this.allowSkip,
    required this.onCapture,
    required this.onUpload,
    this.onSkip,
    this.onClose,
  });

  final Uint8List? previewBytes;

  /// Es gibt eine frische, noch nicht hochgeladene Aufnahme.
  final bool hasNewCapture;
  final bool uploading;
  final String? error;
  final bool retake;
  final bool allowSkip;
  final VoidCallback onCapture;
  final VoidCallback onUpload;
  final VoidCallback? onSkip;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final frame = (w - 72).clamp(220.0, 320.0);
    final hasPreview = previewBytes != null;

    final preview = StopwatchRing(
      size: frame,
      progress: hasPreview ? 1 : 0,
      strokeWidth: 6,
      color: uploading ? SbsColors.fgMuted : SbsColors.fg,
      child: Padding(
        padding: EdgeInsets.all(frame * 0.17),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPreview)
                Image.memory(previewBytes!,
                    fit: BoxFit.cover, gaplessPlayback: true)
              else
                Container(
                  color: SbsColors.surface,
                  alignment: Alignment.center,
                  child: const Icon(Icons.groups_outlined,
                      size: 64, color: SbsColors.fgFaint),
                ),
              if (uploading)
                Container(
                  color: const Color(0xAA050605),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: SbsColors.fg),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final String primaryLabel;
    final VoidCallback? primary;
    if (hasNewCapture) {
      primaryLabel = error != null ? 'Erneut versuchen' : 'Hochladen';
      primary = uploading ? null : onUpload;
    } else {
      primaryLabel = hasPreview ? 'Neu aufnehmen' : 'Foto aufnehmen';
      primary = onCapture;
    }

    final children = <Widget>[
      Row(
        children: [
          if (onClose != null)
            IconButton(
              tooltip: 'Zurück',
              onPressed: uploading ? null : onClose,
              icon: const Icon(Icons.arrow_back),
            ),
          const Spacer(),
          SbsLabel(
              retake
                  ? 'Neu aufnehmen'
                  : allowSkip
                      ? 'Jetzt nachholen'
                      : 'Pflicht vor dem Start',
              color: retake ? SbsColors.fgMuted : SbsColors.warn),
        ],
      ),
      const SizedBox(height: 12),
      const SbsHeading('Teamfoto', size: 32),
      const SizedBox(height: 8),
      Text(
        'Macht ein gemeinsames Foto eures Teams – es dient der Orga zur '
        'Erkennung und erscheint als euer Pin auf der Karte.',
        style: SbsText.body(color: SbsColors.fgMuted),
      ),
      const SizedBox(height: 24),
      Center(child: preview),
      const SizedBox(height: 24),
      if (uploading)
        Center(
          child: Text('Foto wird hochgeladen …',
              style: SbsText.body(
                  size: 14, weight: FontWeight.w600, color: SbsColors.fgMuted)),
        ),
      if (error != null)
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
                child: Text(error!,
                    style: SbsText.body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: SbsColors.signal)),
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
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
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
                      if (hasNewCapture) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          onPressed: uploading ? null : onCapture,
                          child: const Text('Neu aufnehmen'),
                        ),
                      ],
                      if (allowSkip && onSkip != null)
                        TextButton(
                          onPressed: uploading ? null : onSkip,
                          child: const Text('Später'),
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
