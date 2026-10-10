import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/maps_localizations.dart';
import '../model/map_models.dart';
import '../viewer/hit_test.dart';
import 'editor_canvas.dart';
import 'editor_ops.dart';
import 'editor_providers.dart';
import 'feature_form.dart';
import 'maps_api.dart';
import 'organizer_screens.dart';

enum EditorTool { select, room, stand, poi, marker, walkway }

/// Organizer editor of an event's draft map (`/o/e/{eventId}`).
class MapEditorScreen extends StatelessWidget {
  const MapEditorScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) =>
      OrganizerGate(child: _EditorLoader(eventId: eventId));
}

/// Loads the draft only once an organizer is signed in.
class _EditorLoader extends ConsumerWidget {
  const _EditorLoader({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = MapsLocalizations.of(context);
    return ref
        .watch(editorProvider(eventId))
        .when(
          skipLoadingOnReload: true,
          data: (s) => _Editor(eventId: eventId, state: s),
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      e is MapsApiException &&
                              (e.statusCode == 404 || e.statusCode == 403)
                          ? l10n.mapNotFound
                          : l10n.mapUnavailable,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(editorProvider(eventId)),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

/// Shows an API/Storage error as a snackbar.
void showEditorError(BuildContext context, Object e) {
  final l10n = MapsLocalizations.of(context);
  final msg = e is MapsApiException
      ? [e.message, ...e.fieldErrors].join('\n')
      : '$e';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.saveFailed(msg)), showCloseIcon: true),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.eventId, required this.state});

  final String eventId;
  final EditorState state;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _map = MapController();
  String? _floorId;
  EditorTool _tool = EditorTool.select;
  final _drawing = <PlanPoint>[];
  String? _activeNodeId;
  String? _selectedFeatureId;
  String? _selectedNodeId;
  FeatureDraft? _newDraft;
  String? _movingId;
  bool _publishing = false;

  EditorController get _ctrl =>
      ref.read(editorProvider(widget.eventId).notifier);
  VenueMap get _draft => widget.state.draft;

  Floor? get _floor {
    final floors = _draft.floors;
    if (floors.isEmpty) return null;
    return floors.where((f) => f.id == _floorId).firstOrNull ?? floors.first;
  }

  Feature? get _selectedFeature =>
      _draft.features.where((f) => f.id == _selectedFeatureId).firstOrNull;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _resetInteraction() {
    _drawing.clear();
    _activeNodeId = null;
    _selectedFeatureId = null;
    _selectedNodeId = null;
    _newDraft = null;
    _movingId = null;
  }

