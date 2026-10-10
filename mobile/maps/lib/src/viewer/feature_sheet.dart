import 'package:flutter/material.dart';

import '../../l10n/maps_localizations.dart';
import '../model/map_models.dart';
import 'labels.dart';

/// Details of a room, stand or POI, shown in a bottom sheet.
class FeatureDetails extends StatelessWidget {
  const FeatureDetails({
    super.key,
    required this.feature,
    this.floorName,
    this.onRoute,
  });

  final Feature feature;
  final String? floorName;

  /// "Prikaži put"; hidden when null.
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final theme = Theme.of(context);
    final f = feature;
    final sponsor = sponsorLabel(l10n, f.sponsorTier);
    final tierColor = MapPalette.of(context).tierColor(f.sponsorTier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  featureIcon(f),
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(f.name, style: theme.textTheme.headlineSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(kindLabel(l10n, f))),
                if (sponsor != null)
                  Chip(
                    avatar: Icon(Icons.workspace_premium, color: tierColor),
                    label: Text(sponsor),
                    side: BorderSide(
                      color: tierColor ?? theme.dividerColor,
                      width: 2,
                    ),
                  ),
                if (floorName != null)
                  Chip(label: Text(l10n.onFloor(floorName!))),
              ],
            ),
            if (f.company.isNotEmpty)
              _Row(label: l10n.company, value: f.company),
            if (f.category.isNotEmpty)
              _Row(label: l10n.category, value: f.category),
            if (f.capacity != null && f.capacity! > 0)
              _Row(value: l10n.capacity(f.capacity!)),
            if (f.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(f.description, style: theme.textTheme.bodyLarge),
            ],
            if (f.link != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                '${l10n.website}: ${f.link}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (onRoute != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRoute,
                  icon: const Icon(Icons.directions_walk),
                  label: Text(l10n.showRoute),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({this.label, required this.value});

  final String? label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        TextSpan(
          children: [
            if (label != null)
              TextSpan(
                text: '$label: ',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            TextSpan(text: value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
