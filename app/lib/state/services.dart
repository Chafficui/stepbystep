import '../api/api_client.dart';
import '../db/app_database.dart';
import '../tracking/battery_monitor.dart';
import '../tracking/tracking_service.dart';
import '../tracking/upload_service.dart';
import 'session_store.dart';

/// Zentrale Service-Instanzen (Singletons für App-Laufzeit).
///
/// Wird in `main.dart` initialisiert; Screens/Widgets greifen über
/// [AppServices.instance] zu.
class AppServices {
  AppServices._();

  static AppServices? _instance;

  static AppServices get instance {
    assert(_instance != null, 'AppServices.init() wurde nicht aufgerufen');
    return _instance!;
  }

  /// Null-sichere Variante für frühe Widget-Lifecycles (vor `init()`).
  static AppServices? get instanceOrNull => _instance;

  late final SessionStore session;
  late final AppDatabase db;
  late final ApiClient api;
  late final BatteryMonitor battery;
  late final TrackingService tracking;
  late final UploadService upload;

  /// Wird vom Auth-Layer gesetzt (Rückkehr zum Join-Screen bei 401).
  static void Function()? onAuthExpired;

  static Future<AppServices> init() async {
    final s = AppServices._();
    s.session = SessionStore();
    s.db = AppDatabase();
    s.api = ApiClient();
    s.battery = BatteryMonitor(sessionStore: s.session);
    await s.battery.init();
    s.tracking = TrackingService(
      db: s.db,
      sessionStore: s.session,
      batteryMonitor: s.battery,
    );
    s.upload = UploadService(
      db: s.db,
      api: s.api,
      session: s.session,
      onAuthExpired: onAuthExpired,
    );
    _instance = s;
    return s;
  }
}
