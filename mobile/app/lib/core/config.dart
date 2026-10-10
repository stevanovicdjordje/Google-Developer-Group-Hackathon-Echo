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
  );

  final String apiBaseUrl;
  final bool useEmulators;
  final String emulatorHost;

  /// Echo service (`backend/echo`, `contracts/echo`).
  final String echoApiBaseUrl;

  /// Use the Echo API when Firebase is up and the service answers `/healthz`.
  /// Otherwise (or with `USE_ECHO_API=false`) Echo runs on demo data.
  final bool useEchoApi;
}
