import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/maps_localizations.dart';
import '../editor/editor_providers.dart';
import '../editor/maps_api.dart';
import '../model/stats_models.dart';

/// Date range of the stats screen.
enum StatsRange { today, days7, days30, event }

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2026-10-11" → "11.10."
String _short(String ymd) {
  final p = ymd.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.' : ymd;
}

/// [from, to] (YYYY-MM-DD, UTC like the server) of [range].
(String, String) statsDates(
  StatsRange range,
  OrganizerEvent event,
  DateTime now,
) {
  final today = DateTime.utc(now.year, now.month, now.day);
  DateTime back(int days) => today.subtract(Duration(days: days));
  return switch (range) {
    StatsRange.today => (_ymd(today), _ymd(today)),
    StatsRange.days7 => (_ymd(back(6)), _ymd(today)),
    StatsRange.days30 => (_ymd(back(29)), _ymd(today)),
    StatsRange.event => (event.startDate, event.endDate),
  };
}

typedef StatsQuery = ({String eventId, String from, String to});

final _statsEventProvider = FutureProvider.autoDispose
    .family<OrganizerEvent, String>(
      (ref, id) => ref.watch(mapsApiProvider).getEvent(id),
      retry: (_, _) => null,
    );

final mapsStatsProvider = FutureProvider.autoDispose
    .family<EventStats, StatsQuery>(
      (ref, q) => ref
          .watch(mapsApiProvider)
          .getStats(q.eventId, from: q.from, to: q.to),
      retry: (_, _) => null,
    );

/// Organizer view of how attendees use the map (`/o/e/{eventId}/stats`).
class MapStatsScreen extends ConsumerStatefulWidget {
  const MapStatsScreen({super.key, required this.eventId, this.now});

  final String eventId;

  /// Clock for tests.
  final DateTime Function()? now;

  @override
  ConsumerState<MapStatsScreen> createState() => _MapStatsScreenState();
}

class _MapStatsScreenState extends ConsumerState<MapStatsScreen> {
  StatsRange _range = StatsRange.event;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final event = ref.watch(_statsEventProvider(widget.eventId));
    final now = (widget.now ?? DateTime.now)().toUtc();

