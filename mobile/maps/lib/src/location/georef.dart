import 'dart:math' as math;

import '../model/map_models.dart';

/// WGS84 mean radius in meters (local equirectangular projection).
const _earthRadius = 6371008.8;

/// The three control points are collinear or coincide.
class DegenerateGeoref implements Exception {
  const DegenerateGeoref();

  @override
  String toString() => 'control points are collinear or coincide';
}

/// How far a fitted transform is from a pure rotation + uniform scale
/// (`GeorefQuality` schema). Large values usually mean a misplaced point.
class GeorefQuality {
  const GeorefQuality({
    required this.metersPerPixel,
    required this.scaleMismatchPercent,
    required this.skewDegrees,
    required this.estimatedErrorMeters,
  });

  factory GeorefQuality.fromJson(Map<String, dynamic> j) => GeorefQuality(
    metersPerPixel: (j['metersPerPixel'] as num).toDouble(),
    scaleMismatchPercent: (j['scaleMismatchPercent'] as num).toDouble(),
    skewDegrees: (j['skewDegrees'] as num).toDouble(),
    estimatedErrorMeters: (j['estimatedErrorMeters'] as num).toDouble(),
  );

  final double metersPerPixel;
  final double scaleMismatchPercent;
  final double skewDegrees;
  final double estimatedErrorMeters;
}

/// Plan pixels ↔ lat/lng, fitted to exactly three control points. Mirrors
/// `backend/maps/internal/geo/affine.go`; both are checked against
/// `contracts/maps/testdata/georef.json`.
///
/// Lat/lng is projected to local east/north meters around the first control
/// point, then mapped affinely to pixels.
class Georef {
  Georef._(this._lat0, this._lng0, this._cosLat);

  /// Throws [DegenerateGeoref] for (nearly) collinear points.
  factory Georef.fit(List<ControlPoint> cps) {
    if (cps.length != 3) {
      throw ArgumentError.value(cps.length, 'cps', 'need exactly 3');
    }
    final o = cps[0].latLng;
    final g = Georef._(o.lat, o.lng, math.cos(o.lat * math.pi / 180));
    final px = [for (final c in cps) c.px];
    final en = [for (final c in cps) g._toMeters(c.latLng)];

    final x1 = px[1].x - px[0].x, y1 = px[1].y - px[0].y;
    final x2 = px[2].x - px[0].x, y2 = px[2].y - px[0].y;
    final det = x1 * y2 - x2 * y1;
    if (det.abs() < 100) throw const DegenerateGeoref();
    final e1 = en[1].x - en[0].x, n1 = en[1].y - en[0].y;
    final e2 = en[2].x - en[0].x, n2 = en[2].y - en[0].y;
    if ((e1 * n2 - e2 * n1).abs() < 1) throw const DegenerateGeoref();

    g._a = (e1 * y2 - e2 * y1) / det;
    g._b = (e2 * x1 - e1 * x2) / det;
    g._c = (n1 * y2 - n2 * y1) / det;
    g._d = (n2 * x1 - n1 * x2) / det;
    g._tx = en[0].x - g._a * px[0].x - g._b * px[0].y;
    g._ty = en[0].y - g._c * px[0].x - g._d * px[0].y;

    final ldet = g._a * g._d - g._b * g._c;
    g._ia = g._d / ldet;
    g._ib = -g._b / ldet;
    g._ic = -g._c / ldet;
    g._id = g._a / ldet;
    g._itx = -(g._ia * g._tx + g._ib * g._ty);
    g._ity = -(g._ic * g._tx + g._id * g._ty);
    return g;
  }

  /// Null when the floor isn't georeferenced or its points are degenerate.
  static Georef? of(Floor floor) {
    final cps = floor.georef?.controlPoints;
    if (cps == null || cps.length != 3) return null;
    try {
      return Georef.fit(cps);
    } on DegenerateGeoref {
      return null;
    }
  }

  final double _lat0, _lng0, _cosLat;
  // pixel -> meters: [e n] = A·[x y] + t
  double _a = 0, _b = 0, _c = 0, _d = 0, _tx = 0, _ty = 0;
  // meters -> pixel
  double _ia = 0, _ib = 0, _ic = 0, _id = 0, _itx = 0, _ity = 0;

  PlanPoint _toMeters(LatLngDeg ll) => PlanPoint(
    (ll.lng - _lng0) * math.pi / 180 * _earthRadius * _cosLat,
    (ll.lat - _lat0) * math.pi / 180 * _earthRadius,
  );

  LatLngDeg _fromMeters(double e, double n) => LatLngDeg(
    _lat0 + n / _earthRadius * 180 / math.pi,
    _lng0 + e / (_earthRadius * _cosLat) * 180 / math.pi,
  );

  PlanPoint toPixel(LatLngDeg ll) {
    final m = _toMeters(ll);
    return PlanPoint(
      _ia * m.x + _ib * m.y + _itx,
      _ic * m.x + _id * m.y + _ity,
    );
  }

  LatLngDeg toLatLng(PlanPoint p) =>
      _fromMeters(_a * p.x + _b * p.y + _tx, _c * p.x + _d * p.y + _ty);

  /// Mean scale (square root of the area scale factor).
  double get metersPerPixel => math.sqrt((_a * _d - _b * _c).abs());

  /// Converts meters (e.g. GPS accuracy) to plan pixels.
  double metersToPixels(double meters) => meters / metersPerPixel;

  GeorefQuality quality(int width, int height) {
    final sx = math.sqrt(_a * _a + _c * _c);
    final sy = math.sqrt(_b * _b + _d * _d);
    final cosAng = (_a * _b + _c * _d) / (sx * sy);
    final skew = (90 - math.acos(cosAng.clamp(-1.0, 1.0)) * 180 / math.pi)
        .abs();
    final mean = (sx + sy) / 2;
    final diag = math.sqrt(width * width + height * height) * mean;
    return GeorefQuality(
      metersPerPixel: metersPerPixel,
      scaleMismatchPercent: (sx - sy).abs() / mean * 100,
      skewDegrees: skew,
      estimatedErrorMeters:
          diag * ((sx - sy).abs() / mean + math.sin(skew * math.pi / 180)) / 2,
    );
  }
}
