import 'package:eho_maps/eho_maps.dart';
import 'package:go_router/go_router.dart';

import '../features/dev/dev_status_screen.dart';

/// Deep links: `/e/{eventId}` (optional `?at={markerId}`) and
/// `/e/{eventId}/stand/{standId}`, provided by the venue map package.
GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DevStatusScreen()),
    ...mapsRoutes(),
  ],
);
