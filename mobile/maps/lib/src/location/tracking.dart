import 'dart:math' as math;

import '../model/map_models.dart';
import '../model/route_models.dart';
import 'georef.dart';
import 'location_source.dart';

/// Worse than this, the GPS dot is shown as a hint only, not used as the
/// route start (indoor GPS is often 10–50 m off).
const goodAccuracyMeters = 25.0;

/// A GPS fix placed on a floor plan.
class PlanFix {
  const PlanFix({
    required this.floorId,
    required this.at,
    required this.accuracyMeters,
    required this.accuracyPixels,
    required this.metersPerPixel,
    required this.inside,
  });

  final String floorId;
  final PlanPoint at;
  final double accuracyMeters;
  final double accuracyPixels;
  final double metersPerPixel;

  /// The fix (with its accuracy) overlaps the plan.
  final bool inside;

  /// Good enough to start a route from and to follow it.
  bool get usable => inside && accuracyMeters <= goodAccuracyMeters;
}

/// Places [fix] on [floor]; null if the floor isn't georeferenced. GPS has no
/// floor, so the caller passes the floor the attendee is looking at.
PlanFix? placeFix(GpsFix fix, Floor floor) {
  final g = Georef.of(floor);
  if (g == null) return null;
  final at = g.toPixel(fix.position);
  final accPx = g.metersToPixels(fix.accuracyMeters);
  final margin = accPx + g.metersToPixels(10);
  return PlanFix(
    floorId: floor.id,
    at: at,
    accuracyMeters: fix.accuracyMeters,
    accuracyPixels: accPx,
    metersPerPixel: g.metersPerPixel,
    inside:
        at.x >= -margin &&
        at.y >= -margin &&
        at.x <= floor.width + margin &&
        at.y <= floor.height + margin,
  );
}

double _dist(PlanPoint a, PlanPoint b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

/// Shortest distance from [p] to the polyline [line] (plan pixels).
double distanceToPolyline(PlanPoint p, List<PlanPoint> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return _dist(p, line.first);
  var best = double.infinity;
  for (var i = 0; i + 1 < line.length; i++) {
    final a = line[i], b = line[i + 1];
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0
        ? 0.0
        : (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
    final d = _dist(p, PlanPoint(a.x + t * dx, a.y + t * dy));
    if (d < best) best = d;
  }
  return best;
}

enum TrackStep { onRoute, offRoute, arrived }

/// What following [route] with [fix] means right now.
TrackStep trackRoute(MapRoute route, PlanFix fix) {
  final mpp = fix.metersPerPixel;
  final arriveWithin = math.max(6.0, math.min(fix.accuracyMeters, 12.0));
  if (route.legs.last.floorId == fix.floorId &&
      _dist(fix.at, route.end) * mpp <= arriveWithin) {
    return TrackStep.arrived;
  }
  final legs = route.legs.where((l) => l.floorId == fix.floorId).toList();
  // On a floor the route doesn't pass (e.g. in the lift): nothing to judge.
  if (legs.isEmpty) return TrackStep.onRoute;
  final off = legs
      .map((l) => distanceToPolyline(fix.at, l.points))
      .reduce(math.min);
  final allowed = math.max(15.0, fix.accuracyMeters * 1.5);
  return off * mpp > allowed ? TrackStep.offRoute : TrackStep.onRoute;
}
