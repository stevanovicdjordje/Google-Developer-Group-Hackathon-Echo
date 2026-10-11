import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/map_models.dart';
import 'hit_test.dart';
import 'labels.dart';
import 'plan_projection.dart';
import 'providers.dart';

/// Room for the search bar on top and the details sheet at the bottom.
const _focusPadding = EdgeInsets.fromLTRB(48, 120, 48, 260);

/// Whole-plan fit: edge to edge across the width, clear of the search bar and
/// chips on top and the buttons at the bottom.
const planFitPadding = EdgeInsets.fromLTRB(8, 132, 8, 96);

/// Interactive floor plan of one floor: image, rooms, stands, POIs, labels.
/// Zoom and pan; rotation is disabled.
class VenueMapView extends ConsumerWidget {
  const VenueMapView({
    super.key,
    required this.floor,
    required this.features,
    required this.controller,
    required this.onFeatureTap,
    this.selectedId,
    this.initialFocus,
    this.onPlanTap,
    this.underLabels = const [],
    this.overLabels = const [],
  });

  final Floor floor;
  final List<Feature> features;
  final MapController controller;
  final ValueChanged<Feature?> onFeatureTap;
  final String? selectedId;

  /// Camera bounds to start with instead of the whole plan.
  final LatLngBounds? initialFocus;

  /// When set, a tap reports the plan point instead of a feature
  /// (picking where the attendee is).
  final ValueChanged<PlanPoint>? onPlanTap;

  /// Extra layers between the shapes and the labels (the route line).
  final List<Widget> underLabels;

  /// Extra layers above everything (route ends, "you are here").
  final List<Widget> overLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = PlanProjection(floor.width, floor.height);
    final palette = MapPalette.of(context);
    final image = ref.watch(floorImageUrlProvider(floor.imagePath)).value;

    return FlutterMap(
      // A new key per floor resets the camera to the new plan.
      key: ValueKey(floor.id),
      mapController: controller,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCameraFit: initialFocus != null
            ? proj.fit(initialFocus!, padding: _focusPadding, maxScale: 2)
            : proj.fit(proj.bounds, padding: planFitPadding),
        minZoom: proj.minZoom,
        maxZoom: proj.maxZoom,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (tap, latLng) {
          if (onPlanTap != null) {
            onPlanTap!(proj.toPlan(latLng));
            return;
          }
          final camera = controller.camera;
          // 22 screen pixels of tolerance, converted to plan pixels.
          final tolerance = 22 / proj.scaleAt(camera.zoom);
          onFeatureTap(
            featureAt(features, proj.toPlan(latLng), tolerance: tolerance),
          );
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
                _polygon(f, proj, palette),
          ],
        ),
        CircleLayer(
          circles: [
            for (final f in features)
              if (f.type == FeatureType.stand &&
                  f.geometry.kind == GeometryKind.point)
                CircleMarker(
                  point: proj.toLatLng(f.geometry.coords.first),
                  radius: 9,
                  color: palette.stand,
                  borderColor: f.id == selectedId
                      ? palette.selected
                      : (palette.tierColor(f.sponsorTier) ?? Colors.white),
                  borderStrokeWidth: f.id == selectedId ? 4 : 2,
                ),
          ],
        ),
        ...underLabels,
        _LabelsAndIcons(features: features, proj: proj, selectedId: selectedId),
        ...overLabels,
      ],
    );
  }

  Polygon _polygon(Feature f, PlanProjection proj, MapPalette palette) {
    final selected = f.id == selectedId;
    final base = f.type == FeatureType.room ? palette.room : palette.stand;
    final tier = palette.tierColor(f.sponsorTier);
    return Polygon(
      points: [for (final p in outline(f.geometry)) proj.toLatLng(p)],
      color: base.withValues(
        alpha: selected
            ? 0.55
            : (f.sponsorTier == SponsorTier.gold ? 0.45 : 0.28),
      ),
      borderColor: selected ? palette.selected : (tier ?? base),
      borderStrokeWidth: selected
          ? 4
          : (f.sponsorTier == SponsorTier.gold ? 3.5 : 1.5),
    );
  }
}

/// POI icons always; room names always; stand names once zoomed in enough.
class _LabelsAndIcons extends StatelessWidget {
  const _LabelsAndIcons({
    required this.features,
    required this.proj,
    this.selectedId,
  });

  final List<Feature> features;
  final PlanProjection proj;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final scale = proj.scaleAt(camera.zoom);
    final palette = MapPalette.of(context);
    final showStandLabels = scale >= 0.9;
    final markers = <Marker>[];

    for (final f in features) {
      final at = proj.toLatLng(f.geometry.center);
      switch (f.type) {
        case FeatureType.poi:
          markers.add(
            Marker(
              point: at,
              width: 34,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: f.id == selectedId
                        ? palette.selected
                        : palette.scheme.outline,
                    width: 2,
                  ),
                ),
                child: Icon(
                  featureIcon(f),
                  size: 20,
                  color: palette.scheme.onSurface,
                ),
              ),
            ),
          );
        case FeatureType.room:
        case FeatureType.stand:
          if (f.type == FeatureType.stand &&
              !showStandLabels &&
              f.id != selectedId) {
            break;
          }
          final width = f.type == FeatureType.room ? 160.0 : 110.0;
          markers.add(
            Marker(
              point: at,
              width: width,
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
                        fontSize: f.type == FeatureType.room ? 14 : 11,
                        fontWeight:
                            f.type == FeatureType.room ||
                                f.sponsorTier == SponsorTier.gold
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        case FeatureType.marker:
          break; // "you are here" markers are used for positioning, not shown
      }
    }
    return MarkerLayer(markers: markers);
  }
}
