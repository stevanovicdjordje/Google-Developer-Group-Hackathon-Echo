import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../model/map_models.dart';

/// Maps floor-plan pixels to the [LatLng] space of flutter_map's [CrsSimple].
///
/// CrsSimple treats latitude as "up", plan pixels grow downwards, and
/// flutter_map clamps latitude to ±90 / longitude to ±180. Pixels are therefore
/// scaled so the plan fits into longitude 0..170 and latitude -85..0.
class PlanProjection {
  PlanProjection(this.width, this.height)
    : unit = math.max(math.max(width / 170, height / 85), 1e-9);

  final int width;
  final int height;

  /// Plan pixels per CrsSimple unit.
  final double unit;

  LatLng toLatLng(PlanPoint p) => LatLng(-p.y / unit, p.x / unit);

  PlanPoint toPlan(LatLng l) =>
      PlanPoint(l.longitude * unit, -l.latitude * unit);

  LatLngBounds get bounds =>
      LatLngBounds(LatLng(-height / unit, 0), LatLng(0, width / unit));

  /// Screen pixels per plan pixel at [zoom] (flutter_map: 256·2^zoom screen px per unit).
  double scaleAt(double zoom) => 256 * math.pow(2, zoom) / unit;

  /// Zoom at which one plan pixel is [screenPx] screen pixels.
  double zoomFor(double screenPx) => math.log(screenPx * unit / 256) / math.ln2;

  /// Zoom limits of the viewer: from 0.02 to 8 screen px per plan px.
  double get minZoom => zoomFor(0.02);
  double get maxZoom => zoomFor(8);

  /// Camera fit for [bounds]. Zoom levels are negative for CrsSimple plans,
  /// so the fit's minZoom (default 0) must be set explicitly.
  CameraFit fit(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(24),
    double maxScale = 8,
  }) => CameraFit.bounds(
    bounds: bounds,
    padding: padding,
    minZoom: minZoom,
    maxZoom: zoomFor(maxScale),
  );

  /// Whole-plan fit with the plan's top edge right under [padding].top when
  /// the plan is wider than the screen (no empty band above it).
  CameraFit fitPlan({required EdgeInsets padding}) =>
      _TopAlignedFit(fit(bounds, padding: padding), bounds, padding);
}

class _TopAlignedFit extends CameraFit {
  const _TopAlignedFit(this.inner, this.bounds, this.padding);

  final CameraFit inner;
  final LatLngBounds bounds;
  final EdgeInsets padding;

  @override
  MapCamera fit(MapCamera camera) {
    final c = inner.fit(camera);
    final top = c.projectAtZoom(bounds.northWest);
    final bottom = c.projectAtZoom(bounds.southEast);
    final size = c.nonRotatedSize;
    if (bottom.dy - top.dy >= size.height - padding.vertical) return c;
    final center = c.projectAtZoom(c.center);
    final y = top.dy - padding.top + size.height / 2;
    return c.withPosition(center: c.unprojectAtZoom(Offset(center.dx, y)));
  }
}
