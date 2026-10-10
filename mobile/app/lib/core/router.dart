import 'package:go_router/go_router.dart';

import '../features/dev/dev_status_screen.dart';

/// Deep links: `/e/{eventId}` (optional `?at={markerId}`) and
/// `/e/{eventId}/stand/{standId}`. Event routes are added with the map viewer.
GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DevStatusScreen()),
  ],
);
