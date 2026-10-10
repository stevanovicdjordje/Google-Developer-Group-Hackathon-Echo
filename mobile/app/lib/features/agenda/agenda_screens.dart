import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../join/join_screens.dart';

final agendaProvider = FutureProvider.family<List<Session>, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).agenda(eventId),
);

/// Agenda tab: sessions by time, filterable by stage.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  String? _stage;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider(widget.eventId));
    final event = ref.watch(eventSummaryProvider(widget.eventId)).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(event?.name ?? 'Agenda'),
        actions: [
          IconButton(
            tooltip: 'My events',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.go('/events'),
          ),
        ],
      ),
      body: agenda.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (sessions) {
          final stages = {for (final s in sessions) s.stage}.toList();
          final shown = sessions
              .where((s) => _stage == null || s.stage == _stage)
              .toList();
          return ListView(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    for (final st in [null, ...stages])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(st ?? 'All stages'),
                          selected: _stage == st,
                          onSelected: (_) => setState(() => _stage = st),
                        ),
                      ),
                  ],
                ),
              ),
              for (final s in shown) _SessionTile(widget.eventId, s),
            ],
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile(this.eventId, this.session);

  final String eventId;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (session.isBreak) {
      return ListTile(
        leading: Text(session.start, style: t.labelLarge),
        title: Text(session.title, style: t.bodyMedium),
        dense: true,
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Text(session.start, style: t.labelLarge),
        title: Text(session.title),
        subtitle: Text(
          '${session.stage} · ${session.speakers.map((p) => p.name).join(', ')}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/e/$eventId/session/${session.id}'),
      ),
    );
  }
}

/// `/e/{eventId}/session/{sessionId}`: talk details, entry to Echo.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
  });

  final String eventId;
  final String sessionId;

  /// Finds the stage on the published venue map so the map opens on it.
  String? _stageFeatureId(WidgetRef ref, String stage) {
    final event = ref.read(publishedEventProvider(eventId)).value;
    if (event == null) return null;
    for (final f in event.map.features) {
      if (f.name == stage) return f.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(agendaProvider(eventId)).value ?? const [];
    final s = sessions.where((x) => x.id == sessionId).firstOrNull;
    final t = Theme.of(context).textTheme;
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (s.track.isNotEmpty) Text(s.track.toUpperCase(), style: t.labelLarge),
          const SizedBox(height: 4),
          Text(s.title, style: t.headlineSmall),
          const SizedBox(height: 8),
          Text('${s.start}–${s.end} · ${s.stage}', style: t.titleMedium),
          const SizedBox(height: 16),
          Text(s.description, style: t.bodyLarge),
          const SizedBox(height: 16),
          for (final sp in s.speakers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(sp.name[0])),
              title: Text(sp.name),
              subtitle: Text(sp.title),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.graphic_eq),
            label: const Text('Open Echo: live transcript & AI'),
            onPressed: () =>
                context.push('/e/$eventId/session/$sessionId/echo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.place_outlined),
            label: Text('Show ${s.stage} on map'),
            onPressed: () {
              final id = _stageFeatureId(ref, s.stage);
              context.go(
                id == null ? '/e/$eventId/map' : '/e/$eventId/map/stand/$id',
              );
            },
          ),
        ],
      ),
    );
  }
}
