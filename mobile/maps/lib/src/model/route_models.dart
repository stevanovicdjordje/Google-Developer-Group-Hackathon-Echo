import 'map_models.dart';

/// One end of a route (`RouteEndpoint` schema): a feature, or a point on a
/// floor. Points are sent only to compute the route; the server never stores
/// them.
class RouteEndpoint {
  const RouteEndpoint.feature(String this.featureId)
    : floorId = null,
      point = null;

  const RouteEndpoint.point(String this.floorId, PlanPoint this.point)
    : featureId = null;

  final String? featureId;
  final String? floorId;
  final PlanPoint? point;

  Map<String, dynamic> toJson() => featureId != null
      ? {'featureId': featureId}
      : {'floorId': floorId, 'point': point!.toJson()};

  @override
  bool operator ==(Object other) =>
      other is RouteEndpoint &&
      other.featureId == featureId &&
      other.floorId == floorId &&
      other.point == point;

  @override
  int get hashCode => Object.hash(featureId, floorId, point);
}

/// How a route reaches a floor (`RouteLeg.arriveBy`).
enum ArriveBy { lift, stairs }

/// The part of a route on one floor (`RouteLeg` schema).
class RouteLeg {
  const RouteLeg({required this.floorId, required this.points, this.arriveBy});

  factory RouteLeg.fromJson(Map<String, dynamic> j) => RouteLeg(
    floorId: j['floorId'] as String,
    points: [
      for (final p in j['points'] as List)
        PlanPoint.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
    arriveBy: switch (j['arriveBy']) {
      'lift' => ArriveBy.lift,
      'stairs' => ArriveBy.stairs,
      _ => null,
    },
  );

  final String floorId;
  final List<PlanPoint> points;

  /// Null on the first leg.
  final ArriveBy? arriveBy;
}

/// A walking route on the published map (`Route` schema).
class MapRoute {
  const MapRoute({
    required this.publishedVersion,
    required this.legs,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceEstimated,
  });

  factory MapRoute.fromJson(Map<String, dynamic> j) {
    final legs = [
      for (final l in j['legs'] as List)
        RouteLeg.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
    if (legs.isEmpty || legs.any((l) => l.points.isEmpty)) {
      throw const FormatException('route without points');
    }
    return MapRoute(
      publishedVersion: (j['publishedVersion'] as num).toInt(),
      legs: legs,
      distanceMeters: (j['distanceMeters'] as num).toDouble(),
      durationSeconds: (j['durationSeconds'] as num).toDouble(),
      distanceEstimated: j['distanceEstimated'] as bool? ?? false,
    );
  }

  final int publishedVersion;
  final List<RouteLeg> legs;
  final double distanceMeters;
  final double durationSeconds;
  final bool distanceEstimated;

  PlanPoint get start => legs.first.points.first;
  PlanPoint get end => legs.last.points.last;

  /// Whole minutes, at least 1.
  int get minutes {
    final m = (durationSeconds / 60).ceil();
    return m < 1 ? 1 : m;
  }
}

/// What the viewer asks for. [version] is the published map version, so a
/// new publish computes the route again.
class RouteQuery {
  const RouteQuery({
    required this.eventId,
    required this.from,
    required this.to,
    required this.version,
    this.accessible = false,
  });

  final String eventId;
  final RouteEndpoint from;
  final RouteEndpoint to;
  final int version;
  final bool accessible;

  RouteQuery copyWith({bool? accessible, int? version}) => RouteQuery(
    eventId: eventId,
    from: from,
    to: to,
    version: version ?? this.version,
    accessible: accessible ?? this.accessible,
  );

  @override
  bool operator ==(Object other) =>
      other is RouteQuery &&
      other.eventId == eventId &&
      other.from == from &&
      other.to == to &&
      other.version == version &&
      other.accessible == accessible;

  @override
  int get hashCode => Object.hash(eventId, from, to, version, accessible);
}
