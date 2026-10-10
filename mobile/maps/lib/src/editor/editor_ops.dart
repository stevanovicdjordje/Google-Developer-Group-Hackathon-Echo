import 'dart:math' as math;

import '../model/map_models.dart';

/// Pure editing operations on draft map data. No I/O, so they are unit-tested.

/// A rect from two opposite corners in any order (stored as min, max corner).
Geometry rectFrom(PlanPoint a, PlanPoint b) => Geometry(GeometryKind.rect, [
  PlanPoint(math.min(a.x, b.x), math.min(a.y, b.y)),
  PlanPoint(math.max(a.x, b.x), math.max(a.y, b.y)),
]);

/// Geometry for the points tapped with an area tool: 2 points → rect,
/// 3+ → polygon. Null when there are too few points or the area is degenerate.
Geometry? areaFrom(List<PlanPoint> pts) {
  if (pts.length == 2) {
    final g = rectFrom(pts[0], pts[1]);
    final a = g.coords[0], b = g.coords[1];
    return (b.x - a.x) < 1 || (b.y - a.y) < 1 ? null : g;
  }
  if (pts.length >= 3) return Geometry(GeometryKind.polygon, List.of(pts));
  return null;
}

Geometry translate(Geometry g, double dx, double dy) =>
    Geometry(g.kind, [for (final c in g.coords) PlanPoint(c.x + dx, c.y + dy)]);

/// Moves [g] so that its center lands on [to].
Geometry moveCenterTo(Geometry g, PlanPoint to) {
  final c = g.center;
  return translate(g, to.x - c.x, to.y - c.y);
}

/// Keeps every coordinate inside a [width]×[height] plan.
Geometry clampTo(Geometry g, int width, int height) => Geometry(g.kind, [
  for (final c in g.coords)
    PlanPoint(
      c.x.clamp(0, width.toDouble()).toDouble(),
      c.y.clamp(0, height.toDouble()).toDouble(),
    ),
]);

double _dist(PlanPoint a, PlanPoint b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// The node closest to [p], optionally only within [maxDistance] plan pixels.
GraphNode? nearestNode(
  FloorGraph? graph,
  PlanPoint p, {
  double maxDistance = double.infinity,
}) {
  GraphNode? best;
  var bestD = maxDistance;
  for (final n in graph?.nodes ?? const <GraphNode>[]) {
    final d = _dist(n.point, p);
    if (d <= bestD) {
      best = n;
      bestD = d;
    }
  }
  return best;
}

final _rand = math.Random();

/// A short random node ID ("n" + 8 base-36 chars), unique within a floor.
String newNodeId(FloorGraph graph) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  while (true) {
    final id =
        'n${List.generate(8, (_) => chars[_rand.nextInt(chars.length)]).join()}';
    if (!graph.nodes.any((n) => n.id == id)) return id;
  }
}

FloorGraph emptyGraph(String floorId) =>
    FloorGraph(floorId: floorId, nodes: const [], edges: const []);

FloorGraph addNode(FloorGraph g, GraphNode node) =>
    FloorGraph(floorId: g.floorId, nodes: [...g.nodes, node], edges: g.edges);

bool hasEdge(FloorGraph g, String a, String b) => g.edges.any(
  (e) => (e.from == a && e.to == b) || (e.from == b && e.to == a),
);

/// Adds the undirected edge a–b unless it exists or is a self-loop.
FloorGraph connect(FloorGraph g, String a, String b) {
  if (a == b || hasEdge(g, a, b)) return g;
  return FloorGraph(
    floorId: g.floorId,
    nodes: g.nodes,
    edges: [...g.edges, GraphEdge(a, b)],
  );
}

/// Removes the node and every edge touching it.
FloorGraph removeNode(FloorGraph g, String id) => FloorGraph(
  floorId: g.floorId,
  nodes: [
    for (final n in g.nodes)
      if (n.id != id) n,
  ],
  edges: [
    for (final e in g.edges)
      if (e.from != id && e.to != id) e,
  ],
);

/// Replaces the node with the same ID (e.g. after moving it).
FloorGraph replaceNode(FloorGraph g, GraphNode node) => FloorGraph(
  floorId: g.floorId,
  nodes: [for (final n in g.nodes) n.id == node.id ? node : n],
  edges: g.edges,
);

/// What a feature form collects; turned into `FeatureInput`/`FeaturePatch` JSON.
class FeatureDraft {
  FeatureDraft({
    required this.type,
    required this.floorId,
    required this.geometry,
    this.name = '',
    this.description = '',
    this.capacity,
    this.company = '',
    this.category = '',
    this.link = '',
    this.sponsorTier = SponsorTier.none,
    this.poiKind,
    this.entranceNodeId,
  });

  factory FeatureDraft.of(Feature f) => FeatureDraft(
    type: f.type,
    floorId: f.floorId,
    geometry: f.geometry,
    name: f.name,
    description: f.description,
    capacity: f.capacity,
    company: f.company,
    category: f.category,
    link: f.link ?? '',
    sponsorTier: f.sponsorTier,
    poiKind: f.poiKind,
    entranceNodeId: f.entranceNodeId,
  );

  FeatureType type;
  String floorId;
  Geometry geometry;
  String name;
  String description;
  int? capacity;
  String company;
  String category;
  String link;
  SponsorTier sponsorTier;
  String? poiKind;
  String? entranceNodeId;

  /// JSON for `createFeature`, or for `updateFeature` with [patch] (type and
  /// floor can't change; "" clears text fields).
  Map<String, dynamic> toJson({bool patch = false}) {
    final isStand = type == FeatureType.stand;
    return {
      if (!patch) 'type': type.name,
      if (!patch) 'floorId': floorId,
      'name': name.trim(),
      'geometry': geometry.toJson(),
      if (patch || description.trim().isNotEmpty)
        'description': description.trim(),
      if (entranceNodeId != null) 'entranceNodeId': entranceNodeId,
      if (patch && entranceNodeId == null) 'entranceNodeId': '',
      if (type == FeatureType.room && (patch || capacity != null))
        'capacity': capacity ?? 0,
      if (isStand && (patch || company.trim().isNotEmpty))
        'company': company.trim(),
      if (isStand && (patch || category.trim().isNotEmpty))
        'category': category.trim(),
      if (isStand) 'sponsorTier': sponsorTier.name,
      if (type != FeatureType.marker && (patch || link.trim().isNotEmpty))
        'link': link.trim(),
      if (type == FeatureType.poi && poiKind != null) 'poiKind': poiKind,
    };
  }
}
