import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/maps_localizations.dart';
import '../location/georef.dart';
import '../model/map_models.dart';
import '../viewer/labels.dart';
import '../viewer/plan_projection.dart';
import '../viewer/providers.dart';
import 'editor_providers.dart';
import 'maps_api.dart';

/// Above this, a control point is probably misplaced.
const badPointMeters = 5.0;

/// Ties a floor plan to GPS: three spots tapped on the plan, each with its
/// "lat, lng" from Google Maps. Saved with `putFloorGeoref`.
class GeorefScreen extends ConsumerStatefulWidget {
  const GeorefScreen({super.key, required this.eventId, required this.floor});

  final String eventId;
  final Floor floor;

  @override
  ConsumerState<GeorefScreen> createState() => _GeorefScreenState();
}

class _GeorefScreenState extends ConsumerState<GeorefScreen> {
  final _px = List<PlanPoint?>.filled(3, null);
  final _coords = List.generate(3, (_) => TextEditingController());
  int _active = 0;
  bool _saving = false;

  Floor get _floor => widget.floor;
  PlanProjection get _proj => PlanProjection(_floor.width, _floor.height);

  @override
  void initState() {
    super.initState();
    final cps = _floor.georef?.controlPoints;
    if (cps != null && cps.length == 3) {
      for (var i = 0; i < 3; i++) {
        _px[i] = cps[i].px;
        _coords[i].text =
            '${cps[i].latLng.lat.toStringAsFixed(7)}, '
            '${cps[i].latLng.lng.toStringAsFixed(7)}';
      }
    }
    for (final c in _coords) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _coords) {
      c.dispose();
    }
    super.dispose();
  }

  /// All three points, or null while something is missing or invalid.
  List<ControlPoint>? get _controlPoints {
    final cps = <ControlPoint>[];
    for (var i = 0; i < 3; i++) {
      final px = _px[i];
      final ll = parseLatLng(_coords[i].text);
      if (px == null || ll == null) return null;
      cps.add(ControlPoint(px: px, latLng: ll));
    }
    return cps;
  }

  void _onTap(PlanPoint p) {
    if (p.x < 0 || p.y < 0 || p.x > _floor.width || p.y > _floor.height) {
      return;
    }
    setState(() {
      _px[_active] = p;
      // Go on to the next point that still needs a spot.
      final next = _px.indexWhere((x) => x == null);
      if (next != -1) _active = next;
    });
  }

  Future<void> _save(List<ControlPoint> cps) async {
    final l10n = MapsLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(editorProvider(widget.eventId).notifier)
          .putGeoref(_floor.id, cps);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.georefSaved)));
      Navigator.pop(context);
    } on MapsApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [l10n.saveFailed(e.message), ...e.fieldErrors].join('\n'),
          ),
        ),
      );
    }
  }

  Future<void> _remove() async {
    final l10n = MapsLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(editorProvider(widget.eventId).notifier)
          .deleteGeoref(_floor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.georefRemoved)));
      Navigator.pop(context);
    } on MapsApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.saveFailed(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = MapPalette.of(context);
    final image = ref.watch(floorImageUrlProvider(_floor.imagePath)).value;
    final cps = _controlPoints;

    // Live check with the same transform the attendee app uses.
    String? status;
    var bad = false;
    var degenerate = false;
    if (cps != null) {
      try {
        final q = Georef.fit(cps).quality(_floor.width, _floor.height);
        bad = q.estimatedErrorMeters > badPointMeters;
        status = [
          l10n.georefScale(
            (q.metersPerPixel * 100).toStringAsFixed(1),
            q.estimatedErrorMeters.toStringAsFixed(1),
          ),
          if (bad) l10n.georefBadPoint,
        ].join('\n');
      } on DegenerateGeoref {
        bad = degenerate = true;
        status = l10n.georefDegenerate;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.georefTitle(_floor.name)),
        actions: [
          if (_floor.georef != null)
            TextButton(
              onPressed: _saving ? null : _remove,
              child: Text(l10n.georefRemove),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _saving || cps == null || degenerate
                  ? null
                  : () => _save(cps),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(l10n.georefIntro, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                crs: const CrsSimple(),
                initialCameraFit: _proj.fit(_proj.bounds),
                minZoom: _proj.minZoom,
                maxZoom: _proj.maxZoom,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, latLng) => _onTap(_proj.toPlan(latLng)),
              ),
              children: [
                if (image != null)
                  OverlayImageLayer(
                    overlayImages: [
                      OverlayImage(
                        bounds: _proj.bounds,
                        imageProvider: NetworkImage(image),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < 3; i++)
                      if (_px[i] != null)
                        Marker(
                          key: ValueKey('cp-$i'),
                          point: _proj.toLatLng(_px[i]!),
                          width: 34,
                          height: 34,
                          child: CircleAvatar(
                            backgroundColor: i == _active
                                ? palette.route
                                : theme.colorScheme.secondary,
                            foregroundColor: palette.onRoute,
                            child: Text('${i + 1}'),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 3; i++) _pointRow(l10n, i),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        status,
                        key: const ValueKey('georef-status'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: bad ? theme.colorScheme.error : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointRow(MapsLocalizations l10n, int i) {
    final px = _px[i];
    final text = _coords[i].text;
    final invalid = text.trim().isNotEmpty && parseLatLng(text) == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.georefPoint(i + 1)),
            selected: i == _active,
            onSelected: (_) => setState(() => _active = i),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              px == null
                  ? l10n.georefTapPlan
                  : '${px.x.round()}, ${px.y.round()} px',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey('cp-coords-$i'),
              controller: _coords[i],
              onTap: () => setState(() => _active = i),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.georefCoordsHint,
                errorText: invalid ? l10n.georefCoordsInvalid : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
