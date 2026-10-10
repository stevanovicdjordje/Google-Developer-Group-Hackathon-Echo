import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/firebase/firebase_init.dart';
import 'data/local_store.dart';

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
  // Preload saved client state so Notifiers (and router redirects) see it
  // synchronously. Falls back to in-memory state if storage is unavailable.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Local storage not available, state will not persist: $e');
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const EhoApp(),
    ),
  );
}
