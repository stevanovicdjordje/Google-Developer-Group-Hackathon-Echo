import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// The session to show for a room: the one live there, else the next one that
/// starts after [nowHm] ("HH:mm"). Null when there is none (breaks are skipped).
Session? sessionForStage(List<Session> sessions, String stage, String nowHm) {
  final here = sessions.where((s) => s.stage == stage && !s.isBreak).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  return here.where((s) => s.isLive).firstOrNull ??
      here.where((s) => s.start.compareTo(nowHm) > 0).firstOrNull;
}

/// The app's own details sheet for a map feature that is a stage of the event
/// (design `MapDetail.dc.html`), or null so the map shows its default sheet.
Widget? buildStageSheet(
  BuildContext context, {
  required String eventId,
  required List<Session> sessions,
  required MapFeatureSheetData data,
}) {
  final name = data.feature.name;
  if (!sessions.any((s) => s.stage == name)) return null;
  final now = TimeOfDay.now();
  final nowHm =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final session = sessionForStage(sessions, name, nowHm);
  final router = GoRouter.of(context);
  void open(String path) {
    Navigator.of(context).pop();
    router.push(path);
  }

  return MapStageSheet(
    feature: data.feature,
    floorName: data.floorName,
    route: data.route,
    routeLoading: data.routeLoading,
    session: session,
    onStartRoute: data.startRoute,
    onOpenSession: session == null
        ? null
        : () => open('/e/$eventId/session/${session.id}'),
    onOpenEcho: session == null || !session.isLive
        ? null
        : () => open('/e/$eventId/session/${session.id}/echo'),
  );
}

/// Room name, capacity, walking time, the live (or next) session and the
/// "Start route" / "Open Echo" actions.
class MapStageSheet extends StatelessWidget {
  const MapStageSheet({
    super.key,
    required this.feature,
    this.floorName,
    this.route,
    this.routeLoading = false,
    this.session,
    this.onStartRoute,
    this.onOpenSession,
    this.onOpenEcho,
  });

  final Feature feature;
  final String? floorName;
  final MapRoute? route;
  final bool routeLoading;
  final Session? session;
  final VoidCallback? onStartRoute;
  final VoidCallback? onOpenSession;

  /// Shown only for a live session.
  final VoidCallback? onOpenEcho;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final f = feature;
    final capacity = f.capacity;
    final meta = [
      if (f.description.isNotEmpty) f.description,
      if (capacity != null && capacity > 0) l10n.mapSheetCapacity(capacity),
      ?floorName,
    ].join(' · ');
    final s = session;
    final r = route;
    final hasStart = onStartRoute != null;
    final hasEcho = onOpenEcho != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: theme.textTheme.headlineMedium),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (r != null || routeLoading) ...[
                  const SizedBox(width: 12),
                  if (r != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.mapSheetWalkMinutes(r.minutes),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          l10n.mapSheetWalkDistance(r.distanceMeters.round()),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 4),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                ],
              ],
            ),
            if (s != null) ...[
              const SizedBox(height: 14),
              Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onOpenSession,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.isLive)
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: eho.live,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        l10n
                                            .mapSheetNow(s.start, s.end)
                                            .toUpperCase(),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: eho.onLiveContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  l10n.mapSheetNext(s.start).toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(s.title, style: theme.textTheme.titleSmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (hasStart || hasEcho) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (hasStart)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onStartRoute,
                        icon: const Icon(Icons.near_me_outlined, size: 18),
                        label: Text(l10n.mapSheetStartRoute),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  if (hasStart && hasEcho) const SizedBox(width: 10),
                  if (hasEcho)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenEcho,
                        icon: Icon(Icons.graphic_eq, size: 18, color: eho.live),
                        label: Text(l10n.mapSheetOpenEcho),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
