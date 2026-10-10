import 'package:go_router/go_router.dart';

import 'editor/map_editor_screen.dart';
import 'editor/organizer_screens.dart';
import 'viewer/map_viewer_screen.dart';

/// Venue map routes, mounted by the app's router:
/// `/e/{eventId}` (optional `?at={markerId}`) and `/e/{eventId}/stand/{standId}`
/// for attendees, `/o` (events) and `/o/e/{eventId}` (map editor) for organizers.
List<RouteBase> mapsRoutes() => [
  GoRoute(
    path: '/e/:eventId',
    builder: (context, state) => MapViewerScreen(
      eventId: state.pathParameters['eventId']!,
      markerId: state.uri.queryParameters['at'],
    ),
    routes: [
      GoRoute(
        path: 'stand/:standId',
        builder: (context, state) => MapViewerScreen(
          eventId: state.pathParameters['eventId']!,
          initialFeatureId: state.pathParameters['standId'],
        ),
      ),
    ],
  ),
  GoRoute(
    path: '/o',
    builder: (context, state) => const OrganizerHomeScreen(),
    routes: [
      GoRoute(
        path: 'e/:eventId',
        builder: (context, state) =>
            MapEditorScreen(eventId: state.pathParameters['eventId']!),
      ),
    ],
  ),
];
