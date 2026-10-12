import 'package:flutter/services.dart';

/// Fordert die Ausnahme von der Android-Akku-Optimierung an (Onboarding
/// Schritt 4): MethodChannel 'de.example.stepbystep/battery' ->
/// `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` mit Paket-URI.
///
/// Liefert true, wenn der Systemdialog geöffnet werden konnte; false bzw.
/// geworfene Fehler (z. B. Plattform nicht verfügbar) -> Aufrufer nutzt
/// den Fallback (App-Einstellungen öffnen).
class BatteryOptimization {
  BatteryOptimization._();

  static const MethodChannel _channel =
      MethodChannel('de.example.stepbystep/battery');

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
