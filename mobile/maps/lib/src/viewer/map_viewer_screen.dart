import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/maps_localizations.dart';
import '../data/published_map_repository.dart';
import '../editor/maps_api.dart';
import '../location/location_source.dart';
import '../location/tracking.dart';
import '../model/map_models.dart';
import '../model/route_models.dart';
import '../stats/stats_reporter.dart';
import 'feature_sheet.dart';
import 'hit_test.dart';
import 'labels.dart';
import 'plan_projection.dart';
import 'providers.dart';
import 'route_layers.dart';
import 'route_panels.dart';
import 'search.dart';
import 'venue_map_view.dart';

/// Attendee view of a published event's venue map (`/e/{eventId}`).
class MapViewerScreen extends ConsumerWidget {
  const MapViewerScreen({
    super.key,
    required this.eventId,
    this.initialFeatureId,
    this.markerId,
    this.highlightFeatureId,
    this.highlightLabel,
    this.featureSheetBuilder,
    this.previewRouteOnSelect = true,
  });

  final String eventId;

  /// Lets the app supply the details sheet of a selected place (null from the
  /// builder = the map's default sheet).
  final MapFeatureSheetBuilder? featureSheetBuilder;

  /// When a place is selected and "You are here" is known, draw the route to
  /// it behind the details sheet.
  final bool previewRouteOnSelect;

  /// Feature to select on open (`/e/{eventId}/stand/{standId}`).
  final String? initialFeatureId;

  /// "You are here" QR marker the attendee scanned (`?at=`).
  final String? markerId;

  /// A place to point out with its own label (e.g. an agreed meeting spot):
  /// the map opens on it and shows [highlightLabel] there.
  final String? highlightFeatureId;
  final String? highlightLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = MapsLocalizations.of(context);
    final event = ref.watch(publishedEventProvider(eventId));

