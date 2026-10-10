import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final meta = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: agenda.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (sessions) {
            final stages = {for (final s in sessions) s.stage}.toList();
            final shown = sessions
                .where((s) => _stage == null || s.stage == _stage)
                .toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event != null)
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      event.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: meta,
                                    ),
                                  ),
                                  Text(' · ${event.dates}', style: meta),
                                ],
                              ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.tabAgenda,
                              style: theme.textTheme.headlineLarge,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: l10n.myEvents,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => context.go('/events'),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      for (final st in [null, ...stages])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(st ?? l10n.agendaAllStages),
                            selected: _stage == st,
                            onSelected: (_) => setState(() => _stage = st),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final s in shown)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _SessionTile(widget.eventId, s),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final t = theme.textTheme;
    final secondary = t.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (session.isBreak) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                session.start,
                style: secondary?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(session.title, style: secondary)),
          ],
        ),
      );
    }
    final live = session.isLive;
    final speakers = session.speakers.map((p) => p.name).join(', ');
    return EhoCard(
      borderColor: live ? context.eho.live : null,
      onTap: () => context.push('/e/$eventId/session/${session.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, child: Text(session.start, style: t.titleSmall)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (live) ...[
                  LiveBadge(l10n.agendaLiveEchoOn),
                  const SizedBox(height: 8),
                ],
                Text(
                  session.title,
                  style: t.titleMedium?.copyWith(height: 1.3),
                ),
                const SizedBox(height: 6),
                Text(
                  speakers.isEmpty
                      ? session.stage
                      : '${session.stage} · $speakers',
                  style: secondary,
                ),
              ],
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final live = s.isLive;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface,
                  foregroundColor: scheme.onSurface,
                ),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/e/$eventId/agenda'),
              ),
            ),
            const SizedBox(height: 18),
            if (s.track.isNotEmpty || live)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (s.track.isNotEmpty)
                      _Pill(
                        label: s.track,
                        color: scheme.primaryContainer,
                        foreground: eho.primaryPressed,
                      ),
                    if (live)
                      _Pill(
                        label: l10n.agendaLiveNow,
                        color: eho.liveContainer,
                        foreground: eho.onLiveContainer,
                        dot: eho.live,
                      ),
                  ],
                ),
              ),
            Text(
              s.title,
              style: t.headlineMedium?.copyWith(fontSize: 30, height: 1.08),
            ),
            const SizedBox(height: 10),
            Text(
              '${s.start}–${s.end} · ${s.stage}',
              style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (s.description.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(s.description, style: t.bodyLarge),
            ],
            for (final sp in s.speakers) ...[
              const SizedBox(height: 18),
              EhoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: eho.ink,
                      foregroundColor: eho.onInk,
                      child: Text(
                        _initials(sp.name),
                        style: t.titleSmall?.copyWith(color: eho.onInk),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sp.name, style: t.titleMedium),
                          Text(
                            sp.title,
                            style: t.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            EhoCard(
              color: eho.ink,
              radius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.graphic_eq, size: 22, color: eho.onInkLive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.agendaEchoOnTitle,
                          style: t.titleMedium?.copyWith(color: eho.onInk),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.agendaEchoOnBody,
                    style: t.bodySmall?.copyWith(
                      color: eho.onInkMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: eho.onInk,
                      foregroundColor: eho.ink,
                    ),
                    onPressed: () =>
                        context.push('/e/$eventId/session/$sessionId/echo'),
                    child: Text(l10n.sessionOpenEcho),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: Text(l10n.sessionShowOnMap(s.stage)),
              onPressed: () {
                final id = _stageFeatureId(ref, s.stage);
                context.go(
                  id == null ? '/e/$eventId/map' : '/e/$eventId/map/stand/$id',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) => name
    .split(' ')
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0])
    .join()
    .toUpperCase();

/// Small rounded label above the title (track, "LIVE NOW").
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.foreground,
    this.dot,
  });

  final String label;
  final Color color;
  final Color foreground;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
