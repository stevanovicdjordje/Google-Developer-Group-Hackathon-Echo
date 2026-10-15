import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/georef.dart';
import '../model/map_models.dart';
import 'editor_ops.dart';
import 'maps_api.dart';

/// Base URL of the map API (`backend/maps`). The app overrides it from its config.
final mapsApiBaseUrlProvider = Provider<String>(
  (ref) => 'http://localhost:8080',
);

final mapsApiProvider = Provider<MapsApi>(
  (ref) => MapsApi(
    baseUrl: ref.watch(mapsApiBaseUrlProvider),
    tokenProvider: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  ),
);

/// The signed-in organizer, or null (signed out or anonymous attendee).
final organizerUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges().map(
    (u) => u == null || u.isAnonymous ? null : u,
  ),
);

/// Reloads whenever the signed-in organizer changes.
final myEventsProvider = FutureProvider.autoDispose<List<OrganizerEvent>>((
  ref,
) async {
  await ref.watch(organizerUserProvider.future);
  return ref.watch(mapsApiProvider).listMyEvents();
}, retry: (_, _) => null);

class EditorState {
  const EditorState({
    required this.event,
    required this.draft,
    this.savingGraph = false,
    this.graphError,
  });

  final OrganizerEvent event;
  final VenueMap draft;
  final bool savingGraph;

  /// Last failed graph save; the local graph is kept so nothing is lost.
  final String? graphError;

  FloorGraph graphOf(String floorId) =>
      draft.graphs.where((g) => g.floorId == floorId).firstOrNull ??
      emptyGraph(floorId);

  EditorState copyWith({
    OrganizerEvent? event,
    VenueMap? draft,
    bool? savingGraph,
    String? graphError,
    bool clearGraphError = false,
  }) => EditorState(
    event: event ?? this.event,
    draft: draft ?? this.draft,
    savingGraph: savingGraph ?? this.savingGraph,
    graphError: clearGraphError ? null : (graphError ?? this.graphError),
  );
}

VenueMap _withMap(
  VenueMap m, {
  List<Floor>? floors,
  List<Feature>? features,
  List<FloorGraph>? graphs,
}) => VenueMap(
  floors: (floors ?? m.floors)..sort((a, b) => a.order.compareTo(b.order)),
  features: features ?? m.features,
  graphs: graphs ?? m.graphs,
);

/// Draft map of one event, edited through the API. Mutations throw
/// [MapsApiException] (or Storage errors) for the UI to show.
class EditorController extends AsyncNotifier<EditorState> {
  EditorController(this.eventId);

  final String eventId;

  static const _graphSaveDelay = Duration(milliseconds: 400);
  final _pendingGraphs = <String, Timer>{};
  Future<void> _graphSaves = Future.value();

  MapsApi get _api => ref.read(mapsApiProvider);

  @override
  Future<EditorState> build() async {
    ref.onDispose(() {
      for (final t in _pendingGraphs.values) {
        t.cancel();
      }
    });
    // Reload for another organizer; never call the API signed out.
    await ref.watch(organizerUserProvider.future);
    final (event, draft) = await (
      _api.getEvent(eventId),
      _api.getDraft(eventId),
    ).wait;
    return EditorState(event: event, draft: draft);
  }

  EditorState get _s => state.requireValue;

  void _set(EditorState s) => state = AsyncData(s);

  Future<Feature> createFeature(FeatureDraft d) async {
    final f = await _api.createFeature(eventId, d.toJson());
    _set(
      _s.copyWith(
        draft: _withMap(_s.draft, features: [..._s.draft.features, f]),
      ),
    );
    return f;
  }

  Future<Feature> updateFeature(String id, FeatureDraft d) async {
    final f = await _api.updateFeature(eventId, id, d.toJson(patch: true));
    _set(
      _s.copyWith(
        draft: _withMap(
          _s.draft,
          features: [for (final x in _s.draft.features) x.id == id ? f : x],
        ),
      ),
    );
    return f;
  }

  Future<void> deleteFeature(String id) async {
    await _api.deleteFeature(eventId, id);
    _set(
      _s.copyWith(
        draft: _withMap(
          _s.draft,
          features: [
            for (final x in _s.draft.features)
              if (x.id != id) x,
          ],
        ),
      ),
    );
  }

