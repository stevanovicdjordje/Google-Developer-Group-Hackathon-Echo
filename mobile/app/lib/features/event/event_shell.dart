import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _tabs = ['agenda', 'map', 'find', 'profile'];

/// Bottom navigation for an event: Agenda, Map, Find, Profile.
/// The active tab is derived from the URL (`/e/{eventId}/{tab}/…`).
class EventShell extends StatelessWidget {
  const EventShell({
    super.key,
    required this.eventId,
    required this.location,
    required this.child,
  });

  final String eventId;
  final String location;
  final Widget child;

  int get _index {
    final segments = Uri.parse(location).pathSegments;
    final i = segments.length > 2 ? _tabs.indexOf(segments[2]) : 0;
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => context.go('/e/$eventId/${_tabs[i]}'),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Agenda',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Find',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}
