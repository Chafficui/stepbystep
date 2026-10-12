/// Zentrale Server-Konfiguration.
///
/// Die Server-URL wird beim Build über `--dart-define=API_URL=...` gesetzt.
/// Es gibt bewusst keinen Fallback-Default: Ohne API_URL startet die App
/// in einen deutschen Fehlerbildschirm statt still gegen einen falschen
/// Server zu laufen.
class ApiConfig {
  ApiConfig._();

  static const String apiUrl = String.fromEnvironment('API_URL');

  static bool get hasApiUrl => apiUrl.trim().isNotEmpty;

  /// Basis-URL ohne abschließenden Slash.
  static String get base {
    var url = apiUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
