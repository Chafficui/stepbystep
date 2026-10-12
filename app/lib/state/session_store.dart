import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Sitzungsdaten (secure storage) und App-Einstellungen (shared prefs).
///
/// WICHTIG: `clearSession()` löscht NUR Token/Team/Name — niemals die
/// lokale drift-Datenbank oder ausstehende Medien (Datenschutz vor
/// Datenverlust: gesammelte Punkte/Check-ins bleiben offline erhalten).
class SessionStore {
  SessionStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  })  : _secure = secureStorage ?? const FlutterSecureStorage(),
        _prefs = prefs;

  static const _kDeviceId = 'device_id';
  static const _kToken = 'token';
  static const _kTeamName = 'team_name';
  static const _kDisplayName = 'display_name';
  static const _kTrackingActive = 'tracking_active';
  static const _kBatteryWarnShown = 'battery_warning_shown';

  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // --- device_id (UUID v4, einmalig beim ersten Start) ---

  Future<String> getOrCreateDeviceId() async {
    final existing = await _secure.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _secure.write(key: _kDeviceId, value: id);
    return id;
  }

  // --- Token / Team (secure storage) ---

  Future<String?> get token => _secure.read(key: _kToken);

  Future<String?> get teamName => _secure.read(key: _kTeamName);

  Future<String?> get displayName => _secure.read(key: _kDisplayName);

  Future<void> saveSession({
    required String token,
    required String teamName,
    required String displayName,
  }) async {
    await _secure.write(key: _kToken, value: token);
    await _secure.write(key: _kTeamName, value: teamName);
    await _secure.write(key: _kDisplayName, value: displayName);
  }

  /// Löscht NUR die Sitzung (Token/Team/Name). Die lokale Datenbank und
  /// ausstehende Medien bleiben bewusst UNBERÜHRT.
  Future<void> clearSession() async {
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kTeamName);
    await _secure.delete(key: _kDisplayName);
    await setTrackingActive(false);
  }

  /// Ist eine Sitzung vorhanden (nur Präsenz prüfen, Token wird nicht
  /// in der UI angezeigt)?
  Future<bool> hasSession() async {
    final t = await token;
    return t != null && t.isNotEmpty;
  }

  // --- App-Einstellungen (shared prefs, kein Geheimnis) ---

  Future<bool> getTrackingActive() async {
    return (await _sharedPrefs).getBool(_kTrackingActive) ?? false;
  }

  Future<void> setTrackingActive(bool value) async {
    await (await _sharedPrefs).setBool(_kTrackingActive, value);
  }

  Future<bool> getBatteryWarningShown() async {
    return (await _sharedPrefs).getBool(_kBatteryWarnShown) ?? false;
  }

  Future<void> setBatteryWarningShown(bool value) async {
    await (await _sharedPrefs).setBool(_kBatteryWarnShown, value);
  }
}
