import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../model/map_models.dart';
import '../model/route_models.dart';
import 'labels.dart';
import 'plan_projection.dart';

/// The GPS accuracy circle (plan pixels scaled to the current zoom).
class GpsAccuracyLayer extends StatelessWidget {
  const GpsAccuracyLayer({
    super.key,
    required this.at,
    required this.radiusPixels,
    required this.proj,
    this.weak = false,
  });

  final PlanPoint at;
  final double radiusPixels;
  final PlanProjection proj;

  /// Too imprecise to navigate by: drawn fainter.
  final bool weak;

  @override
  Widget build(BuildContext context) {
    final palette = MapPalette.of(context);
    final scale = proj.scaleAt(MapCamera.of(context).zoom);
    return CircleLayer(
      circles: [
        CircleMarker(
          key: const ValueKey('gps-accuracy'),
          point: proj.toLatLng(at),
          radius: radiusPixels * scale,
          color: palette.route.withValues(alpha: weak ? 0.08 : 0.15),
          borderColor: palette.route.withValues(alpha: weak ? 0.3 : 0.5),
          borderStrokeWidth: 1.5,
        ),
      ],
    );
  }
}

/// The route's lines on [floorId] (drawn under the labels).
Widget routeLines(
  BuildContext context,
  MapRoute route,
  String floorId,
  PlanProjection proj,
) {
  final palette = MapPalette.of(context);
  return PolylineLayer(
    polylines: [
      for (final leg in route.legs)
        if (leg.floorId == floorId && leg.points.length > 1)
          Polyline(
            points: [for (final p in leg.points) proj.toLatLng(p)],
            color: palette.route,
            strokeWidth: 7,
            borderColor: palette.scheme.surface,
            borderStrokeWidth: 2.5,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
    ],
  );
}

/// Start dot, destination pin and lift/stairs points on [floorId]
/// (drawn above the labels).
Widget routeMarkers(
  BuildContext context,
  MapRoute route,
  String floorId,
  PlanProjection proj,
) {
  final palette = MapPalette.of(context);
  final legs = route.legs;
  final markers = <Marker>[];

  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
    if (leg.floorId != floorId) continue;
    // Where this leg leaves the floor by lift/stairs.
    if (i + 1 < legs.length) {
      markers.add(
        _iconMarker(
          proj.toLatLng(leg.points.last),
          legs[i + 1].arriveBy == ArriveBy.stairs
              ? Icons.stairs
              : Icons.elevator,
          palette,
        ),
      );
    }
    // Where this leg arrives on the floor.
    if (i > 0) {
      markers.add(
        _iconMarker(
          proj.toLatLng(leg.points.first),
          leg.arriveBy == ArriveBy.stairs ? Icons.stairs : Icons.elevator,
          palette,
        ),
      );
    }
  }
  if (legs.first.floorId == floorId) {
    markers.add(
      Marker(
        key: const ValueKey('route-start'),
        point: proj.toLatLng(route.start),
        width: 22,
        height: 22,
        child: _Dot(color: palette.route, size: 16),
      ),
    );
  }
  if (legs.last.floorId == floorId) {
    markers.add(
      Marker(
        key: const ValueKey('route-end'),
        point: proj.toLatLng(route.end),
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: Icon(Icons.location_on, size: 44, color: palette.route),
      ),
    );
  }
  return MarkerLayer(markers: markers);
}

/// "You are here" dot with a label (the scanned QR marker or a picked point).
Widget youAreHereMarker(
  BuildContext context,
  PlanPoint at,
  PlanProjection proj,
  String label,
) {
  final palette = MapPalette.of(context);
  return MarkerLayer(
    markers: [
      Marker(
        key: const ValueKey('you-are-here'),
        point: proj.toLatLng(at),
        // The dot is centered on the point; the label sits above it.
        width: 160,
        height: 100,
        child: IgnorePointer(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.route.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: _Dot(color: palette.route, size: 18),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 66,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.route,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.onRoute,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Marker _iconMarker(LatLng point, IconData icon, MapPalette palette) => Marker(
  point: point,
  width: 32,
  height: 32,
  child: IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.route,
        shape: BoxShape.circle,
        border: Border.all(color: palette.scheme.surface, width: 2),
      ),
      child: Icon(icon, size: 18, color: palette.onRoute),
    ),
  ),
);

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
      ),
    ),
  );
}
