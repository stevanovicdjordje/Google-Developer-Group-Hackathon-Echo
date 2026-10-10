import 'package:flutter/material.dart';

import '../../l10n/maps_localizations.dart';
import '../model/map_models.dart';
import '../viewer/labels.dart';
import 'editor_ops.dart';

const poiKinds = [
  'entrance',
  'toilet',
  'info',
  'cloakroom',
  'food',
  'lift',
  'stairs',
];

String typeLabel(MapsLocalizations l10n, FeatureType t) => switch (t) {
  FeatureType.room => l10n.typeRoom,
  FeatureType.stand => l10n.typeStand,
  FeatureType.poi => l10n.typePoi,
  FeatureType.marker => l10n.typeMarker,
};

String poiKindLabel(MapsLocalizations l10n, String kind) => kindLabel(
  l10n,
  Feature(
    id: '',
    type: FeatureType.poi,
    floorId: '',
    name: '',
    geometry: const Geometry(GeometryKind.point, []),
    poiKind: kind,
  ),
);

/// Properties of a new or existing feature. Saving returns the edited
/// [FeatureDraft] through [onSave]; the caller talks to the API.
class FeatureForm extends StatefulWidget {
  const FeatureForm({
    super.key,
    required this.draft,
    required this.graph,
    required this.isNew,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
    this.onMove,
  });

  final FeatureDraft draft;
  final FloorGraph graph;
  final bool isNew;
  final Future<void> Function(FeatureDraft) onSave;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onMove;

  @override
  State<FeatureForm> createState() => _FeatureFormState();
}

class _FeatureFormState extends State<FeatureForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.draft.name);
  late final _description = TextEditingController(
    text: widget.draft.description,
  );
  late final _capacity = TextEditingController(
    text: widget.draft.capacity?.toString() ?? '',
  );
  late final _company = TextEditingController(text: widget.draft.company);
  late final _category = TextEditingController(text: widget.draft.category);
  late final _link = TextEditingController(text: widget.draft.link);
  late SponsorTier _tier = widget.draft.sponsorTier;
  late String? _poiKind = widget.draft.poiKind;
  late String? _entrance = widget.draft.entranceNodeId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _capacity,
      _company,
      _category,
      _link,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final d = widget.draft
      ..name = _name.text
      ..description = _description.text
      ..capacity = int.tryParse(_capacity.text.trim())
      ..company = _company.text
      ..category = _category.text
      ..link = _link.text
      ..sponsorTier = _tier
      ..poiKind = _poiKind
      ..entranceNodeId = _entrance;
    setState(() => _saving = true);
    try {
      await widget.onSave(d);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final type = widget.draft.type;
    final hasEntrance =
        _entrance != null && widget.graph.nodes.any((n) => n.id == _entrance);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.isNew
                ? l10n.newFeature(typeLabel(l10n, type))
                : l10n.editFeature(widget.draft.name),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            autofocus: widget.isNew,
            decoration: InputDecoration(labelText: l10n.name),
            maxLength: 120,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? l10n.nameRequired : null,
            onFieldSubmitted: (_) => _saving ? null : _save(),
          ),
          if (type == FeatureType.poi)
            DropdownButtonFormField<String>(
              initialValue: _poiKind,
              decoration: InputDecoration(labelText: l10n.poiKind),
              items: [
                for (final k in poiKinds)
                  DropdownMenuItem(
                    value: k,
                    child: Text(poiKindLabel(l10n, k)),
                  ),
              ],
              validator: (v) => v == null ? l10n.poiKind : null,
              onChanged: (v) => setState(() => _poiKind = v),
            ),
          if (type == FeatureType.stand) ...[
            TextFormField(
              controller: _company,
              decoration: InputDecoration(labelText: l10n.company),
              maxLength: 120,
            ),
            TextFormField(
              controller: _category,
              decoration: InputDecoration(labelText: l10n.category),
              maxLength: 120,
            ),
            DropdownButtonFormField<SponsorTier>(
              initialValue: _tier,
              decoration: InputDecoration(labelText: l10n.sponsorTier),
              items: [
                for (final t in SponsorTier.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(sponsorLabel(l10n, t) ?? l10n.sponsorNone),
                  ),
              ],
              onChanged: (v) => setState(() => _tier = v ?? SponsorTier.none),
            ),
          ],
          if (type == FeatureType.room)
            TextFormField(
              controller: _capacity,
              decoration: InputDecoration(labelText: l10n.capacityField),
              keyboardType: TextInputType.number,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                return n == null || n < 0 ? l10n.capacityField : null;
              },
            ),
          if (type != FeatureType.marker) ...[
            TextFormField(
              controller: _description,
              decoration: InputDecoration(labelText: l10n.description),
              maxLines: 3,
              minLines: 1,
              maxLength: 2000,
            ),
            TextFormField(
              controller: _link,
              decoration: InputDecoration(labelText: l10n.website),
              keyboardType: TextInputType.url,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final u = Uri.tryParse(t);
                return u == null ||
                        !(u.isScheme('http') || u.isScheme('https')) ||
                        u.host.isEmpty
                    ? l10n.invalidUrl
                    : null;
              },
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.entrance}: ${hasEntrance ? l10n.entranceSet(_entrance!) : l10n.entranceNone}',
                ),
              ),
              TextButton(
                onPressed: widget.graph.nodes.isEmpty
                    ? null
                    : () => setState(
                        () => _entrance = nearestNode(
                          widget.graph,
                          widget.draft.geometry.center,
                        )?.id,
                      ),
                child: Text(l10n.entranceNearest),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (widget.onDelete != null)
                TextButton.icon(
                  onPressed: _saving ? null : widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.delete),
                ),
              if (widget.onMove != null)
                TextButton.icon(
                  onPressed: _saving ? null : widget.onMove,
                  icon: const Icon(Icons.open_with),
                  label: Text(l10n.move),
                ),
              TextButton(
                onPressed: _saving ? null : widget.onCancel,
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.isNew ? l10n.create : l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