  void _setTool(EditorTool t) => setState(() {
    _resetInteraction();
    _tool = t;
  });

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showEditorError(context, e);
    }
  }

  void _startNew(FeatureType type, Geometry g) {
    final floor = _floor!;
    setState(() {
      _drawing.clear();
      _newDraft = FeatureDraft(
        type: type,
        floorId: floor.id,
        geometry: clampTo(g, floor.width, floor.height),
        poiKind: type == FeatureType.poi ? 'info' : null,
        entranceNodeId: nearestNode(
          widget.state.graphOf(floor.id),
          g.center,
        )?.id,
      );
    });
  }

  void _finishArea() {
    final g = areaFrom(_drawing);
    if (g == null) {
      setState(_drawing.clear);
      return;
    }
    _startNew(
      _tool == EditorTool.room ? FeatureType.room : FeatureType.stand,
      g,
    );
  }

  void _onTap(PlanPoint p, double tolerance) {
    final floor = _floor;
    if (floor == null) return;
    // Taps outside the plan are ignored; shapes must stay on the image.
    if (p.x < 0 || p.y < 0 || p.x > floor.width || p.y > floor.height) return;
    final graph = widget.state.graphOf(floor.id);

    if (_newDraft != null) return; // finish or cancel the form first

    switch (_tool) {
      case EditorTool.select:
        final moving = _draft.features
            .where((f) => f.id == _movingId)
            .firstOrNull;
        if (moving != null) {
          final g = clampTo(
            moveCenterTo(moving.geometry, p),
            floor.width,
            floor.height,
          );
          setState(() => _movingId = null);
          _run(
            () => _ctrl
                .updateFeature(moving.id, FeatureDraft.of(moving)..geometry = g)
                .then((_) {}),
          );
          return;
        }
        final node = nearestNode(graph, p, maxDistance: tolerance);
        final feature = node == null
            ? featureAt(
                _draft.featuresOn(floor.id),
                p,
                tolerance: tolerance,
                includeMarkers: true,
              )
            : null;
        setState(() {
          _selectedNodeId = node?.id;
          _selectedFeatureId = feature?.id;
        });
      case EditorTool.room:
        setState(() => _drawing.add(p));
      case EditorTool.stand:
        setState(() => _drawing.add(p));
        if (_drawing.length == 2) _finishArea();
      case EditorTool.poi:
        _startNew(FeatureType.poi, Geometry(GeometryKind.point, [p]));
      case EditorTool.marker:
        _startNew(FeatureType.marker, Geometry(GeometryKind.point, [p]));
      case EditorTool.walkway:
        final hit = nearestNode(graph, p, maxDistance: tolerance);
        var g = graph;
        final String id;
        if (hit != null) {
          id = hit.id;
        } else {
          id = newNodeId(g);
          g = addNode(g, GraphNode(id: id, x: p.x, y: p.y));
        }
        if (_activeNodeId != null &&
            g.nodes.any((n) => n.id == _activeNodeId)) {
          g = connect(g, _activeNodeId!, id);
        }
        setState(() => _activeNodeId = id);
        if (!identical(g, graph)) _ctrl.setGraph(g);
    }
  }

  Future<void> _publish() async {
    final l10n = MapsLocalizations.of(context);
    setState(() => _publishing = true);
    try {
      final r = await _ctrl.publish();
      if (!mounted) return;
      setState(() => _publishing = false);
      final link = Uri.base.resolve('/e/${widget.eventId}').toString();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(r.ok ? l10n.publishedOk(r.version) : l10n.publishBlocked),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final i in r.errors)
                  ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(issueText(l10n, i, _draft)),
                    dense: true,
                    onTap: () => _showIssue(context, i),
                  ),
                if (r.warnings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l10n.publishWarnings),
                  ),
                  for (final i in r.warnings)
                    ListTile(
                      leading: const Icon(Icons.warning_amber),
                      title: Text(issueText(l10n, i, _draft)),
                      dense: true,
                      onTap: () => _showIssue(context, i),
                    ),
                ],
                if (r.ok)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(l10n.attendeeLink),
                    subtitle: SelectableText(link),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(l10n.copied)));
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (r.ok)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  this.context.push('/e/${widget.eventId}');
                },
                child: Text(l10n.openViewer),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (mounted) showEditorError(context, e);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Closes the publish dialog and selects the feature an issue is about.
  void _showIssue(BuildContext dialogContext, PublishIssue i) {
    final f = _draft.features.where((f) => f.id == i.featureId).firstOrNull;
    final floorId = f?.floorId ?? i.floorId;
    if (floorId == null) return;
    Navigator.pop(dialogContext);
    setState(() {
      _resetInteraction();
      _tool = EditorTool.select;
      _floorId = floorId;
      _selectedFeatureId = f?.id;
    });
  }

  Future<void> _addFloor() async {
    final created = await showDialog<Floor>(
      context: context,
      builder: (_) => _AddFloorDialog(
        ctrl: _ctrl,
        nextOrder: _draft.floors.isEmpty
            ? 0
            : _draft.floors
                      .map((f) => f.order)
                      .reduce((a, b) => a > b ? a : b) +
                  1,
      ),
    );
    if (created != null) {
      setState(() {
        _resetInteraction();
        _floorId = created.id;
      });
    }
  }

  Future<void> _renameFloor(Floor floor) async {
    final l10n = MapsLocalizations.of(context);
    final name = await _askText(context, l10n.renameFloor, floor.name);
    if (name == null || name.trim().isEmpty) return;
    await _run(() => _ctrl.updateFloor(floor.id, name: name.trim()));
  }

  Future<void> _deleteFloor(Floor floor) async {
    final l10n = MapsLocalizations.of(context);
    if (!await _confirm(context, l10n.deleteFloorConfirm(floor.name))) return;
    await _run(() async {
      await _ctrl.deleteFloor(floor.id);
      setState(() {
        _resetInteraction();
        _floorId = null;
      });
    });
  }

  Future<void> _deleteFeature(Feature f) async {
    final l10n = MapsLocalizations.of(context);
    if (!await _confirm(context, l10n.deleteConfirm(f.name))) return;
    await _run(() async {
      await _ctrl.deleteFeature(f.id);
      setState(() => _selectedFeatureId = null);
    });
  }

  String _hint(MapsLocalizations l10n) {
    final moving = _draft.features.where((f) => f.id == _movingId).firstOrNull;
    if (moving != null) return l10n.hintMove(moving.name);
    return switch (_tool) {
      EditorTool.select => l10n.hintSelect,
      EditorTool.room => l10n.hintRoom,
      EditorTool.stand => l10n.hintStand,
      EditorTool.poi => l10n.hintPoi,
      EditorTool.marker => l10n.hintMarker,
      EditorTool.walkway => l10n.hintWalkway,
    };
  }

  Widget? _panel(Floor floor) {
    final l10n = MapsLocalizations.of(context);
    final graph = widget.state.graphOf(floor.id);
    if (_newDraft != null) {
      return FeatureForm(
        key: const ValueKey('new'),
        draft: _newDraft!,
        graph: graph,
        isNew: true,
        onCancel: () => setState(() => _newDraft = null),
        onSave: (d) => _run(() async {
          await _ctrl.createFeature(d);
          if (mounted) setState(() => _newDraft = null);
        }),
      );
    }
    final f = _selectedFeature;
    if (f != null) {
      return FeatureForm(
        key: ValueKey('${f.id}/${f.hashCode}'),
        draft: FeatureDraft.of(f),
        graph: graph,
        isNew: false,
        onCancel: () => setState(() => _selectedFeatureId = null),
        onDelete: () => _deleteFeature(f),
        onMove: () => setState(() => _movingId = f.id),
        onSave: (d) => _run(() async {
          await _ctrl.updateFeature(f.id, d);
        }),
      );
    }
    final node = graph.nodes.where((n) => n.id == _selectedNodeId).firstOrNull;
    if (node != null) {
      final edges = graph.edges
          .where((e) => e.from == node.id || e.to == node.id)
          .length;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.walkwayNode,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('${node.id} · ${l10n.nodeEdges(edges)}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  _ctrl.setGraph(removeNode(graph, node.id));
                  setState(() => _selectedNodeId = null);
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.delete),
              ),
              FilledButton(
                onPressed: () => setState(() => _selectedNodeId = null),
                child: Text(l10n.close),
              ),
            ],
          ),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final s = widget.state;
    final floor = _floor;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final panel = floor == null ? null : _panel(floor);
    final areaTool = _tool == EditorTool.room || _tool == EditorTool.stand;

    final canvas = floor == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.noFloorsYet, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addFloor,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l10n.addFloor),
                  ),
                ],
              ),
            ),
          )
        : Stack(
            children: [
              Positioned.fill(
                child: EditorCanvas(
                  floor: floor,
                  features: _draft.featuresOn(floor.id).toList(),
                  graph: s.graphOf(floor.id),
                  controller: _map,
                  onTap: _onTap,
                  selectedFeatureId: _selectedFeatureId ?? _movingId,
                  selectedNodeId: _selectedNodeId,
                  activeNodeId: _activeNodeId,
                  // While the form is open, show the new shape.
                  drawing: _newDraft?.geometry.coords ?? _drawing,
                  drawingClosed: _newDraft != null
                      ? _newDraft!.geometry.kind != GeometryKind.point
                      : _tool == EditorTool.room || _tool == EditorTool.stand,
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_hint(l10n))),
                        if (areaTool && _drawing.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setState(() => _drawing.removeLast()),
                            child: Text(l10n.undoPoint),
                          ),
                        if (_tool == EditorTool.room && _drawing.length >= 2)
                          FilledButton(
                            onPressed: _finishArea,
                            child: Text(l10n.finishShape),
                          ),
                        if (_tool == EditorTool.walkway &&
                            _activeNodeId != null)
                          TextButton(
                            onPressed: () =>
                                setState(() => _activeNodeId = null),
                            child: Text(l10n.endWalkway),
                          ),
                        if (_movingId != null)
                          TextButton(
                            onPressed: () => setState(() => _movingId = null),
                            child: Text(l10n.cancel),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (s.savingGraph || s.graphError != null)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: s.graphError != null
                      ? ActionChip(
                          avatar: const Icon(Icons.error_outline),
                          label: Text(l10n.graphSaveFailed(s.graphError!)),
                          onPressed: () => _ctrl.retryGraphs(),
                        )
                      : Chip(label: Text(l10n.savingGraph)),
                ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.event.name),
            Text(
              s.event.publishedVersion > 0
                  ? l10n.publishedVersion(s.event.publishedVersion)
                  : l10n.notPublished,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (s.event.publishedVersion > 0)
            IconButton(
              tooltip: l10n.openViewer,
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => context.push('/e/${widget.eventId}'),
            ),
          IconButton(
            tooltip: l10n.reload,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(editorProvider(widget.eventId)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed: _publishing || _draft.floors.isEmpty ? null : _publish,
              icon: _publishing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish),
              label: Text(l10n.publish),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _Toolbar(
            floors: _draft.floors,
            floor: floor,
            tool: _tool,
            onFloor: (f) => setState(() {
              _resetInteraction();
              _floorId = f.id;
            }),
            onTool: _setTool,
            onAddFloor: _addFloor,
            onRenameFloor: _renameFloor,
            onDeleteFloor: _deleteFloor,
          ),
          const Divider(height: 1),
          Expanded(
            child: wide
                // The panel is always there so the plan doesn't jump when
                // something is selected.
                ? Row(
                    children: [
                      Expanded(child: canvas),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 380,
                        child:
                            panel ??
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _hint(l10n),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned.fill(child: canvas),
                      if (panel != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: MediaQuery.sizeOf(context).height * 0.45,
                          child: Material(elevation: 8, child: panel),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.floors,
    required this.floor,
    required this.tool,
    required this.onFloor,
    required this.onTool,
    required this.onAddFloor,
    required this.onRenameFloor,
    required this.onDeleteFloor,
  });

  final List<Floor> floors;
  final Floor? floor;
  final EditorTool tool;
  final ValueChanged<Floor> onFloor;
  final ValueChanged<EditorTool> onTool;
  final VoidCallback onAddFloor;
  final ValueChanged<Floor> onRenameFloor;
  final ValueChanged<Floor> onDeleteFloor;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final tools = [
      (EditorTool.select, Icons.near_me_outlined, l10n.toolSelect),
      (EditorTool.room, Icons.meeting_room_outlined, l10n.toolRoom),
      (EditorTool.stand, Icons.storefront_outlined, l10n.toolStand),
      (EditorTool.poi, Icons.place_outlined, l10n.toolPoi),
      (EditorTool.marker, Icons.qr_code_2, l10n.toolMarker),
      (EditorTool.walkway, Icons.timeline, l10n.toolWalkway),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          if (floor != null) ...[
            DropdownButton<String>(
              value: floor!.id,
              underline: const SizedBox.shrink(),
              items: [
                for (final f in floors)
                  DropdownMenuItem(value: f.id, child: Text(f.name)),
              ],
              onChanged: (id) => onFloor(floors.firstWhere((f) => f.id == id)),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.floor,
              onSelected: (v) => switch (v) {
                'add' => onAddFloor(),
                'rename' => onRenameFloor(floor!),
                _ => onDeleteFloor(floor!),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'add', child: Text(l10n.addFloor)),
                PopupMenuItem(value: 'rename', child: Text(l10n.renameFloor)),
                PopupMenuItem(value: 'delete', child: Text(l10n.deleteFloor)),
              ],
            ),
            const SizedBox(width: 8),
            SegmentedButton<EditorTool>(
              showSelectedIcon: false,
              segments: [
                for (final (t, icon, label) in tools)
                  ButtonSegment(
                    value: t,
                    icon: Icon(icon),
                    label: Text(label),
                    tooltip: label,
                  ),
              ],
              selected: {tool},
              onSelectionChanged: (s) => onTool(s.first),
            ),
          ] else
            TextButton.icon(
              onPressed: onAddFloor,
              icon: const Icon(Icons.add),
              label: Text(l10n.addFloor),
            ),
        ],
      ),
    );
  }
}

class _AddFloorDialog extends StatefulWidget {
  const _AddFloorDialog({required this.ctrl, required this.nextOrder});

  final EditorController ctrl;
  final int nextOrder;

  @override
  State<_AddFloorDialog> createState() => _AddFloorDialogState();
}

class _AddFloorDialogState extends State<_AddFloorDialog> {
  late final _name = TextEditingController();
  late final _order = TextEditingController(text: '${widget.nextOrder}');
  String? _fileName;
  Uint8List? _bytes;
  String? _error;
  bool _busy = false;

  static const _maxBytes = 10 * 1024 * 1024;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    final tooLarge = bytes.length > _maxBytes;
    setState(() {
      _fileName = f.name;
      _bytes = tooLarge ? null : bytes;
      _error = tooLarge ? MapsLocalizations.of(context).imageTooLarge : null;
    });
  }

  Future<void> _submit() async {
    final bytes = _bytes;
    if (bytes == null || _name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final floor = await widget.ctrl.addFloor(
        name: _name.text.trim(),
        order: int.tryParse(_order.text.trim()) ?? widget.nextOrder,
        bytes: bytes,
        fileName: _fileName!,
      );
      if (mounted) Navigator.pop(context, floor);
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = e is MapsApiException
            ? [e.message, ...e.fieldErrors].join('\n')
            : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final ready = _bytes != null && _name.text.trim().isNotEmpty && !_busy;
    return AlertDialog(
      title: Text(l10n.addFloor),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.floorName),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _order,
              decoration: InputDecoration(labelText: l10n.floorOrder),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.image_outlined),
              label: Text(_fileName ?? l10n.pickImage),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: ready ? _submit : null,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.create),
        ),
      ],
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String initial) {
  final l10n = MapsLocalizations.of(context);
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: Text(l10n.save),
        ),
      ],
    ),
  ).whenComplete(c.dispose);
}

Future<bool> _confirm(BuildContext context, String question) async {
  final l10n = MapsLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// A publish issue in the UI language; the server's English text is only the
/// detail of invalid graphs/features.
String issueText(MapsLocalizations l10n, PublishIssue i, VenueMap draft) {
  final name =
      draft.features.where((f) => f.id == i.featureId).firstOrNull?.name ??
      i.featureId ??
      '';
  final floor =
      draft.floors.where((f) => f.id == i.floorId).firstOrNull?.name ??
      i.floorId ??
      '';
  return switch (i.code) {
    'no_floors' => l10n.issueNoFloors,
    'invalid_graph' => l10n.issueInvalidGraph(floor, i.message),
    'invalid_feature' => l10n.issueInvalidFeature(name, i.message),
    'no_entrance' => l10n.issueNoEntrance(name),
    'unknown_entrance' => l10n.issueUnknownEntrance(name),
    'unreachable' => l10n.issueUnreachable(name),
    _ => i.message,
  };
}
