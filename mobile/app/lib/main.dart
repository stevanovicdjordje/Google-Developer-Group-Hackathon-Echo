import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/firebase/firebase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // clean /e/{eventId} links on web
  await initFirebase(AppConfig.fromEnvironment());
  runApp(const ProviderScope(child: EhoApp()));
}
