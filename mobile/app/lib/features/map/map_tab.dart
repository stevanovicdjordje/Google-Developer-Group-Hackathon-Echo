import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';

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
    final spotId = _spotFeatureId;
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
                : 'Meeting: ${spot.personName}',
          ),
        ),
        if (spot != null)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: SafeArea(
              top: false,
              child: ListTile(
                leading: const Icon(Icons.handshake_outlined),
                title: Text('Meeting ${spot.personName}'),
                subtitle: Text('at ${spot.place}'),
                trailing: TextButton(
                  onPressed: () => _showSpot(spot.place),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showSpot(String place) {
    final event = ref.read(publishedEventProvider(widget.eventId)).value;
    final id = event?.map.features.where((f) => f.name == place).firstOrNull?.id;
    if (id != null) setState(() => _spotFeatureId = id);
  }
}
