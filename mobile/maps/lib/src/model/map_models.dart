/// Venue map data, mirroring `contracts/maps/openapi.yaml` (schemas Floor,
/// Feature, Geometry, Graph). Parsed from API JSON and from Firestore
/// documents of the published map (`contracts/maps/realtime.md`).
library;

/// A position on a floor plan in image pixels (x right, y down).
class PlanPoint {
  const PlanPoint(this.x, this.y);

  factory PlanPoint.fromJson(Map<String, dynamic> j) =>
      PlanPoint(_num(j['x']), _num(j['y']));

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      other is PlanPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PlanPoint($x, $y)';
}

class LatLngDeg {
  const LatLngDeg(this.lat, this.lng);

  factory LatLngDeg.fromJson(Map<String, dynamic> j) =>
      LatLngDeg(_num(j['lat']), _num(j['lng']));

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class ControlPoint {
  const ControlPoint({required this.px, required this.latLng});

  factory ControlPoint.fromJson(Map<String, dynamic> j) => ControlPoint(
    px: PlanPoint.fromJson(_map(j['px'])),
    latLng: LatLngDeg.fromJson(_map(j['latLng'])),
  );

  final PlanPoint px;
  final LatLngDeg latLng;

  Map<String, dynamic> toJson() => {
    'px': px.toJson(),
    'latLng': latLng.toJson(),
  };
}

class Georeference {
  const Georeference({
    required this.controlPoints,
    required this.metersPerPixel,
  });

  factory Georeference.fromJson(Map<String, dynamic> j) => Georeference(
    controlPoints: _list(j['controlPoints'])
        .map(ControlPoint.fromJson)
        .toList(),
    metersPerPixel: _num(j['metersPerPixel']),
  );

  final List<ControlPoint> controlPoints;
  final double metersPerPixel;
}

class Floor {
  const Floor({
    required this.id,
    required this.name,
    required this.order,
    required this.imagePath,
    required this.width,
    required this.height,
    this.georef,
  });

  /// [id] overrides `j['id']` (Firestore documents carry the ID separately).
  factory Floor.fromJson(Map<String, dynamic> j, {String? id}) => Floor(
    id: id ?? j['id'] as String,
    name: j['name'] as String? ?? '',
    order: (j['order'] as num?)?.toInt() ?? 0,
    imagePath: j['imagePath'] as String? ?? '',
    width: (j['width'] as num).toInt(),
    height: (j['height'] as num).toInt(),
    georef: j['georef'] == null
        ? null
        : Georeference.fromJson(_map(j['georef'])),
  );

  final String id;
  final String name;
  final int order;
  final String imagePath;
  final int width;
  final int height;
  final Georeference? georef;
}

enum FeatureType { room, stand, poi, marker }

enum GeometryKind { point, rect, polygon }

enum SponsorTier { none, bronze, silver, gold }

class Geometry {
  const Geometry(this.kind, this.coords);

  factory Geometry.fromJson(Map<String, dynamic> j) => Geometry(
    GeometryKind.values.byName(j['kind'] as String),
    _list(j['coords']).map(PlanPoint.fromJson).toList(),
  );

  final GeometryKind kind;
  final List<PlanPoint> coords;

  /// Mean of the coordinates; a label/tap anchor for any kind.
  PlanPoint get center {
    var x = 0.0, y = 0.0;
    for (final p in coords) {
      x += p.x;
      y += p.y;
    }
    return coords.isEmpty
        ? const PlanPoint(0, 0)
        : PlanPoint(x / coords.length, y / coords.length);
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'coords': [for (final c in coords) c.toJson()],
  };
}

class Feature {
  const Feature({
    required this.id,
    required this.type,
    required this.floorId,
    required this.name,
    required this.geometry,
    this.description = '',
    this.entranceNodeId,
    this.capacity,
    this.company = '',
    this.category = '',
    this.link,
    this.sponsorTier = SponsorTier.none,
    this.poiKind,
  });

