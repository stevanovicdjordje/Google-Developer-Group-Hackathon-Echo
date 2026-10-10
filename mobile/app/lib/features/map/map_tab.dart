import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../l10n/app_localizations.dart';

/// Map tab: the venue map from `feature:maps`, plus the agreed meeting spot.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({
    super.key,
    required this.eventId,
    this.featureId,
    this.markerId,
  });

  final String eventId;
  final String? featureId;
  final String? markerId;

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  /// Feature of the meeting spot being shown on the map, if any. Kept as local
  /// state so the router stays untouched; the viewer is re-keyed when it changes.
  String? _spotFeatureId;

  @override
  Widget build(BuildContext context) {
    final eventId = widget.eventId;
    final spot = ref.watch(meetingSpotProvider);
    // `?spot=1` (Messages > "Show on map") highlights the meeting spot like the
    // "Show" button does, without a router change.
    final wantSpot =
        GoRouterState.of(context).uri.queryParameters['spot'] == '1';
    final autoId = wantSpot && spot != null
        ? _featureIdOf(
            spot.place,
            ref.watch(publishedEventProvider(eventId)).value,
          )
        : null;
    if (autoId != null && autoId != _spotFeatureId) {
      // Remember it, so the highlight survives leaving and re-entering the tab.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _spotFeatureId = autoId);
      });
    }
    final spotId = autoId ?? _spotFeatureId;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eho = context.eho;
    return Column(
      children: [
        Expanded(
          child: MapViewerScreen(
            key: ValueKey('$eventId/${widget.featureId}/$spotId'),
            eventId: eventId,
            initialFeatureId: widget.featureId,
            markerId: widget.markerId,
            highlightFeatureId: spot == null ? null : spotId,
            highlightLabel: spot == null || spotId == null
                ? null
                : l10n.mapMeetingHighlight(spot.personName),
          ),
        ),
        if (spot != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Material(
              color: scheme.surface,
              elevation: 4,
              shadowColor: scheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: eho.liveContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.place_outlined,
                        size: 20,
                        color: eho.onLiveContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.mapMeetingTitle(spot.personName),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.mapMeetingAt(spot.place),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: theme.textTheme.labelLarge,
                      ),
                      onPressed: () => _showSpot(spot.place),
                      child: Text(l10n.mapShowSpot),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The map feature whose name is [place], on the published event.
  String? _featureIdOf(String place, PublishedEvent? event) =>
      event?.map.features.where((f) => f.name == place).firstOrNull?.id;

  void _showSpot(String place) {
    final id = _featureIdOf(
      place,
      ref.read(publishedEventProvider(widget.eventId)).value,
    );
    if (id != null) setState(() => _spotFeatureId = id);
  }
}
