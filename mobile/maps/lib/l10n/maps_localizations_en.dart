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

  @override
  String get organizerTitle => 'My events';

  @override
  String get signInTitle => 'Organizer sign-in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String signInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get newEvent => 'New event';

  @override
  String get eventName => 'Event name';

  @override
  String eventDates(String start, String end) {
    return 'Dates: $start – $end';
  }

  @override
  String get pickDates => 'Pick dates';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get noEvents => 'You don\'t have any events yet.';

  @override
  String publishedVersion(int version) {
    return 'Published, version $version';
  }

  @override
  String get notPublished => 'Not published';

  @override
  String get toolSelect => 'Select';

  @override
  String get toolRoom => 'Room';

  @override
  String get toolStand => 'Stand';

  @override
  String get toolPoi => 'Place';

  @override
  String get toolMarker => 'QR marker';

  @override
  String get toolWalkway => 'Walkway';

  @override
  String get hintSelect => 'Tap an object or a walkway node to edit it.';

  @override
  String get hintRoom =>
      'Tap the room\'s corners. 2 points = rectangle, 3 or more = polygon.';

  @override
  String get hintStand => 'Tap two opposite corners of the stand.';

  @override
  String get hintPoi => 'Tap a place: entrance, toilet, info desk, food…';

  @override
  String get hintMarker => 'Tap where the \"You are here\" QR code hangs.';

  @override
  String get hintWalkway =>
      'Tap along the corridors. Tapping an existing node connects to it.';

  @override
  String hintMove(String name) {
    return 'Tap the new position for \"$name\".';
  }

  @override
  String get finishShape => 'Finish';

  @override
  String get undoPoint => 'Undo point';

  @override
  String get endWalkway => 'End walkway';

  @override
  String get addFloor => 'Add floor';

  @override
  String get floorName => 'Floor name';

  @override
  String get floorOrder => 'Order (0 = ground floor)';

  @override
  String get pickImage => 'Choose the plan image (PNG/JPEG)';

  @override
  String get imageTooLarge => 'The image is larger than 10 MB.';

  @override
  String get renameFloor => 'Rename floor';

  @override
  String get deleteFloor => 'Delete floor';

  @override
  String deleteFloorConfirm(String name) {
    return 'Delete floor \"$name\" with all its objects and walkways?';
  }

  @override
  String get noFloorsYet => 'Add the first floor: upload the plan image.';

  @override
  String get publish => 'Publish';

  @override
  String publishedOk(int version) {
    return 'Published, version $version. Attendees see the changes right away.';
  }

  @override
  String get publishBlocked => 'Can\'t publish yet. Fix:';

  @override
  String get publishWarnings => 'Warnings (don\'t block publishing):';

  @override
  String get attendeeLink => 'Attendee link';

  @override
  String get savingGraph => 'Saving walkway…';

  @override
  String graphSaveFailed(String error) {
    return 'Walkway not saved: $error';
  }

  @override
  String saveFailed(String error) {
    return 'Saving failed: $error';
  }

  @override
  String get name => 'Name';

  @override
  String get description => 'Description';

  @override
  String get capacityField => 'Capacity';

  @override
  String get sponsorTier => 'Sponsorship';

  @override
  String get sponsorNone => 'No sponsorship';

  @override
  String get poiKind => 'Kind of place';

  @override
  String get entrance => 'Route entrance';

  @override
  String get entranceNone => 'Not connected to a walkway';

  @override
  String entranceSet(String node) {
    return 'Node $node';
  }

  @override
  String get entranceNearest => 'Nearest node';

  @override
  String get move => 'Move';

  @override
  String newFeature(String kind) {
    return 'New: $kind';
  }

  @override
  String editFeature(String name) {
    return 'Edit: $name';
  }

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get invalidUrl => 'Enter an http(s) address';

  @override
  String deleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get walkwayNode => 'Walkway node';

  @override
  String nodeEdges(int count) {
    return 'Connections: $count';
  }

  @override
  String get typeMarker => 'QR marker';

  @override
  String get openViewer => 'View as attendee';

  @override
  String get copied => 'Copied';

  @override
  String get reload => 'Reload';

  @override
  String get issueNoFloors => 'Add at least one floor before publishing.';

  @override
  String issueInvalidGraph(String floor, String detail) {
    return 'The walkway on floor \"$floor\" is invalid: $detail';
  }

  @override
  String issueInvalidFeature(String name, String detail) {
    return '\"$name\" is invalid: $detail';
  }

  @override
  String issueNoEntrance(String name) {
    return '\"$name\" isn\'t connected to a walkway, so it can\'t be routed to.';
  }

  @override
  String issueUnknownEntrance(String name) {
    return '\"$name\" uses a deleted walkway node as its entrance. Select it and click \"Nearest node\".';
  }

  @override
  String issueUnreachable(String name) {
    return '\"$name\" is on a part of the walkway that isn\'t connected to the rest.';
  }

  @override
  String get showRoute => 'Show the way';

  @override
  String get routeFromTitle => 'Where are you starting from?';

  @override
  String get routePickOnMap => 'Pick on the map';

  @override
  String get routePickHint => 'Tap the spot on the map where you are';

  @override
  String get youAreHere => 'You are here';

  @override
  String routeTo(String name) {
    return 'To: $name';
  }

  @override
  String routeSummary(int meters, int minutes) {
    return '$meters m · $minutes min';
  }

  @override
  String get routeEstimated => 'estimate';

  @override
  String get routeNoStairs => 'No stairs';

  @override
  String get routeLoading => 'Finding the way…';

  @override
  String get routeNoRoute => 'There\'s no way to this place on the map.';

  @override
  String get routeFailed =>
      'Couldn\'t find the way right now. Check your connection.';

  @override
  String routeByLift(String floor) {
    return 'Take the lift to $floor';
  }

  @override
  String routeByStairs(String floor) {
    return 'Take the stairs to $floor';
  }

  @override
  String routeContinue(String floor) {
    return 'Continue to $floor';
  }

  @override
  String routeStartsOn(String floor) {
    return 'The way starts on $floor';
  }

  @override
  String get routeShowFloor => 'Show';

  @override
  String get closeRoute => 'Close the way';

  @override
  String get routeAlreadyHere => 'You\'re already here.';

  @override
  String get gpsMyLocation => 'My location';

  @override
  String get gpsSearching => 'Looking for a GPS signal…';

  @override
  String gpsWeak(int meters) {
    return 'GPS is imprecise (±$meters m). Scan a QR code or pick your spot on the map.';
  }

  @override
  String get gpsOutside => 'You don\'t seem to be at the venue.';

  @override
  String get gpsNoGeoref => 'GPS isn\'t set up for this floor.';

  @override
  String get gpsDenied =>
      'Location isn\'t allowed. Scan a QR code or pick your spot on the map.';

  @override
  String get gpsServiceOff => 'Location is turned off on this device.';

  @override
  String get gpsFailed => 'Location isn\'t available right now.';

  @override
  String arrived(String name) {
    return 'You\'ve arrived: $name';
  }

  @override
  String get georefMenu => 'Set up GPS (georeferencing)';

  @override
  String get georefMenuSet => 'GPS is set up: edit';

  @override
  String georefTitle(String floor) {
    return 'GPS for floor \"$floor\"';
  }

  @override
  String get georefIntro =>
      'Pick 3 spots you can find both on the plan and on Google Maps (building corners, entrances), as far apart as possible. For each: tap the plan, then paste the coordinates (in Google Maps: right-click the spot → click the coordinates).';

  @override
  String georefPoint(int n) {
    return 'Point $n';
  }

  @override
  String get georefTapPlan => 'Tap the plan';

  @override
  String get georefCoordsHint => 'e.g. 44.81234, 20.46123';

  @override
  String get georefCoordsInvalid => 'Enter \"latitude, longitude\"';

  @override
  String georefScale(String cm, String meters) {
    return 'Scale: $cm cm per pixel · possible error ±$meters m';
  }

  @override
  String get georefDegenerate =>
      'The points are on one line or too close. Pick spots further apart.';

  @override
  String get georefBadPoint =>
      'The possible error is large: a point is probably misplaced.';

  @override
  String get georefRemove => 'Remove GPS';

  @override
  String get georefSaved =>
      'GPS is set up. Attendees get it after you publish.';

  @override
  String get georefRemoved => 'GPS removed.';

  @override
  String get statsOpen => 'Stats';

  @override
  String get statsTitle => 'Map stats';

  @override
  String get statsRangeToday => 'Today';

  @override
  String get statsRange7 => '7 days';

  @override
  String get statsRange30 => '30 days';

  @override
  String get statsRangeEvent => 'Event dates';

  @override
  String get statsSearches => 'Searches';

  @override
  String get statsNoResults => 'No results';

  @override
  String get statsFeatureViews => 'Details opened';

  @override
  String get statsRoutes => 'Routes asked';

  @override
  String get statsQrScans => 'QR scans';

  @override
  String get statsPerDay => 'Activity per day';

  @override
  String get statsPerDayHint =>
      'Searches, opened details, routes and QR scans together';

  @override
  String statsDayTooltip(String date, int count) {
    return '$date: $count';
  }

  @override
  String get statsNotFound => 'Looked for, not found';

  @override
  String get statsNotFoundHint =>
      'Searches without a single result. A place, name or category may be missing from the plan.';

  @override
  String get statsTopSearches => 'Top searches';

  @override
  String get statsTopFeatures => 'Most opened';

  @override
  String get statsTopRoutes => 'Top route targets';

  @override
  String get statsQrList => 'Scans per QR marker';

  @override
  String get statsRemoved => '(removed from the plan)';

  @override
  String get statsEmpty =>
      'No data for this period yet. Numbers arrive as attendees use the map, up to 10 seconds later.';

  @override
  String get statsError => 'Stats are not available right now.';

  @override
  String get statsPrivacy =>
      'Daily totals only. No locations and no data about people.';
}