    Widget body;
    StatsQuery? query;
    if (event.value case final e?) {
      final (from, to) = statsDates(_range, e, now);
      query = (eventId: widget.eventId, from: from, to: to);
      final stats = ref.watch(mapsStatsProvider(query));
      body = stats.when(
        skipLoadingOnRefresh: false,
        data: (s) => _StatsBody(stats: s),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _Failed(onRetry: () => ref.invalidate(mapsStatsProvider(query!))),
      );
    } else if (event.hasError) {
      body = _Failed(
        onRetry: () => ref.invalidate(_statsEventProvider(widget.eventId)),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.value == null
              ? l10n.statsTitle
              : '${l10n.statsTitle} · ${event.value!.name}',
        ),
        actions: [
          IconButton(
            tooltip: l10n.reload,
            icon: const Icon(Icons.refresh),
            onPressed: query == null
                ? null
                : () => ref.invalidate(mapsStatsProvider(query!)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<StatsRange>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: StatsRange.event,
                    label: Text(l10n.statsRangeEvent),
                  ),
                  ButtonSegment(
                    value: StatsRange.today,
                    label: Text(l10n.statsRangeToday),
                  ),
                  ButtonSegment(
                    value: StatsRange.days7,
                    label: Text(l10n.statsRange7),
                  ),
                  ButtonSegment(
                    value: StatsRange.days30,
                    label: Text(l10n.statsRange30),
                  ),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.statsError),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final theme = Theme.of(context);
    final t = stats.totals;
    final range = stats.from == stats.to
        ? _short(stats.from)
        : '${_short(stats.from)} – ${_short(stats.to)}';

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(range, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tile(l10n.statsSearches, t.searches, Icons.search),
                _Tile(
                  l10n.statsNoResults,
                  t.searchesNoResults,
                  Icons.search_off,
                ),
                _Tile(
                  l10n.statsFeatureViews,
                  t.featureViews,
                  Icons.touch_app_outlined,
                ),
                _Tile(l10n.statsRoutes, t.routes, Icons.directions_walk),
                _Tile(l10n.statsQrScans, t.qrScans, Icons.qr_code_2),
              ],
            ),
            if (stats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  l10n.statsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              )
            else ...[
              if (stats.days.length > 1)
                _Section(
                  title: l10n.statsPerDay,
                  hint: l10n.statsPerDayHint,
                  child: DailyBars(days: stats.days),
                ),
              if (stats.topNoResults.isNotEmpty)
                _Section(
                  title: l10n.statsNotFound,
                  hint: l10n.statsNotFoundHint,
                  emphasized: true,
                  child: _Ranked([
                    for (final e in stats.topNoResults) (e.query, e.count),
                  ]),
                ),
              _Columns(
                children: [
                  if (stats.topSearches.isNotEmpty)
                    _Section(
                      title: l10n.statsTopSearches,
                      child: _Ranked([
                        for (final e in stats.topSearches) (e.query, e.count),
                      ]),
                    ),
                  if (stats.topFeatures.isNotEmpty)
                    _Section(
                      title: l10n.statsTopFeatures,
                      child: _Ranked(_named(l10n, stats.topFeatures)),
                    ),
                  if (stats.topRouteTargets.isNotEmpty)
                    _Section(
                      title: l10n.statsTopRoutes,
                      child: _Ranked(_named(l10n, stats.topRouteTargets)),
                    ),
                  if (stats.qrScans.isNotEmpty)
                    _Section(
                      title: l10n.statsQrList,
                      child: _Ranked(_named(l10n, stats.qrScans)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.statsPrivacy,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static List<(String, int)> _named(
    MapsLocalizations l10n,
    List<FeatureCount> list,
  ) => [
    for (final f in list)
      (f.name.isEmpty ? l10n.statsRemoved : f.name, f.count),
  ];
}

/// Two columns of sections on wide screens, one on phones.
class _Columns extends StatelessWidget {
  const _Columns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 640) return Column(children: children);
      final left = [for (var i = 0; i < children.length; i += 2) children[i]];
      final right = [for (var i = 1; i < children.length; i += 2) children[i]];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: 16),
          Expanded(child: Column(children: right)),
        ],
      );
    },
  );
}

/// A headline number.
class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text('$value', style: theme.textTheme.headlineMedium),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.hint,
    this.emphasized = false,
  });

  final String title;
  final String? hint;
  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        margin: EdgeInsets.zero,
        color: emphasized ? theme.colorScheme.secondaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Label, count and a thin bar relative to the largest count.
class _Ranked extends StatelessWidget {
  const _Ranked(this.rows);

  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = rows.fold(1, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      children: [
        for (final (label, count) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FractionallySizedBox(
                  widthFactor: count / max,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One bar per day (all interactions); tap or hover shows the exact number.
class DailyBars extends StatelessWidget {
  const DailyBars({super.key, required this.days});

  final List<StatsCounts> days;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final theme = Theme.of(context);
    final max = days.fold(0, (m, d) => d.interactions > m ? d.interactions : m);
    const height = 120.0;
    final axis = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$max', style: axis),
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Tooltip(
                    message: l10n.statsDayTooltip(
                      _short(d.date),
                      d.interactions,
                    ),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      // The whole column is the hit target, not just the bar.
                      color: Colors.transparent,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        height: max == 0
                            ? 0
                            : (height * d.interactions / max).clamp(
                                d.interactions > 0 ? 2.0 : 0.0,
                                height,
                              ),
                        constraints: const BoxConstraints(maxWidth: 28),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(_short(days.first.date), style: axis),
            const Spacer(),
            Text(_short(days.last.date), style: axis),
          ],
        ),
      ],
    );
  }
}
