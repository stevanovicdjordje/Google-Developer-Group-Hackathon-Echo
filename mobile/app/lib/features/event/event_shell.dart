import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Design: 1 px divider on top of the bar, same line icon whether selected
    // or not (the pill marks the active tab).
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Theme(
            data: theme.copyWith(
              navigationBarTheme: theme.navigationBarTheme.copyWith(height: 80),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: l10n.tabAgenda,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  label: l10n.tabMap,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.people_outline),
                  label: l10n.tabFind,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  label: l10n.tabProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