  factory Feature.fromJson(Map<String, dynamic> j, {String? id}) {
    final tier = j['sponsorTier'] as String?;
    return Feature(
      id: id ?? j['id'] as String,
      type: FeatureType.values.byName(j['type'] as String),
      floorId: j['floorId'] as String,
      name: j['name'] as String? ?? '',
      geometry: Geometry.fromJson(_map(j['geometry'])),
      description: j['description'] as String? ?? '',
      entranceNodeId: _nonEmpty(j['entranceNodeId']),
      capacity: (j['capacity'] as num?)?.toInt(),
      company: j['company'] as String? ?? '',
      category: j['category'] as String? ?? '',
      link: _nonEmpty(j['link']),
      sponsorTier: tier == null || tier.isEmpty
          ? SponsorTier.none
          : SponsorTier.values.byName(tier),
      poiKind: _nonEmpty(j['poiKind']),
    );
  }

  final String id;
  final FeatureType type;
  final String floorId;
  final String name;
  final Geometry geometry;
  final String description;
  final String? entranceNodeId;
  final int? capacity;
  final String company;
  final String category;
  final String? link;
  final SponsorTier sponsorTier;
  final String? poiKind;

  /// Whether a route can end at this feature.
  bool get routable => entranceNodeId != null;
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.x,
    required this.y,
    this.connector,
    this.connectorKind,
  });

  factory GraphNode.fromJson(Map<String, dynamic> j) => GraphNode(
    id: j['id'] as String,
    x: _num(j['x']),
    y: _num(j['y']),
    connector: _nonEmpty(j['connector']),
    connectorKind: _nonEmpty(j['connectorKind']),
  );

  final String id;
  final double x;
  final double y;
  final String? connector;
  final String? connectorKind;

  PlanPoint get point => PlanPoint(x, y);

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    if (connector != null) 'connector': connector,
    if (connectorKind != null) 'connectorKind': connectorKind,
  };
}

class GraphEdge {
  const GraphEdge(this.from, this.to);

  factory GraphEdge.fromJson(Map<String, dynamic> j) =>
      GraphEdge(j['from'] as String, j['to'] as String);

  final String from;
  final String to;

  Map<String, dynamic> toJson() => {'from': from, 'to': to};
}

class FloorGraph {
  const FloorGraph({
    required this.floorId,
    required this.nodes,
    required this.edges,
  });

  factory FloorGraph.fromJson(Map<String, dynamic> j, {String? floorId}) =>
      FloorGraph(
        floorId: floorId ?? j['floorId'] as String,
        nodes: _list(j['nodes']).map(GraphNode.fromJson).toList(),
        edges: _list(j['edges']).map(GraphEdge.fromJson).toList(),
      );

  final String floorId;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
}

/// A whole venue map (draft or published).
class VenueMap {
  const VenueMap({
    required this.floors,
    required this.features,
    required this.graphs,
    this.version = 0,
  });

  factory VenueMap.fromJson(Map<String, dynamic> j) {
    final floors = _list(j['floors']).map(Floor.fromJson).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return VenueMap(
      floors: floors,
      features: _list(j['features']).map(Feature.fromJson).toList(),
      graphs: _list(j['graphs']).map(FloorGraph.fromJson).toList(),
    );
  }

  static const empty = VenueMap(floors: [], features: [], graphs: []);

  final List<Floor> floors;
  final List<Feature> features;
  final List<FloorGraph> graphs;

  /// Published version (0 for drafts / never published).
  final int version;

  Iterable<Feature> featuresOn(String floorId) =>
      features.where((f) => f.floorId == floorId);
}

double _num(Object? v) => (v as num).toDouble();

Map<String, dynamic> _map(Object? v) => Map<String, dynamic>.from(v as Map);

Iterable<Map<String, dynamic>> _list(Object? v) =>
    ((v as List?) ?? const []).map(_map);

String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;
