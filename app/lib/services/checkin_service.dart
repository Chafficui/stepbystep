import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../db/app_database.dart';
import '../tracking/upload_service.dart';

/// Aufnahme und lokale Speicherung von Check-ins (Foto/Video).
///
/// Ablauf pro Check-in:
/// 1. Aufnahme über die Kamera (`image_picker`, NIE Galerie).
/// 2. Datei-Bytes nach `<docs>/checkins/<uuid>.jpg|.mp4` kopieren
///    (UUID pro Check-in, dieselbe ID bei Retry).
/// 3. `PendingCheckins`-Zeile einfügen (capturedAt = jetzt UTC ms,
///    sentAt = null).
/// 4. Upload sofort anstoßen (`flushCheckins`) — offline bleibt die Zeile
///    in der Queue und wird später automatisch gesendet.
class CheckinService {
  CheckinService({
    required AppDatabase db,
    required ApiClient api,
    required UploadService upload,
    ImagePicker? picker,
  })  : _db = db,
        _api = api,
        _upload = upload,
        _picker = picker ?? ImagePicker();

  final AppDatabase _db;
  final ApiClient _api;
  final UploadService _upload;
  final ImagePicker _picker;

  /// Nimmt ein Foto bzw. Video (Kamera) auf, speichert es lokal und legt es
  /// in die Upload-Queue. Liefert die Check-in-ID (oder null bei Abbruch).
  Future<String?> captureCheckin({required String mediaType}) async {
    final XFile? picked;
    if (mediaType == 'photo') {
      picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
    } else {
      // image_picker 1.1.x bietet für Videos KEINEN Auflösungs-/Qualitäts-
      // Parameter (weder preferredResolution noch maxResolution). Nur das
      // 15-s-Limit ist möglich; in Standardqualität bleibt ein 15-s-Video
      // damit typischerweise unter 5 MB.
      picked = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
      );
    }
    if (picked == null) return null;

    final id = const Uuid().v4();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'checkins'));
    await dir.create(recursive: true);
    final ext = mediaType == 'photo' ? 'jpg' : 'mp4';
    final target = File(p.join(dir.path, '$id.$ext'));
    await File(picked.path).copy(target.path);

    await _db.insertCheckin(PendingCheckinsCompanion.insert(
      id: id,
      capturedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      mediaType: mediaType,
      filePath: target.path,
    ));

    // Sofortiger Upload-Versuch; offline bleibt die Zeile in der Queue.
    unawaited(_upload.flushCheckins(_api));
    return id;
  }
}
