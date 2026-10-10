import 'dart:math' as math;

import '../model/map_models.dart';

/// Whether [p] lies inside the (implicitly closed) polygon [poly].
bool pointInPolygon(PlanPoint p, List<PlanPoint> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// The four corners of a rect geometry.
List<PlanPoint> rectCorners(Geometry g) {
  final a = g.coords[0], b = g.coords[1];
  return [
    PlanPoint(a.x, a.y),
    PlanPoint(b.x, a.y),
    PlanPoint(b.x, b.y),
    PlanPoint(a.x, b.y),
  ];
}

/// Outline of an area geometry (rect or polygon); empty for points.
List<PlanPoint> outline(Geometry g) => switch (g.kind) {
  GeometryKind.rect => rectCorners(g),
  GeometryKind.polygon => g.coords,
  GeometryKind.point => const [],
};

double _area(List<PlanPoint> pts) {
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    s += a.x * b.y - b.x * a.y;
  }
  return (s / 2).abs();
}

/// Finds the feature under a tap at [p] (plan pixels). Points (stands, POIs)
/// are hit within [tolerance] plan pixels. When several match, the smallest
/// wins, so a stand inside a hall is selectable. QR markers are ignored.
Feature? featureAt(
  Iterable<Feature> features,
  PlanPoint p, {
  required double tolerance,
}) {
  Feature? best;
  var bestScore = double.infinity;
  for (final f in features) {
    if (f.type == FeatureType.marker) continue;
    final g = f.geometry;
    double? score;
    if (g.kind == GeometryKind.point) {
      final c = g.coords.first;
      final d = math.sqrt(math.pow(c.x - p.x, 2) + math.pow(c.y - p.y, 2));
      if (d <= tolerance) score = d; // points beat areas
    } else {
      final o = outline(g);
      if (pointInPolygon(p, o)) score = tolerance + _area(o);
    }
    if (score != null && score < bestScore) {
      best = f;
      bestScore = score;
    }
  }
  return best;
}
