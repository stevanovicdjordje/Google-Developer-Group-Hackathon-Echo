import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';

/// Map tab: the venue map from `feature:maps`, plus the agreed meeting spot.
class MapTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(meetingSpotProvider);
    return Column(
      children: [
        Expanded(
          child: MapViewerScreen(
            key: ValueKey('$eventId/$featureId'),
            eventId: eventId,
            initialFeatureId: featureId,
            markerId: markerId,
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
                  onPressed: () => _showSpot(context, ref, spot.place),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showSpot(BuildContext context, WidgetRef ref, String place) {
    final event = ref.read(publishedEventProvider(eventId)).value;
    final id = event?.map.features.where((f) => f.name == place).firstOrNull?.id;
    if (id != null) context.go('/e/$eventId/map/stand/$id');
  }
}
