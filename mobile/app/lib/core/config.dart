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
  );

  final String apiBaseUrl;
  final bool useEmulators;
  final String emulatorHost;
}