  /// Uploads the plan image to Storage, then registers the floor.
  Future<Floor> addFloor({
    required String name,
    required int order,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final lower = fileName.toLowerCase();
    final contentType = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
    final safe = lower.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    final path =
        'events/$eventId/floors/${DateTime.now().millisecondsSinceEpoch}-$safe';
    await FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
    final floor = await _api.createFloor(
      eventId,
      name: name,
      order: order,
      imagePath: path,
    );
    _set(
      _s.copyWith(
        draft: _withMap(_s.draft, floors: [..._s.draft.floors, floor]),
      ),
    );
    return floor;
  }

  Future<void> updateFloor(String floorId, {String? name, int? order}) async {
    final floor = await _api.updateFloor(eventId, floorId, {
      'name': ?name,
      'order': ?order,
    });
    _set(
      _s.copyWith(
        draft: _withMap(
          _s.draft,
          floors: [
            for (final f in _s.draft.floors) f.id == floorId ? floor : f,
          ],
        ),
      ),
    );
  }

  void _replaceFloor(Floor floor) => _set(
    _s.copyWith(
      draft: _withMap(
        _s.draft,
        floors: [for (final f in _s.draft.floors) f.id == floor.id ? floor : f],
      ),
    ),
  );

  /// Saves the floor's 3 GPS control points; returns the server's quality.
  Future<GeorefQuality> putGeoref(
    String floorId,
    List<ControlPoint> controlPoints,
  ) async {
    final (floor, quality) = await _api.putGeoref(
      eventId,
      floorId,
      controlPoints,
    );
    _replaceFloor(floor);
    return quality;
  }

  Future<void> deleteGeoref(String floorId) async {
    await _api.deleteGeoref(eventId, floorId);
    final f = _s.draft.floors.firstWhere((x) => x.id == floorId);
    _replaceFloor(
      Floor(
        id: f.id,
        name: f.name,
        order: f.order,
        imagePath: f.imagePath,
        width: f.width,
        height: f.height,
      ),
    );
  }

  Future<void> deleteFloor(String floorId) async {
    _pendingGraphs.remove(floorId)?.cancel();
    await _api.deleteFloor(eventId, floorId);
    final d = _s.draft;
    _set(
      _s.copyWith(
        draft: _withMap(
          d,
          floors: [
            for (final f in d.floors)
              if (f.id != floorId) f,
          ],
          features: [
            for (final f in d.features)
              if (f.floorId != floorId) f,
          ],
          graphs: [
            for (final g in d.graphs)
              if (g.floorId != floorId) g,
          ],
        ),
      ),
    );
  }

  /// Applies a graph edit locally right away and saves it shortly after,
  /// so quick successive taps become one request.
  void setGraph(FloorGraph graph) {
    final d = _s.draft;
    _set(
      _s.copyWith(
        draft: _withMap(
          d,
          graphs: [
            for (final g in d.graphs)
              if (g.floorId != graph.floorId) g,
            graph,
          ],
        ),
        savingGraph: true,
      ),
    );
    _pendingGraphs[graph.floorId]?.cancel();
    _pendingGraphs[graph.floorId] = Timer(
      _graphSaveDelay,
      () => _saveGraph(graph.floorId),
    );
  }

  Future<void> _saveGraph(String floorId) {
    _pendingGraphs.remove(floorId);
    _graphSaves = _graphSaves.then((_) async {
      if (!ref.mounted) return;
      try {
        await _api.putGraph(eventId, _s.graphOf(floorId));
        if (!ref.mounted) return;
        _set(
          _s.copyWith(
            savingGraph: _pendingGraphs.isNotEmpty,
            clearGraphError: true,
          ),
        );
      } on Object catch (e) {
        if (!ref.mounted) return;
        _set(
          _s.copyWith(
            savingGraph: _pendingGraphs.isNotEmpty,
            graphError: e is MapsApiException ? e.message : '$e',
          ),
        );
      }
    });
    return _graphSaves;
  }

  /// Saves pending graph edits now (before publishing).
  Future<void> flushGraphs() async {
    for (final id in _pendingGraphs.keys.toList()) {
      _pendingGraphs[id]?.cancel();
      unawaited(_saveGraph(id));
    }
    await _graphSaves;
  }

  /// Retries a failed graph save.
  Future<void> retryGraphs() async {
    for (final f in _s.draft.floors) {
      unawaited(_saveGraph(f.id));
    }
    await _graphSaves;
  }

  Future<PublishResult> publish() async {
    await flushGraphs();
    if (_s.graphError != null) {
      throw MapsApiException(0, 'graph_not_saved', _s.graphError!);
    }
    final r = await _api.publish(eventId);
    if (r.ok) {
      _set(_s.copyWith(event: await _api.getEvent(eventId)));
    }
    return r;
  }
}

final editorProvider = AsyncNotifierProvider.autoDispose
    .family<EditorController, EditorState, String>(
      EditorController.new,
      retry: (_, _) => null,
    );
