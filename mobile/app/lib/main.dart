import 'package:eho_maps/eho_maps.dart' show mapsApiBaseUrlProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/firebase/firebase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // clean /e/{eventId} links on web
  try {
    // Don't block the whole app when the emulators/backend aren't running:
    // only the Map tab needs Firebase, and it shows its own error state.
    await initFirebase(AppConfig.fromEnvironment())
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Firebase not available, continuing without it: $e');
  }
  runApp(
    ProviderScope(
      overrides: [
        // The venue-map package uses the same API base URL as the app.
        mapsApiBaseUrlProvider.overrideWithValue(
          AppConfig.fromEnvironment().apiBaseUrl,
        ),
      ],
      child: const EhoApp(),
    ),
  );
}
