import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../state/session_store.dart';

/// Aktueller Stand des Teamfotos (lokal gecacht).
@immutable
class TeamPhotoState {
  const TeamPhotoState({this.bytes, this.updatedAt});

  /// Bildbytes (jpg/png) oder null.
  final Uint8List? bytes;

  /// `photo_updated_at` des Servers (Cache-Schlüssel); null = kein Foto.
  final DateTime? updatedAt;

  bool get hasPhoto => bytes != null;

  /// Weder Bild noch Server-Zeitstempel: Foto fehlt (bzw. unbekannt).
  bool get missing => bytes == null && updatedAt == null;
}

/// Ergebnis von [TeamPhotoService.refresh].
enum TeamPhotoStatus {
  /// Team hat ein Foto.
  present,

  /// Server bestätigt: kein Foto.
  missing,

  /// Server nicht erreichbar / Fehler — Zustand unbekannt.
  unknown,
}

/// Teamfoto: Aufnahme (nur Kamera), Upload und lokaler Cache.
///
/// Das Foto gehört dem Team (nicht dem Gerät): `GET /api/me` liefert
/// `team_photo_updated_at`; ändert sich der Wert, wird das Bild neu
/// geladen und unter `<docs>/team_photo/<epochMs>.img` gecacht. So
/// funktioniert der Karten-Pin offline und auf dem zweiten Gerät.
class TeamPhotoService {
  TeamPhotoService({
    required ApiClient api,
    required SessionStore session,
    ImagePicker? picker,
    Future<Directory> Function()? cacheDir,
    this.onAuthExpired,
  })  : _api = api,
        _session = session,
        _picker = picker ?? ImagePicker(),
        _cacheDir = cacheDir ?? _defaultCacheDir;

  final ApiClient _api;
  final SessionStore _session;
  final ImagePicker _picker;
  final Future<Directory> Function() _cacheDir;

  /// 401 vom Server: zurück zum Join-Screen.
  final void Function()? onAuthExpired;

  /// Aktuelles Foto (für Live-Tab, Karte, Teamfoto-Screen).
  final ValueNotifier<TeamPhotoState> state =
      ValueNotifier<TeamPhotoState>(const TeamPhotoState());

  static Future<Directory> _defaultCacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'team_photo'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Lädt ein vorhandenes Cache-Bild (App-Start, auch offline).
  Future<void> loadCache() async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return;
      File? best;
      var bestMs = -1;
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.img')) continue;
        final ms = int.tryParse(p.basenameWithoutExtension(e.path));
        if (ms != null && ms > bestMs) {
          bestMs = ms;
          best = e;
        }
      }
      if (best == null) return;
      state.value = TeamPhotoState(
        bytes: await best.readAsBytes(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(bestMs, isUtc: true),
      );
    } catch (_) {
      // Cache ist optional.
    }
  }

  /// Nimmt ein Foto mit der Kamera auf (NIE Galerie). Frontkamera ist
  /// vorbelegt (Selfie), im Kamera-UI umschaltbar. Null bei Abbruch.
  Future<File?> capture() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return picked == null ? null : File(picked.path);
  }

  /// Fragt `/api/me` ab und gleicht den Cache an: Foto neu laden, wenn der
  /// Zeitstempel abweicht; Cache leeren, wenn der Server keins mehr hat
  /// (Orga-Reset). Wirft nie.
  Future<TeamPhotoStatus> refresh() async {
    try {
      final token = await _session.token;
      if (token == null || token.isEmpty) return TeamPhotoStatus.unknown;
      final me = await _api.getMe(token);
      final remote = me.teamPhotoUpdatedAt;
      if (remote == null) {
        await _clearCache();
        state.value = const TeamPhotoState();
        return TeamPhotoStatus.missing;
      }
      final cur = state.value;
      if (cur.hasPhoto && cur.updatedAt == remote) {
        return TeamPhotoStatus.present;
      }
      final bytes = await _api.getTeamPhoto(token);
      if (bytes == null) {
        await _clearCache();
        state.value = const TeamPhotoState();
        return TeamPhotoStatus.missing;
      }
      await _store(bytes, remote);
      state.value = TeamPhotoState(bytes: bytes, updatedAt: remote);
      return TeamPhotoStatus.present;
    } on AuthException {
      onAuthExpired?.call();
      return TeamPhotoStatus.unknown;
    } catch (_) {
      return TeamPhotoStatus.unknown;
    }
  }

  /// Lädt [file] hoch (idempotent über [id]) und aktualisiert den Cache.
  /// Wirft [ApiException] (inkl. [AuthException] → [onAuthExpired]).
  Future<void> upload({required File file, required String id}) async {
    final token = await _session.token;
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Nicht angemeldet.');
    }
    try {
      final updatedAt = await _api.postTeamPhoto(
        token: token,
        id: id,
        capturedAt: DateTime.now().toUtc(),
        file: file,
      );
      final bytes = await file.readAsBytes();
      try {
        await _store(bytes, updatedAt);
      } catch (_) {
        // Cache-Fehler darf den erfolgreichen Upload nicht kippen.
      }
      state.value = TeamPhotoState(bytes: bytes, updatedAt: updatedAt);
    } on AuthException {
      onAuthExpired?.call();
      rethrow;
    }
  }

  Future<void> _store(Uint8List bytes, DateTime updatedAt) async {
    final dir = await _cacheDir();
    await _clearCache();
    await File(p.join(dir.path, '${updatedAt.millisecondsSinceEpoch}.img'))
        .writeAsBytes(bytes, flush: true);
  }

  Future<void> _clearCache() async {
    try {
      final dir = await _cacheDir();
      if (!await dir.exists()) return;
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.img')) await e.delete();
      }
    } catch (_) {}
  }
}
