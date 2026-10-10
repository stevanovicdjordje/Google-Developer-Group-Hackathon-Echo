import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _tabs = ['agenda', 'map', 'find', 'profile'];

/// Bottom navigation for an event: Agenda, Map, Find, Profile.
/// The active tab is derived from the URL (`/e/{eventId}/{tab}/…`).
///
/// [child] is the `StatefulShellRoute` navigation shell, which keeps every
/// visited tab alive. Tapping another tab goes back to where the user left
/// it (e.g. an open person page); tapping the active tab goes to its root.
class EventShell extends StatefulWidget {
  const EventShell({
    super.key,
    required this.eventId,
    required this.location,
    required this.child,
  });

  final String eventId;

  /// Current location (path and query).
  final String location;
  final Widget child;

  @override
  State<EventShell> createState() => _EventShellState();
}

class _EventShellState extends State<EventShell> {
  /// Last location seen per tab index, for [EventShell.eventId] only.
  final _last = <int, String>{};

  int get _index {
    final segments = Uri.parse(widget.location).pathSegments;
    final i = segments.length > 2 ? _tabs.indexOf(segments[2]) : 0;
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _last[_index] = widget.location;
  }

  @override
  void didUpdateWidget(EventShell old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) _last.clear();
    _last[_index] = widget.location;
  }

  void _select(int i) {
    final root = '/e/${widget.eventId}/${_tabs[i]}';
    context.go(i == _index ? root : _last[i] ?? root);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: widget.child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _select,
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
