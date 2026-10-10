import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/maps_localizations.dart';
import '../data/published_map_repository.dart';
import '../editor/maps_api.dart';
import '../model/map_models.dart';
import '../model/route_models.dart';
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
  });

  final String eventId;

  /// Feature to select on open (`/e/{eventId}/stand/{standId}`).
  final String? initialFeatureId;

  /// "You are here" QR marker the attendee scanned (`?at=`).
  final String? markerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = MapsLocalizations.of(context);
    final event = ref.watch(publishedEventProvider(eventId));

    return event.when(
      skipLoadingOnReload: true,
      data: (e) => _Viewer(
        event: e,
        markerId: markerId,
        initialFeatureId: initialFeatureId ?? markerId,
        openSheet: initialFeatureId != null,
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
  const _Message({required this.title, this.child});

  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ?child,
          ],
        ),
      ),
    ),
  );
}

/// Room for the search bar / banner on top and the route card at the bottom.
const _routePadding = EdgeInsets.fromLTRB(48, 130, 48, 240);

class _Viewer extends ConsumerStatefulWidget {
  const _Viewer({
    required this.event,
    this.markerId,
    this.initialFeatureId,
    this.openSheet = false,
  });

  final PublishedEvent event;
  final String? markerId;
  final String? initialFeatureId;
  final bool openSheet;

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

  /// The route being shown, and where it goes.
  RouteQuery? _routeQuery;
  Feature? _routeTarget;

  /// Set while the attendee taps where they are; the route then goes here.
  Feature? _pickingFor;

  /// Where the attendee said they are by tapping the map.
  ({String floorId, PlanPoint at})? _pickedHere;

  VenueMap get _map => widget.event.map;

  /// The scanned QR marker (`?at=`), if it is on the map.
  Feature? get _marker => widget.markerId == null
      ? null
      : _map.features.where((f) => f.id == widget.markerId).firstOrNull;

  /// "You are here": a picked point, else the scanned QR marker.
  ({String floorId, PlanPoint at})? get _here {
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
    _searchFocus.addListener(() => setState(() {}));
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

  Future<void> _select(Feature? f) async {
    setState(() => _selectedId = f?.id);
    if (f == null) return;
    final floorName = _map.floors.length > 1
        ? _map.floors.where((x) => x.id == f.floorId).firstOrNull?.name
        : null;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => FeatureDetails(
        feature: f,
        floorName: floorName,
        onRoute: f.type == FeatureType.marker
            ? null
            : () {
                Navigator.pop(sheet);
                _routeTo(f);
              },
      ),
    );
    if (mounted && _selectedId == f.id) setState(() => _selectedId = null);
  }

  /// Starts a route to [to] from the QR marker or a picked point; otherwise
  /// asks where the attendee is.
  Future<void> _routeTo(Feature to) async {
    final marker = _marker;
    final here = _pickedHere;
    if (here != null) {
      _requestRoute(RouteEndpoint.point(here.floorId, here.at), to);
      return;
    }
    if (marker != null) {
      _requestRoute(RouteEndpoint.feature(marker.id), to);
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

  void _requestRoute(RouteEndpoint from, Feature to) {
    if (from.featureId == to.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_l10n.routeAlreadyHere)));
      return;
    }
    _searchFocus.unfocus();
    _searchCtrl.clear(); // closing the route goes back to the plain map
    setState(() {
      _selectedId = null;
      _routeTarget = to;
      _routeQuery = RouteQuery(
        eventId: widget.event.id,
        from: from,
        to: RouteEndpoint.feature(to.id),
        version: _map.version,
        accessible: _routeQuery?.accessible ?? false,
      );
    });
  }

  void _closeRoute() => setState(() {
    _routeQuery = null;
    _routeTarget = null;
  });

  MapsLocalizations get _l10n => MapsLocalizations.of(context);

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

  void _openResult(Feature f) {
    _searchFocus.unfocus();
    _focus(f);
    _select(f);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final floor = _floor;
    final q = _routeQuery;
    final routeAsync = q == null ? null : ref.watch(mapsRouteProvider(q));
    if (q != null) {
      ref.listen(mapsRouteProvider(q), (_, next) {
        next.whenOrNull(
          data: (r) {
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
      });
    }
    final route = routeAsync?.value;
    final routing = _routeTarget != null && q != null;
    final picking = _pickingFor != null;
    final searching =
        !routing &&
        !picking &&
        (_searchFocus.hasFocus || _searchCtrl.text.isNotEmpty);
    final here = _here;
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
                      if (routing && route != null)
                        routeLines(
                          context,
                          route,
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
                      if (routing && route != null)
                        routeMarkers(
                          context,
                          route,
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
                            if (_map.floors.length > 1)
                              Flexible(child: _floorChips(floor)),
                            const Spacer(),
                            _fabs(l10n, floor),
                          ],
                        ),
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

  Widget _fabs(MapsLocalizations l10n, Floor floor) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FloatingActionButton.small(
        heroTag: 'legend',
        tooltip: l10n.legend,
        onPressed: () =>
            showDialog<void>(context: context, builder: (_) => const _Legend()),
        child: const Icon(Icons.help_outline),
      ),
      const SizedBox(height: 12),
      FloatingActionButton(
        heroTag: 'fit',
        tooltip: l10n.fitPlan,
        onPressed: () => _controller.fitCamera(
          PlanProjection(
            floor.width,
            floor.height,
          ).fit(PlanProjection(floor.width, floor.height).bounds),
        ),
        child: const Icon(Icons.fit_screen),
      ),
    ],
  );

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

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final search = FeatureSearch(
      map.features,
      labelOf: (f) => kindLabel(l10n, f),
    );
    final results = expanded
        ? search.search(controller.text, filter: filter, category: category)
        : const <Feature>[];
    final floorNames = {for (final f in map.floors) f.id: f.name};
    final categories = search.categories;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 18),
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
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