    return event.when(
      skipLoadingOnReload: true,
      data: (e) => _Viewer(
        event: e,
        markerId: markerId,
        initialFeatureId: initialFeatureId ?? highlightFeatureId ?? markerId,
        openSheet: initialFeatureId != null,
        highlightFeatureId: highlightFeatureId,
        highlightLabel: highlightLabel,
        featureSheetBuilder: featureSheetBuilder,
        previewRouteOnSelect: previewRouteOnSelect,
      ),
      loading: () => _Message(
        title: l10n.mapLoading,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _Message(
        title: e is EventNotFound ? l10n.mapNotFound : l10n.mapUnavailable,
        hint: e is EventNotFound ? l10n.mapNotFoundHint : null,
        icon: e is EventNotFound ? Icons.map_outlined : Icons.cloud_off,
        child: e is EventNotFound
            ? null
            : FilledButton.icon(
                onPressed: () {
                  ref.invalidate(mapsSignedInProvider);
                  ref.invalidate(publishedEventProvider(eventId));
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.hint, this.icon, this.child});

  final String title;
  final String? hint;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 34,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: icon == null
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.headlineSmall,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ?child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// At most one re-route per this long while following the GPS.
const _rerouteEvery = Duration(seconds: 8);

/// Room for the search bar / banner on top and the route card at the bottom.
const _routePadding = EdgeInsets.fromLTRB(48, 130, 48, 240);

/// Leaves room for the details sheet over the lower half.
const _previewPadding = EdgeInsets.fromLTRB(48, 100, 48, 380);

class _Viewer extends ConsumerStatefulWidget {
  const _Viewer({
    required this.event,
    this.markerId,
    this.initialFeatureId,
    this.openSheet = false,
    this.highlightFeatureId,
    this.highlightLabel,
    this.featureSheetBuilder,
    this.previewRouteOnSelect = true,
  });

  final PublishedEvent event;
  final String? markerId;
  final String? initialFeatureId;
  final bool openSheet;
  final String? highlightFeatureId;
  final String? highlightLabel;
  final MapFeatureSheetBuilder? featureSheetBuilder;
  final bool previewRouteOnSelect;

  @override
  ConsumerState<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends ConsumerState<_Viewer> {
  final _controller = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String? _floorId;
  String? _selectedId;
  Feature? _pendingFocus;
  SearchFilter _filter = SearchFilter.all;
  String? _category;

  /// A quick chip (Sponsors, Food…) opened the result list without a query.
  bool _browsing = false;
  Timer? _searchDebounce;

  /// The route being shown, and where it goes.
  RouteQuery? _routeQuery;
  Feature? _routeTarget;

  /// Route drawn behind an open details sheet (from "You are here").
  RouteQuery? _previewQuery;

  /// Set while the attendee taps where they are; the route then goes here.
  Feature? _pickingFor;

  /// Where the attendee said they are by tapping the map.
  ({String floorId, PlanPoint at})? _pickedHere;

  /// Live GPS (only after the attendee taps "Moja lokacija"). Kept in
  /// memory only; never stored or logged.
  StreamSubscription<GpsFix>? _gpsSub;
  GpsFix? _gps;
  bool _gpsOn = false;
  bool _centerOnNextFix = false;

  /// The shown route starts at the GPS position and follows it.
  bool _routeFromGps = false;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  /// Fit the camera to the next route answer (not after a re-route).
  bool _fitNextRoute = true;
  bool _fitNextPreview = true;

  VenueMap get _map => widget.event.map;

  /// The scanned QR marker (`?at=`), if it is on the map.
  Feature? get _marker => widget.markerId == null
      ? null
      : _map.features.where((f) => f.id == widget.markerId).firstOrNull;

  bool get _anyGeoref => _map.floors.any((f) => f.georef != null);

  /// The GPS fix on the floor being looked at (GPS has no floor).
  PlanFix? get _planFix {
    final f = _floor;
    final gps = _gps;
    if (!_gpsOn || gps == null || f == null) return null;
    return placeFix(gps, f);
  }

  /// "You are here": a good GPS fix, else a picked point, else the scanned
  /// QR marker.
  ({String floorId, PlanPoint at})? get _here {
    final fix = _planFix;
    if (fix != null && fix.usable) return (floorId: fix.floorId, at: fix.at);
    if (_pickedHere != null) return _pickedHere;
    final m = _marker;
    return m == null ? null : (floorId: m.floorId, at: m.geometry.center);
  }

  Floor? get _floor {
    final floors = _map.floors;
    if (floors.isEmpty) return null;
    return floors.where((f) => f.id == _floorId).firstOrNull ?? floors.first;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocus.addListener(() => setState(() {}));
    if (_marker case final m?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stats.qrScan(m.id);
      });
    }
    final initial = _map.features
        .where((f) => f.id == widget.initialFeatureId)
        .firstOrNull;
    if (initial != null) {
      _floorId = initial.floorId;
      _pendingFocus = initial;
      if (widget.openSheet) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _select(initial));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // An offstage tab (TickerMode off) must not keep reading the position.
    // Read it every time so this runs again when the tab is hidden.
    final onScreen = TickerMode.valuesOf(context).enabled;
    if (_gpsOn && !onScreen) _stopGps();
  }

  @override
  void didUpdateWidget(_Viewer old) {
    super.didUpdateWidget(old);
    // A new publish may have removed the selected feature.
    if (_selectedId != null && !_map.features.any((f) => f.id == _selectedId)) {
      _selectedId = null;
    }
    final q = _routeQuery;
    if (q != null && q.version != _map.version) {
      final target = _map.features
          .where((f) => f.id == _routeTarget?.id)
          .firstOrNull;
      final from = q.from.featureId;
      final fromGone = from != null && !_map.features.any((f) => f.id == from);
      if (target == null || fromGone) {
        _routeQuery = null;
        _routeTarget = null;
      } else {
        // Same places on the new map: the route is computed again.
        _routeTarget = target;
        _routeQuery = q.copyWith(version: _map.version);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _gpsSub?.cancel();
    _controller.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  LatLngBounds _boundsOf(Feature f, PlanProjection proj) {
    final pts = outline(f.geometry);
    if (pts.isNotEmpty) {
      return LatLngBounds.fromPoints([for (final p in pts) proj.toLatLng(p)]);
    }
    final c = f.geometry.center;
    const r = 60.0; // plan pixels around a point
    return LatLngBounds(
      proj.toLatLng(PlanPoint(c.x - r, c.y + r)),
      proj.toLatLng(PlanPoint(c.x + r, c.y - r)),
    );
  }

  /// Switches to the feature's floor if needed and zooms to it.
  void _focus(Feature f) {
    if (f.floorId != _floor?.id) {
      setState(() {
        _floorId = f.floorId;
        _pendingFocus = f; // applied as the new map's initial camera
      });
      // The shared controller may keep the old floor's camera.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _floor?.id == f.floorId) _focus(f);
      });
      return;
    }
    final floor = _floor!;
    final proj = PlanProjection(floor.width, floor.height);
    _controller.fitCamera(
      proj.fit(
        _boundsOf(f, proj),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 260),
        maxScale: 2,
      ),
    );
  }

  /// Where a route from "You are here" starts: a good GPS fix, a tapped
  /// spot, or the scanned QR marker; null if none is known.
  ({RouteEndpoint from, bool gps})? get _hereStart {
    final fix = _planFix;
    if (fix != null && fix.usable) {
      return (from: RouteEndpoint.point(fix.floorId, fix.at), gps: true);
    }
    if (_pickedHere case final h?) {
      return (from: RouteEndpoint.point(h.floorId, h.at), gps: false);
    }
    if (_marker case final m?) {
      return (from: RouteEndpoint.feature(m.id), gps: false);
    }
    return null;
  }

  Future<void> _select(Feature? f) async {
    final start = _hereStart;
    final preview =
        f != null &&
            widget.previewRouteOnSelect &&
            f.type != FeatureType.marker &&
            _routeQuery == null &&
            start != null &&
            start.from.featureId != f.id
        ? RouteQuery(
            eventId: widget.event.id,
            from: start.from,
            to: RouteEndpoint.feature(f.id),
            version: _map.version,
            accessible: false,
          )
        : null;
    setState(() {
      _selectedId = f?.id;
      _previewQuery = preview;
      _fitNextPreview = true;
    });
    if (f == null) return;
    if (f.type != FeatureType.marker) _stats.featureView(f.id);
    final floorName = _map.floors.length > 1
        ? _map.floors.where((x) => x.id == f.floorId).firstOrNull?.name
        : null;
    var startRoute = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final routeAsync = preview == null
              ? null
              : ref.watch(mapsRouteProvider(preview));
          final onRoute = f.type == FeatureType.marker
              ? null
              : () {
                  startRoute = true;
                  Navigator.pop(sheet);
                };
          final data = MapFeatureSheetData(
            feature: f,
            floorName: floorName,
            route: routeAsync?.value,
            routeLoading: routeAsync?.isLoading ?? false,
            startRoute: onRoute,
          );
          return widget.featureSheetBuilder?.call(context, data) ??
              FeatureDetails(
                feature: f,
                floorName: floorName,
                onRoute: onRoute,
                route: data.route,
              );
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      if (_selectedId == f.id) _selectedId = null;
      if (_previewQuery == preview) _previewQuery = null;
    });
    if (startRoute) _routeTo(f);
  }

  /// Starts a route to [to] from the QR marker or a picked point; otherwise
  /// asks where the attendee is.
  Future<void> _routeTo(Feature to) async {
    if (_hereStart case final start?) {
      _requestRoute(start.from, to, gps: start.gps);
      return;
    }
    final starts = [
      for (final f in _map.features)
        if (f.id != to.id &&
            (f.type == FeatureType.marker || f.poiKind == 'entrance'))
          f,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final choice = starts.isEmpty
        ? const StartChoice(null)
        : await showModalBottomSheet<StartChoice>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => StartPicker(
              starts: starts,
              floorNames: _map.floors.length > 1
                  ? {for (final f in _map.floors) f.id: f.name}
                  : const {},
            ),
          );
    if (!mounted || choice == null) return;
    final start = choice.feature;
    if (start == null) {
      setState(() {
        _pickingFor = to;
        _routeQuery = null;
        _routeTarget = null;
      });
    } else {
      _requestRoute(RouteEndpoint.feature(start.id), to);
    }
  }

  void _pickedStart(PlanPoint at) {
    final to = _pickingFor;
    final floor = _floor;
    if (to == null || floor == null) return;
    setState(() {
      _pickingFor = null;
      _pickedHere = (floorId: floor.id, at: at);
    });
    _requestRoute(RouteEndpoint.point(floor.id, at), to);
  }

  void _requestRoute(RouteEndpoint from, Feature to, {bool gps = false}) {
    if (from.featureId == to.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_l10n.routeAlreadyHere)));
      return;
    }
    _stats.route(to.id);
    _searchFocus.unfocus();
    _searchCtrl.clear(); // closing the route goes back to the plain map
    setState(() {
      _selectedId = null;
      _previewQuery = null;
      _routeTarget = to;
      _routeFromGps = gps;
      _fitNextRoute = true;
      _routeQuery = RouteQuery(
        eventId: widget.event.id,
        from: from,
        to: RouteEndpoint.feature(to.id),
        version: _map.version,
        accessible: _routeQuery?.accessible ?? false,
      );
    });
    // The preview behind the details sheet may already have the answer; a
    // listener only hears changes, so handle it here.
    final q = _routeQuery!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _routeQuery != q) return;
      final now = ref.read(mapsRouteProvider(q));
      if (!now.isLoading) _onRouteAnswer(now);
    });
  }

  void _closeRoute() => setState(() {
    _routeQuery = null;
    _routeTarget = null;
    _routeFromGps = false;
  });

  /// "Moja lokacija": turns GPS on, or centers on the dot, or (while still
  /// searching) turns it off again.
  void _onMyLocation() {
    final fix = _planFix;
    if (_gpsOn && fix != null && fix.inside) {
      _centerOn(fix);
      return;
    }
    if (_gpsOn) {
      _stopGps();
      return;
    }
    setState(() {
      _gpsOn = true;
      _gps = null;
      _centerOnNextFix = true;
    });
    _gpsSub = ref
        .read(locationSourceProvider)
        .watch()
        .listen(_onFix, onError: _onGpsError);
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
    setState(() {
      _gpsOn = false;
      _gps = null;
    });
  }

  void _onGpsError(Object e) {
    final problem = e is LocationUnavailable
        ? e.problem
        : LocationProblem.failed;
    if (problem == LocationProblem.failed) {
      // Indoors the signal comes and goes: keep listening, show "searching".
      if (mounted) setState(() => _gps = null);
      return;
    }
    _stopGps();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (problem) {
          LocationProblem.denied => _l10n.gpsDenied,
          LocationProblem.serviceOff => _l10n.gpsServiceOff,
          LocationProblem.failed => _l10n.gpsFailed,
        }),
      ),
    );
  }

  void _centerOn(PlanFix fix) {
    final floor = _floor;
    if (floor == null) return;
    final proj = PlanProjection(floor.width, floor.height);
    final r = fix.accuracyPixels + 80;
    // Clamped to the plan: a weak fix's circle can be larger than the venue.
    double cx(double v) => v.clamp(0, floor.width.toDouble());
    double cy(double v) => v.clamp(0, floor.height.toDouble());
    _controller.fitCamera(
      proj.fit(
        LatLngBounds(
          proj.toLatLng(PlanPoint(cx(fix.at.x - r), cy(fix.at.y + r))),
          proj.toLatLng(PlanPoint(cx(fix.at.x + r), cy(fix.at.y - r))),
        ),
        padding: _routePadding,
        maxScale: 2,
      ),
    );
  }

  void _onFix(GpsFix gps) {
    if (!mounted) return;
    setState(() => _gps = gps);
    final fix = _planFix;
    if (fix == null) return;
    if (_centerOnNextFix && fix.inside) {
      _centerOnNextFix = false;
      _centerOn(fix);
    }
    // Follow a route that started at the GPS position.
    final q = _routeQuery;
    final target = _routeTarget;
    final route = q == null ? null : ref.read(mapsRouteProvider(q)).value;
    if (!_routeFromGps || q == null || target == null || route == null) return;
    if (!fix.usable) return;
    switch (trackRoute(route, fix)) {
      case TrackStep.arrived:
        _closeRoute();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l10n.arrived(target.name))));
      case TrackStep.offRoute:
        final now = DateTime.now();
        if (now.difference(_lastReroute) < _rerouteEvery) return;
        _lastReroute = now;
        setState(() {
          _fitNextRoute = false;
          _routeQuery = q.copyWith(
            from: RouteEndpoint.point(fix.floorId, fix.at),
          );
        });
      case TrackStep.onRoute:
        break;
    }
  }

  /// A short hint about the GPS state, or null when all is well.
  String? _gpsHint(Floor floor) {
    if (!_gpsOn) return null;
    if (floor.georef == null) return _l10n.gpsNoGeoref;
    final fix = _planFix;
    if (fix == null) return _l10n.gpsSearching;
    if (!fix.inside) return _l10n.gpsOutside;
    if (!fix.usable) return _l10n.gpsWeak(fix.accuracyMeters.round());
    return null;
  }

  MapsLocalizations get _l10n => MapsLocalizations.of(context);

  /// Fits the camera to a new route (not after a re-route), or reports why
  /// there is none.
  void _onRouteAnswer(AsyncValue<MapRoute> next) {
    next.whenOrNull(
      data: (r) {
        if (!_fitNextRoute) return; // a re-route keeps the camera
        _fitNextRoute = false;
        final first = r.legs.first.floorId;
        // Show where the route starts, unless it passes the open floor.
        _showRouteOn(
          r,
          r.legs.any((l) => l.floorId == _floor?.id) && _floor?.id == first
              ? _floor!.id
              : first,
        );
      },
      error: (e, _) => _onRouteError(e),
    );
  }

  void _onRouteError(Object e) {
    final noRoute = e is MapsApiException && e.code == 'no_route';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(noRoute ? _l10n.routeNoRoute : _l10n.routeFailed)),
    );
    _closeRoute();
  }

  /// Bounds of the route's points on [floor], or null if it doesn't pass it.
  LatLngBounds? _routeBounds(MapRoute route, Floor floor) {
    final proj = PlanProjection(floor.width, floor.height);
    final pts = [
      for (final leg in route.legs)
        if (leg.floorId == floor.id) ...leg.points,
    ];
    if (pts.isEmpty) return null;
    // The whole destination, not just the point where the route ends.
    final target =
        _routeTarget ??
        _map.features.where((f) => f.id == _selectedId).firstOrNull;
    if (target != null && target.floorId == floor.id) {
      pts.addAll(outline(target.geometry));
    }
    const r = 60.0; // plan pixels, so a short route isn't zoomed in too far
    var minX = pts.first.x, maxX = minX, minY = pts.first.y, maxY = minY;
    for (final p in pts) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return LatLngBounds(
      proj.toLatLng(PlanPoint(minX - r, maxY + r)),
      proj.toLatLng(PlanPoint(maxX + r, minY - r)),
    );
  }

  /// Shows the route's part on [floorId], switching floors if needed.
  void _showRouteOn(MapRoute route, String floorId) {
    if (floorId != _floor?.id) {
      setState(() {
        _floorId = floorId;
        _pendingFocus = null; // the new map starts on the route instead
      });
      // The shared controller keeps the old floor's camera; fit once the
      // new floor's map is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _floor?.id == floorId) _showRouteOn(route, floorId);
      });
      return;
    }
    final floor = _floor!;
    final bounds = _routeBounds(route, floor);
    if (bounds == null) return;
    _controller.fitCamera(
      PlanProjection(
        floor.width,
        floor.height,
      ).fit(bounds, padding: _routePadding, maxScale: 2),
    );
  }

  /// The banner telling the attendee to change floors, if the route goes on.
  Widget? _floorBanner(MapRoute route, Floor floor) {
    final legs = route.legs;
    final names = {for (final f in _map.floors) f.id: f.name};
    final here = legs.lastIndexWhere((l) => l.floorId == floor.id);
    if (here == -1) {
      final first = legs.first.floorId;
      return RouteFloorBanner(
        text: _l10n.routeStartsOn(names[first] ?? ''),
        icon: Icons.layers,
        onShow: () => _showRouteOn(route, first),
      );
    }
    if (here + 1 >= legs.length) return null;
    final next = legs[here + 1];
    final name = names[next.floorId] ?? '';
    return RouteFloorBanner(
      text: switch (next.arriveBy) {
        ArriveBy.lift => _l10n.routeByLift(name),
        ArriveBy.stairs => _l10n.routeByStairs(name),
        null => _l10n.routeContinue(name),
      },
      icon: next.arriveBy == ArriveBy.stairs ? Icons.stairs : Icons.elevator,
      onShow: () => _showRouteOn(route, next.floorId),
    );
  }

  /// Map usage stats (never positions); see [StatsReporter].
  StatsReporter get _stats =>
      ref.read(mapsStatsReporterProvider(widget.event.id));

  /// A search counts once the attendee stops typing or opens a result.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    if (_searchCtrl.text.trim().isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 1500), _reportSearch);
  }

  void _reportSearch() {
    _searchDebounce?.cancel();
    final text = _searchCtrl.text;
    if (!mounted || text.trim().isEmpty) return;
    final results = FeatureSearch(
      _map.features,
      labelOf: (f) => kindLabel(_l10n, f),
    ).search(text, filter: _filter, category: _category);
    _stats.search(text, results.length);
  }

  void _openResult(Feature f) {
    _browsing = false;
    _reportSearch();
    _searchFocus.unfocus();
    _focus(f);
    _select(f);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    ref.watch(mapsStatsReporterProvider(widget.event.id)); // alive while open
    final floor = _floor;
    final q = _routeQuery;
    final routeAsync = q == null ? null : ref.watch(mapsRouteProvider(q));
    if (q != null) {
      ref.listen(mapsRouteProvider(q), (_, next) => _onRouteAnswer(next));
    }
    final pq = _routeQuery == null ? _previewQuery : null;
    if (pq != null) {
      ref.listen(mapsRouteProvider(pq), (_, next) {
        final r = next.value;
        if (r == null || !_fitNextPreview) return;
        _fitNextPreview = false;
        final floor = _floor;
        final bounds = floor == null ? null : _routeBounds(r, floor);
        if (bounds == null) return; // the route doesn't pass this floor
        _controller.fitCamera(
          PlanProjection(
            floor!.width,
            floor.height,
          ).fit(bounds, padding: _previewPadding, maxScale: 2),
        );
      });
    }
    final preview = pq == null ? null : ref.watch(mapsRouteProvider(pq)).value;
    final route = routeAsync?.value;
    final routing = _routeTarget != null && q != null;
    final shown = routing ? route : preview;
    final picking = _pickingFor != null;
    final searching =
        !routing &&
        !picking &&
        (_browsing || _searchFocus.hasFocus || _searchCtrl.text.isNotEmpty);
    final here = _here;
    final fix = _planFix;
    final highlight = widget.highlightLabel == null
        ? null
        : _map.features
              .where((f) => f.id == widget.highlightFeatureId)
              .firstOrNull;
    final gpsHint = floor == null ? null : _gpsHint(floor);
    final banner = routing && route != null && floor != null
        ? _floorBanner(route, floor)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.event.name), centerTitle: false),
      body: floor == null
          ? Center(child: Text(l10n.mapEmpty))
          : Stack(
              children: [
                Positioned.fill(
                  child: VenueMapView(
                    floor: floor,
                    features: _map.featuresOn(floor.id).toList(),
                    controller: _controller,
                    selectedId: _selectedId,
                    initialFocus: _pendingFocus?.floorId == floor.id
                        ? _boundsOf(
                            _pendingFocus!,
                            PlanProjection(floor.width, floor.height),
                          )
                        : (routing && route != null
                              ? _routeBounds(route, floor)
                              : null),
                    onPlanTap: picking ? _pickedStart : null,
                    onFeatureTap: (f) {
                      _searchFocus.unfocus();
                      _select(f);
                    },
                    underLabels: [
                      if (fix != null && fix.inside)
                        GpsAccuracyLayer(
                          at: fix.at,
                          radiusPixels: fix.accuracyPixels,
                          proj: PlanProjection(floor.width, floor.height),
                          weak: !fix.usable,
                        ),
                      if (shown != null)
                        routeLines(
                          context,
                          shown,
                          floor.id,
                          PlanProjection(floor.width, floor.height),
                        ),
                    ],
                    overLabels: [
                      if (here != null && here.floorId == floor.id)
                        youAreHereMarker(
                          context,
                          here.at,
                          PlanProjection(floor.width, floor.height),
                          l10n.youAreHere,
                        ),
                      if (highlight != null && highlight.floorId == floor.id)
                        placeLabelMarker(
                          context,
                          highlight.geometry.center,
                          PlanProjection(floor.width, floor.height),
                          widget.highlightLabel!,
                        ),
                      if (shown != null)
                        routeMarkers(
                          context,
                          shown,
                          floor.id,
                          PlanProjection(floor.width, floor.height),
                        ),
                    ],
                  ),
                ),
                if (picking)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: PickStartBanner(
                      onCancel: () => setState(() => _pickingFor = null),
                    ),
                  )
                else if (routing && banner != null)
                  Positioned(left: 12, right: 12, top: 12, child: banner)
                else if (!routing)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: _SearchPanel(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      expanded: searching,
                      map: _map,
                      filter: _filter,
                      category: _category,
                      onFilter: (f) => setState(() => _filter = f),
                      onCategory: (c) => setState(() => _category = c),
                      onOpen: _openResult,
                      onClose: () => setState(() {
                        _browsing = false;
                        _filter = SearchFilter.all;
                      }),
                      quickChips: searching ? null : _quickChips(floor),
                    ),
                  ),
                if (!searching)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // While routing the search bar (and its floor
                            // chips) is hidden, so the floors sit here.
                            if (routing && _map.floors.length > 1)
                              Flexible(child: _floorChips(floor)),
                            const Spacer(),
                            _fabs(l10n, floor),
                          ],
                        ),
                        if (gpsHint != null) ...[
                          const SizedBox(height: 12),
                          GpsHintCard(text: gpsHint),
                        ],
                        if (routing) ...[
                          const SizedBox(height: 12),
                          RouteSummaryCard(
                            target: _routeTarget!,
                            route: route,
                            loading: routeAsync?.isLoading ?? false,
                            accessible: _map.floors.length > 1
                                ? q.accessible
                                : null,
                            onAccessible: (on) => setState(
                              () => _routeQuery = q.copyWith(accessible: on),
                            ),
                            onClose: _closeRoute,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _fabs(MapsLocalizations l10n, Floor floor) {
    final scheme = Theme.of(context).colorScheme;
    Widget fab(String tag, String tooltip, IconData icon, VoidCallback onTap) =>
        FloatingActionButton.small(
          heroTag: tag,
          tooltip: tooltip,
          onPressed: onTap,
          elevation: 2,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          child: Icon(icon, size: 22),
        );
    final proj = PlanProjection(floor.width, floor.height);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_anyGeoref) ...[
          FloatingActionButton.small(
            heroTag: 'gps',
            tooltip: l10n.gpsMyLocation,
            onPressed: _onMyLocation,
            elevation: 2,
            backgroundColor: _gpsOn ? scheme.primary : scheme.surface,
            foregroundColor: _gpsOn ? scheme.onPrimary : scheme.onSurface,
            child: Icon(
              !_gpsOn
                  ? Icons.location_searching
                  : (_planFix?.usable ?? false)
                  ? Icons.my_location
                  : Icons.gps_not_fixed,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
        ],
        fab(
          'legend',
          l10n.legend,
          Icons.help_outline,
          () => showDialog<void>(
            context: context,
            builder: (_) => const _Legend(),
          ),
        ),
        const SizedBox(height: 10),
        fab(
          'fit',
          l10n.fitPlan,
          Icons.fit_screen,
          () => _controller.fitCamera(proj.fitPlan(padding: planFitPadding)),
        ),
      ],
    );
  }

  /// Floors and quick filters under the search bar (Map.dc.html).
  List<Widget> _quickChips(Floor floor) {
    final l10n = _l10n;
    final scheme = Theme.of(context).colorScheme;
    final hasSponsors = _map.features.any(
      (f) => f.type != FeatureType.marker && f.sponsorTier != SponsorTier.none,
    );
    final hasFood = _map.features.any(
      (f) => f.type == FeatureType.poi && f.poiKind == 'food',
    );
    Widget chip(String label, {required bool selected, VoidCallback? onTap}) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: scheme.inverseSurface,
          labelStyle: TextStyle(
            color: selected ? scheme.onInverseSurface : scheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
          backgroundColor: scheme.surface,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          elevation: 1,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          onSelected: (_) => onTap?.call(),
        );
    void browse(SearchFilter f) => setState(() {
      _filter = f;
      _category = null;
      _browsing = true;
    });
    return [
      for (final f in _map.floors)
        chip(
          f.name,
          selected: f.id == floor.id,
          onTap: () => setState(() {
            _floorId = f.id;
            _pendingFocus = null;
          }),
        ),
      if (hasSponsors)
        chip(
          l10n.filterSponsors,
          selected: false,
          onTap: () => browse(SearchFilter.sponsors),
        ),
      if (hasFood)
        chip(
          l10n.filterFood,
          selected: false,
          onTap: () => browse(SearchFilter.food),
        ),
      chip(
        l10n.filterRooms,
        selected: false,
        onTap: () => browse(SearchFilter.rooms),
      ),
      chip(
        l10n.filterStands,
        selected: false,
        onTap: () => browse(SearchFilter.stands),
      ),
    ];
  }

  Widget _floorChips(Floor floor) => Card(
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Wrap(
        spacing: 6,
        children: [
          for (final f in _map.floors)
            ChoiceChip(
              label: Text(f.name),
              selected: f.id == floor.id,
              onSelected: (_) => setState(() {
                _floorId = f.id;
                _pendingFocus = null;
              }),
            ),
        ],
      ),
    ),
  );
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.map,
    required this.filter,
    required this.category,
    required this.onFilter,
    required this.onCategory,
    required this.onOpen,
    required this.onClose,
    this.quickChips,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expanded;
  final VenueMap map;
  final SearchFilter filter;
  final String? category;
  final ValueChanged<SearchFilter> onFilter;
  final ValueChanged<String?> onCategory;
  final ValueChanged<Feature> onOpen;
  final VoidCallback onClose;

  /// Shown under the search bar while it is closed (floors, quick filters).
  final List<Widget>? quickChips;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final search = FeatureSearch(
      map.features,
      labelOf: (f) => kindLabel(l10n, f),
    );
    final results = expanded
        ? search.search(controller.text, filter: filter, category: category)
        : const <Feature>[];
    final floorNames = {for (final f in map.floors) f.id: f.name};
    final categories = search.categories;

    final card = Card(
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: 0.25),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: expanded
                  ? IconButton(
                      tooltip: l10n.clearSearch,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        focusNode.unfocus();
                        onCategory(null);
                        onClose();
                      },
                    )
                  : null,
              border: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onSubmitted: (_) {
              if (results.isNotEmpty) onOpen(results.first);
            },
          ),
          if (expanded) ...[
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final (f, label) in [
                    (SearchFilter.all, l10n.filterAll),
                    (SearchFilter.rooms, l10n.filterRooms),
                    (SearchFilter.stands, l10n.filterStands),
                    (SearchFilter.pois, l10n.filterPois),
                    if (filter == SearchFilter.sponsors)
                      (SearchFilter.sponsors, l10n.filterSponsors),
                    if (filter == SearchFilter.food)
                      (SearchFilter.food, l10n.filterFood),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: filter == f,
                        onSelected: (_) => onFilter(f),
                      ),
                    ),
                  if (categories.isNotEmpty) const VerticalDivider(width: 16),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(c),
                        selected: category == c,
                        onSelected: (on) => onCategory(on ? c : null),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l10n.searchNoResults(controller.text)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final f = results[i];
                        final subtitle = [
                          kindLabel(l10n, f),
                          if (f.company.isNotEmpty) f.company,
                          if (map.floors.length > 1)
                            floorNames[f.floorId] ?? '',
                        ].where((s) => s.isNotEmpty).join(' · ');
                        return ListTile(
                          minTileHeight: 60,
                          leading: Icon(featureIcon(f)),
                          title: Text(f.name),
                          subtitle: Text(subtitle),
                          trailing: f.sponsorTier == SponsorTier.gold
                              ? const Icon(
                                  Icons.workspace_premium,
                                  color: MapPalette.gold,
                                )
                              : null,
                          onTap: () => onOpen(f),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
    final chips = quickChips;
    if (chips == null || chips.isEmpty) return card;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => chips[i],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final palette = MapPalette.of(context);
    Widget swatch(Color fill, Color border, double width) => Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.35),
        border: Border.all(color: border, width: width),
        borderRadius: BorderRadius.circular(3),
      ),
    );
    final pois = [
      ('entrance', l10n.poiEntrance),
      ('toilet', l10n.poiToilet),
      ('info', l10n.poiInfo),
      ('cloakroom', l10n.poiCloakroom),
      ('food', l10n.poiFood),
      ('lift', l10n.poiLift),
      ('stairs', l10n.poiStairs),
    ];
    return AlertDialog(
      title: Text(l10n.legend),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: swatch(palette.room, palette.room, 1.5),
              title: Text(l10n.typeRoom),
            ),
            ListTile(
              leading: swatch(palette.stand, palette.stand, 1.5),
              title: Text(l10n.typeStand),
            ),
            ListTile(
              leading: swatch(palette.stand, MapPalette.gold, 3.5),
              title: Text(l10n.sponsorGold),
            ),
            for (final (kind, label) in pois)
              ListTile(
                leading: Icon(
                  featureIcon(
                    Feature(
                      id: '',
                      type: FeatureType.poi,
                      floorId: '',
                      name: '',
                      poiKind: kind,
                      geometry: const Geometry(GeometryKind.point, [
                        PlanPoint(0, 0),
                      ]),
                    ),
                  ),
                ),
                title: Text(label),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
