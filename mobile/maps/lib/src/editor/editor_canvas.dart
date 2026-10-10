import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/map_models.dart';
import '../viewer/hit_test.dart';
import '../viewer/labels.dart';
import '../viewer/plan_projection.dart';
import '../viewer/providers.dart';

/// A tap on the plan, with the hit tolerance in plan pixels at the current zoom.
typedef PlanTap = void Function(PlanPoint p, double tolerance);

/// The editor's floor plan: image, every feature (QR markers too), the
/// walkway graph and the shape being drawn. Taps are reported in plan pixels.
class EditorCanvas extends ConsumerWidget {
  const EditorCanvas({
    super.key,
    required this.floor,
    required this.features,
    required this.graph,
    required this.controller,
    required this.onTap,
    this.selectedFeatureId,
    this.selectedNodeId,
    this.activeNodeId,
    this.drawing = const [],
    this.drawingClosed = false,
  });

  final Floor floor;
  final List<Feature> features;
  final FloorGraph graph;
  final MapController controller;
  final PlanTap onTap;
  final String? selectedFeatureId;
  final String? selectedNodeId;

  /// Walkway tool: the node the next tap connects from.
  final String? activeNodeId;

  /// Points of the shape being drawn.
  final List<PlanPoint> drawing;

  /// Whether [drawing] is an area outline (drawn closed).
  final bool drawingClosed;

  /// Outline of the shape being drawn; 2 points of an area are a rect.
  List<PlanPoint> get _preview => drawingClosed && drawing.length == 2
      ? rectCorners(Geometry(GeometryKind.rect, drawing))
      : drawing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = PlanProjection(floor.width, floor.height);
    final palette = MapPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final image = ref.watch(floorImageUrlProvider(floor.imagePath)).value;
    final nodes = {for (final n in graph.nodes) n.id: n};

    return FlutterMap(
      key: ValueKey(floor.id),
      mapController: controller,
      options: MapOptions(
        crs: const CrsSimple(),
        // Room for the hint card on top.
        initialCameraFit: proj.fit(
          proj.bounds,
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
        ),
        minZoom: proj.minZoom,
        maxZoom: proj.maxZoom,
        backgroundColor: scheme.surfaceContainerHighest,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, latLng) {
          // 18 screen pixels of tolerance, converted to plan pixels.
          final tolerance = 18 / proj.scaleAt(controller.camera.zoom);
          onTap(proj.toPlan(latLng), tolerance);
        },
      ),
      children: [
        if (image != null)
          OverlayImageLayer(
            overlayImages: [
              OverlayImage(
                bounds: proj.bounds,
                imageProvider: NetworkImage(image),
              ),
            ],
          ),
        PolygonLayer(
          polygonLabels: false,
          polygons: [
            for (final f in features)
              if (f.geometry.kind != GeometryKind.point)
                Polygon(
                  points: [
                    for (final p in outline(f.geometry)) proj.toLatLng(p),
                  ],
                  color:
                      (f.type == FeatureType.room
                              ? palette.room
                              : palette.stand)
                          .withValues(
                            alpha: f.id == selectedFeatureId ? 0.55 : 0.3,
                          ),
                  borderColor: f.id == selectedFeatureId
                      ? palette.selected
                      : (palette.tierColor(f.sponsorTier) ??
                            (f.type == FeatureType.room
                                ? palette.room
                                : palette.stand)),
                  borderStrokeWidth: f.id == selectedFeatureId ? 4 : 1.5,
                ),
          ],
        ),
        PolylineLayer(
          polylines: [
            for (final e in graph.edges)
              if (nodes[e.from] != null && nodes[e.to] != null)
                Polyline(
                  points: [
                    proj.toLatLng(nodes[e.from]!.point),
                    proj.toLatLng(nodes[e.to]!.point),
                  ],
                  color: scheme.tertiary,
                  strokeWidth: 4,
                ),
            if (drawing.length >= 2)
              Polyline(
                points: [
                  for (final p in _preview) proj.toLatLng(p),
                  if (drawingClosed) proj.toLatLng(_preview.first),
                ],
                color: scheme.primary,
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [10, 6]),
              ),
          ],
        ),
        CircleLayer(
          circles: [
            for (final n in graph.nodes)
              CircleMarker(
                point: proj.toLatLng(n.point),
                radius: n.id == activeNodeId || n.id == selectedNodeId ? 8 : 5,
                color: n.id == selectedNodeId
                    ? palette.selected
                    : (n.id == activeNodeId ? scheme.primary : scheme.tertiary),
                borderColor: scheme.surface,
                borderStrokeWidth: 2,
              ),
            for (final f in features)
              if (f.type == FeatureType.stand &&
                  f.geometry.kind == GeometryKind.point)
                CircleMarker(
                  point: proj.toLatLng(f.geometry.coords.first),
                  radius: 9,
                  color: palette.stand,
                  borderColor: f.id == selectedFeatureId
                      ? palette.selected
                      : Colors.white,
                  borderStrokeWidth: f.id == selectedFeatureId ? 4 : 2,
                ),
            for (final p in drawing)
              CircleMarker(
                point: proj.toLatLng(p),
                radius: 6,
                color: scheme.primary,
                borderColor: scheme.surface,
                borderStrokeWidth: 2,
              ),
          ],
        ),
        Builder(
          builder: (context) => MarkerLayer(
            markers: [
              for (final f in features)
                if (f.type == FeatureType.poi || f.type == FeatureType.marker)
                  Marker(
                    point: proj.toLatLng(f.geometry.center),
                    width: 34,
                    height: 34,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: f.type == FeatureType.marker
                              ? scheme.secondaryContainer
                              : scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: f.id == selectedFeatureId
                                ? palette.selected
                                : scheme.outline,
                            width: f.id == selectedFeatureId ? 3 : 2,
                          ),
                        ),
                        child: Icon(featureIcon(f), size: 20),
                      ),
                    ),
                  )
                else if (f.type == FeatureType.room ||
                    f.id == selectedFeatureId ||
                    // Stand names once zoomed in enough, like the viewer.
                    proj.scaleAt(MapCamera.of(context).zoom) >= 0.9)
                  Marker(
                    point: proj.toLatLng(f.geometry.center),
                    width: f.type == FeatureType.room ? 160 : 110,
                    height: 40,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.labelBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            f.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.labelText,
                              fontSize: f.type == FeatureType.room ? 13 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
