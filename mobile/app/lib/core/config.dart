/// Build-time configuration, passed with `--dart-define`.
///
/// ```sh
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
/// ```
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.useEmulators,
    required this.emulatorHost,
    this.echoApiBaseUrl = 'http://localhost:8082',
    this.useEchoApi = true,
    this.findApiBaseUrl = 'http://localhost:8083',
    this.useFindApi = true,
    this.eventsApiBaseUrl = 'http://localhost:8084',
    this.useEventsApi = true,
    this.firebase = const FirebaseWebConfig(),
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    useEmulators: bool.fromEnvironment('USE_EMULATORS', defaultValue: true),
    // Android emulator reaches the host machine via 10.0.2.2.
    emulatorHost: String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: 'localhost',
    ),
    echoApiBaseUrl: String.fromEnvironment(
      'ECHO_API_BASE_URL',
      defaultValue: 'http://localhost:8082',
    ),
    useEchoApi: bool.fromEnvironment('USE_ECHO_API', defaultValue: true),
    findApiBaseUrl: String.fromEnvironment(
      'FIND_API_BASE_URL',
      defaultValue: 'http://localhost:8083',
    ),
    useFindApi: bool.fromEnvironment('USE_FIND_API', defaultValue: true),
    eventsApiBaseUrl: String.fromEnvironment(
      'EVENTS_API_BASE_URL',
      defaultValue: 'http://localhost:8084',
    ),
    useEventsApi: bool.fromEnvironment('USE_EVENTS_API', defaultValue: true),
    firebase: FirebaseWebConfig(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    ),
  );

  final String apiBaseUrl;
  final bool useEmulators;
  final String emulatorHost;

  /// Echo service (`backend/echo`, `contracts/echo`).
  final String echoApiBaseUrl;

  /// Use the Echo API when Firebase is up and the service answers `/healthz`.
  /// Otherwise (or with `USE_ECHO_API=false`) Echo runs on demo data.
  final bool useEchoApi;

  /// Find service (`backend/find`, `contracts/find`).
  final String findApiBaseUrl;

  /// Use the Find API when Firebase is up and the service answers `/healthz`.
  /// Otherwise (or with `USE_FIND_API=false`) Find runs on demo data.
  final bool useFindApi;

  /// Events service (`backend/events`, `contracts/events`).
  final String eventsApiBaseUrl;

  /// Use the Events API (join, agenda, My events, organizer import) when
  /// Firebase is up and the service answers `/healthz`. Otherwise (or with
  /// `USE_EVENTS_API=false`) they run on demo data.
  final bool useEventsApi;

  /// Real Firebase project values, used only when `USE_EMULATORS=false`.
  final FirebaseWebConfig firebase;
}

/// Public Firebase client config (not secrets), read from `--dart-define`.
/// Empty string means "not set". Never commit real values.
class FirebaseWebConfig {
  const FirebaseWebConfig({
    this.apiKey = '',
    this.appId = '',
    this.projectId = '',
    this.messagingSenderId = '',
    this.authDomain = '',
    this.storageBucket = '',
  });

  final String apiKey;
  final String appId;
  final String projectId;
  final String messagingSenderId;
  final String authDomain;
  final String storageBucket;
}
