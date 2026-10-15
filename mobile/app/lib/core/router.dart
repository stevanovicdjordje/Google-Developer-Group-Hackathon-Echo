import 'package:eho_maps/eho_maps.dart' show mapsRoutes;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/demo_ids.dart';
import '../data/repositories.dart' show demoEventId;
import '../features/agenda/agenda_screens.dart';
import '../features/dev/dev_shot_routes.dart';
import '../features/dev/dev_status_screen.dart';
import '../features/echo/echo_screen.dart';
import '../features/event/event_shell.dart';
import '../features/find/find_screens.dart';
import '../features/join/join_screens.dart';
import '../features/map/map_tab.dart';
import '../features/organizer/organizer_screens.dart';
import '../features/profile/profile_screen.dart';
import '../features/start/start_screen.dart';

/// App routes. Links (`docs/decisions/team-event-join.md`):
/// - `/e/{eventId}` join/open an event (optional `?at={markerId}`)
/// - `/e/{eventId}/stand/{standId}` a stand on the map
///
/// The venue map (`eho_maps`) is shown inside the Map tab via
/// [MapViewerScreen]. Of its own `mapsRoutes()` only the organizer map
/// editor (`/o`, `/o/e/{eventId}`) is mounted; its `/e/:eventId` would clash.
///
/// `/e/devfest/...` (and the old `/e/devsummit/...`) redirect to
/// `/e/{demoId}/...` when `--dart-define=DEMO_EVENT_ID` points at a real
/// backend event; see [demoEventRedirect].
GoRouter buildRouter({String demoId = demoEventId}) => GoRouter(
  redirect: (c, s) => demoEventRedirect(s.uri, demoId),
  routes: [
    GoRoute(path: '/', builder: (c, s) => const StartScreen()),
    GoRoute(path: '/dev', builder: (c, s) => const DevStatusScreen()),
    if (devRoutesEnabled) ...devShotRoutes(),
    GoRoute(path: '/events', builder: (c, s) => const MyEventsScreen()),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),

    // Venue map editor (feature:maps)
    ...mapsRoutes().where((r) => r is GoRoute && r.path == '/o'),

    // Organizer
    GoRoute(
      path: '/organizer',
      builder: (c, s) => const OrganizerUploadScreen(),
      routes: [
        GoRoute(
          path: 'review',
          builder: (c, s) => const OrganizerReviewScreen(),
        ),
        GoRoute(
          path: 'published',
          builder: (c, s) => OrganizerPublishedScreen(
            url: s.uri.queryParameters['url'] ?? '',
            name: s.uri.queryParameters['name'] ?? '',
          ),
        ),
      ],
    ),

    // Event: bottom-nav tabs. Each tab is a branch with its own Navigator
    // kept alive in an IndexedStack, so switching tabs keeps scroll
    // position, Find results, the map camera and pushed pages. The branches
    // are shared by all events, so each tab root is keyed by `eventId`: going
    // to another event creates fresh screen state instead of showing the
    // previous event's search, stage filter or map.
    StatefulShellRoute.indexedStack(
      builder: (c, s, shell) =>
          EventShell(eventId: _id(s), location: s.uri.toString(), child: shell),
      branches: [
        StatefulShellBranch(
          initialLocation: _tabPlaceholder('agenda'),
          routes: [
            GoRoute(
              path: '/e/:eventId/agenda',
              builder: (c, s) =>
                  AgendaScreen(key: ValueKey(_id(s)), eventId: _id(s)),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: _tabPlaceholder('map'),
          routes: [
            GoRoute(
              path: '/e/:eventId/map',
              builder: (c, s) => MapTab(
                key: ValueKey(_id(s)),
                eventId: _id(s),
                markerId: s.uri.queryParameters['at'],
              ),
              routes: [
                GoRoute(
                  path: 'stand/:standId',
                  builder: (c, s) => MapTab(
                    key: ValueKey(_id(s)),
                    eventId: _id(s),
                    featureId: s.pathParameters['standId'],
                    markerId: s.uri.queryParameters['at'],
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: _tabPlaceholder('find'),
          routes: [
            GoRoute(
              path: '/e/:eventId/find',
              builder: (c, s) =>
                  FindScreen(key: ValueKey(_id(s)), eventId: _id(s)),
              routes: [
                GoRoute(
                  path: 'person/:personId',
                  builder: (c, s) => PersonScreen(
                    key: ValueKey(_id(s)),
                    eventId: _id(s),
                    personId: s.pathParameters['personId']!,
                    why: s.uri.queryParameters['why'],
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: _tabPlaceholder('profile'),
          routes: [
            GoRoute(
              path: '/e/:eventId/profile',
              builder: (c, s) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Event: full-screen pages and link entry points
    GoRoute(
      path: '/e/:eventId',
      builder: (c, s) =>
          EventEntry(eventId: _id(s), markerId: s.uri.queryParameters['at']),
    ),
    GoRoute(
      path: '/e/:eventId/stand/:standId',
      // Keeps the query: `?at=` is the "you are here" QR marker.
      redirect: (c, s) => s.uri
          .replace(
            path: '/e/${_id(s)}/map/stand/${s.pathParameters['standId']}',
          )
          .toString(),
    ),
    GoRoute(
      path: '/e/:eventId/session/:sessionId',
      builder: (c, s) => SessionScreen(
        eventId: _id(s),
        sessionId: s.pathParameters['sessionId']!,
      ),
      routes: [
        GoRoute(
          path: 'echo',
          builder: (c, s) => EchoScreen(
            eventId: _id(s),
            sessionId: s.pathParameters['sessionId']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/e/:eventId/messages/:personId',
      builder: (c, s) => MessagesScreen(
        eventId: _id(s),
        personId: s.pathParameters['personId']!,
      ),
    ),
  ],
);

/// Maps `/e/{alias}/...` to `/e/{demoId}/...`, keeping the sub-path and query
/// (e.g. `?at=`). Returns null when nothing changes, which also rules out a
/// redirect loop when [demoId] is itself an alias (the default `devfest`).
String? demoEventRedirect(Uri uri, String demoId) {
  final seg = uri.pathSegments;
  if (seg.length < 2 || seg[0] != 'e' || !uri.path.startsWith('/e/')) {
    return null;
  }
  if (!demoEventAliases.contains(seg[1]) || seg[1] == demoId) return null;
  if (demoEventAliases.contains(demoId)) return null;
  // Rewrite the raw path (keeps encoding and the leading slash).
  final rest = uri.path.substring('/e/${seg[1]}'.length);
  return uri.replace(path: '/e/${Uri.encodeComponent(demoId)}$rest').toString();
}

String _id(GoRouterState s) => s.pathParameters['eventId']!;

/// go_router needs a concrete initial location per branch, but ours depend on
/// `:eventId`. This placeholder only satisfies that check: [EventShell]
/// always navigates with real `/e/{eventId}/…` locations (never `goBranch`),
/// and branches are not preloaded, so it is never opened.
String _tabPlaceholder(String tab) => '/e/_/$tab';

/// `/e/{eventId}`: joined users go straight in (to the map when a
/// "you are here" QR was scanned); everyone else sees the join screen.
class EventEntry extends ConsumerWidget {
  const EventEntry({super.key, required this.eventId, this.markerId});

  final String eventId;
  final String? markerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = ref.watch(joinedEventsProvider).any((e) => e.id == eventId);
    if (!joined) return JoinScreen(eventId: eventId, markerId: markerId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.go(
        markerId == null
            ? '/e/$eventId/agenda'
            : '/e/$eventId/map?at=${Uri.encodeComponent(markerId!)}',
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
