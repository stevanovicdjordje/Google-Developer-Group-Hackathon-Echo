// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'maps_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MapsLocalizationsEn extends MapsLocalizations {
  MapsLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get mapLoading => 'Loading the floor plan…';

  @override
  String get mapNotFound => 'Event not found or not published yet.';

  @override
  String get mapUnavailable =>
      'The server is not reachable right now. Check your connection and try again.';

  @override
  String get mapEmpty => 'The plan has no floors yet.';

  @override
  String get retry => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get searchHint => 'Search stands, rooms, companies…';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filterAll => 'All';

  @override
  String get filterRooms => 'Rooms';

  @override
  String get filterStands => 'Stands';

  @override
  String get filterPois => 'Other';

  @override
  String get typeRoom => 'Room';

  @override
  String get typeStand => 'Stand';

  @override
  String get typePoi => 'Place';

  @override
  String get poiEntrance => 'Entrance';

  @override
  String get poiToilet => 'Toilet';

  @override
  String get poiInfo => 'Info desk';

  @override
  String get poiCloakroom => 'Cloakroom';

  @override
  String get poiFood => 'Food & drinks';

  @override
  String get poiLift => 'Lift';

  @override
  String get poiStairs => 'Stairs';

  @override
  String get sponsorGold => 'Gold sponsor';

  @override
  String get sponsorSilver => 'Silver sponsor';

  @override
  String get sponsorBronze => 'Bronze sponsor';

  @override
  String capacity(int count) {
    return 'Capacity: $count';
  }

  @override
  String get company => 'Company';

  @override
  String get category => 'Category';

  @override
  String get website => 'Website';

  @override
  String get floor => 'Floor';

  @override
  String get legend => 'Legend';

  @override
  String get fitPlan => 'Show whole plan';

  @override
  String onFloor(String floor) {
    return 'Floor: $floor';
  }
}
