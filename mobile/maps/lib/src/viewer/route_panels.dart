import 'package:flutter/material.dart';

import '../../l10n/maps_localizations.dart';
import '../model/map_models.dart';
import '../model/route_models.dart';
import 'labels.dart';

/// One line about the GPS state ("tražim signal", "neprecizan", …).
class GpsHintCard extends StatelessWidget {
  const GpsHintCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.gps_not_fixed, color: MapPalette.of(context).route),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

/// Distance, time and the "no stairs" switch of the shown route.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.target,
    required this.route,
    required this.loading,
    required this.accessible,
    required this.onAccessible,
    required this.onClose,
  });

  final Feature target;

  /// Null while the first answer is loading.
  final MapRoute? route;
  final bool loading;

  /// Null hides the "no stairs" switch (single floor).
  final bool? accessible;
  final ValueChanged<bool> onAccessible;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final theme = Theme.of(context);
    final r = route;

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  color: MapPalette.of(context).route,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.routeTo(target.name),
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: l10n.closeRoute,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  if (r == null || loading) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: r == null
                        ? Text(l10n.routeLoading)
                        : Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: l10n.routeSummary(
                                    r.distanceMeters.round(),
                                    r.minutes,
                                  ),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (r.distanceEstimated)
                                  TextSpan(
                                    text: '  ${l10n.routeEstimated}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                  ),
                  if (accessible != null)
                    FilterChip(
                      avatar: const Icon(Icons.accessible, size: 18),
                      label: Text(l10n.routeNoStairs),
                      selected: accessible!,
                      onSelected: onAccessible,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Idite liftom na sprat X" with a button that switches the floor.
class RouteFloorBanner extends StatelessWidget {
  const RouteFloorBanner({
    super.key,
    required this.text,
    required this.icon,
    required this.onShow,
  });

  final String text;
  final IconData icon;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    return Card(
      elevation: 4,
      color: palette.route,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            Icon(icon, color: palette.onRoute),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: palette.onRoute),
              ),
            ),
            TextButton(
              onPressed: onShow,
              style: TextButton.styleFrom(foregroundColor: palette.onRoute),
              child: Text(MapsLocalizations.of(context).routeShowFloor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner while the attendee taps where they are.
class PickStartBanner extends StatelessWidget {
  const PickStartBanner({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            Icon(Icons.touch_app, color: MapPalette.of(context).route),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.routePickHint,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
          ],
        ),
      ),
    );
  }
}

/// The start the attendee chose: a feature, or null for "tap on the map".
class StartChoice {
  const StartChoice(this.feature);

  final Feature? feature;
}

/// "Odakle krećete?": QR markers and entrances, or pick on the map.
class StartPicker extends StatelessWidget {
  const StartPicker({
    super.key,
    required this.starts,
    required this.floorNames,
  });

  final List<Feature> starts;

  /// Floor names by id; empty for a single floor.
  final Map<String, String> floorNames;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.routeFromTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in starts)
                  ListTile(
                    minTileHeight: 60,
                    leading: Icon(
                      f.type == FeatureType.marker
                          ? Icons.qr_code_2
                          : featureIcon(f),
                    ),
                    title: Text(f.name),
                    subtitle: floorNames[f.floorId] == null
                        ? null
                        : Text(floorNames[f.floorId]!),
                    onTap: () => Navigator.pop(context, StartChoice(f)),
                  ),
                ListTile(
                  minTileHeight: 60,
                  leading: const Icon(Icons.touch_app),
                  title: Text(l10n.routePickOnMap),
                  onTap: () => Navigator.pop(context, const StartChoice(null)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
