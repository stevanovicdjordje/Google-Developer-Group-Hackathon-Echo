import 'package:flutter/material.dart';

import '../../l10n/maps_localizations.dart';
import '../model/map_models.dart';

/// Localized label of a feature's kind ("Štand", "Toalet", …).
String kindLabel(MapsLocalizations l10n, Feature f) => switch (f.type) {
  FeatureType.room => l10n.typeRoom,
  FeatureType.stand => l10n.typeStand,
  FeatureType.marker => '',
  FeatureType.poi => switch (f.poiKind) {
    'entrance' => l10n.poiEntrance,
    'toilet' => l10n.poiToilet,
    'info' => l10n.poiInfo,
    'cloakroom' => l10n.poiCloakroom,
    'food' => l10n.poiFood,
    'lift' => l10n.poiLift,
    'stairs' => l10n.poiStairs,
    _ => l10n.typePoi,
  },
};

String? sponsorLabel(MapsLocalizations l10n, SponsorTier t) => switch (t) {
  SponsorTier.gold => l10n.sponsorGold,
  SponsorTier.silver => l10n.sponsorSilver,
  SponsorTier.bronze => l10n.sponsorBronze,
  SponsorTier.none => null,
};

IconData featureIcon(Feature f) => switch (f.type) {
  FeatureType.room => Icons.meeting_room_outlined,
  FeatureType.stand => Icons.storefront_outlined,
  FeatureType.marker => Icons.qr_code_2,
  FeatureType.poi => switch (f.poiKind) {
    'entrance' => Icons.login,
    'toilet' => Icons.wc,
    'info' => Icons.info_outline,
    'cloakroom' => Icons.checkroom,
    'food' => Icons.restaurant,
    'lift' => Icons.elevator_outlined,
    'stairs' => Icons.stairs_outlined,
    _ => Icons.place_outlined,
  },
};

/// Map colors, derived from the theme so light and dark both stay readable.
class MapPalette {
  MapPalette.of(BuildContext context) : scheme = Theme.of(context).colorScheme;

  final ColorScheme scheme;

  static const gold = Color(0xFFD4A017);
  static const silver = Color(0xFF8E9AA6);
  static const bronze = Color(0xFFB0703C);

  Color get room => const Color(0xFF4A90D9);
  Color get stand => const Color(0xFFF2994A);
  Color get selected => scheme.primary;
  Color get labelBackground => scheme.surface.withValues(alpha: 0.85);
  Color get labelText => scheme.onSurface;
  Color get route => const Color(0xFF1E6FE0);
  Color get onRoute => Colors.white;

  Color? tierColor(SponsorTier t) => switch (t) {
    SponsorTier.gold => gold,
    SponsorTier.silver => silver,
    SponsorTier.bronze => bronze,
    SponsorTier.none => null,
  };
}
