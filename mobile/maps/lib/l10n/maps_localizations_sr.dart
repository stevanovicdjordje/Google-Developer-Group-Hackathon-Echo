// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'maps_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class MapsLocalizationsSr extends MapsLocalizations {
  MapsLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get mapLoading => 'Učitavam plan…';

  @override
  String get mapNotFound => 'Događaj nije pronađen ili još nije objavljen.';

  @override
  String get mapUnavailable =>
      'Server trenutno nije dostupan. Proverite internet vezu i pokušajte ponovo.';

  @override
  String get mapEmpty => 'Plan još nema nijedan sprat.';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String get close => 'Zatvori';

  @override
  String get searchHint => 'Pretraži štandove, sale, kompanije…';

  @override
  String searchNoResults(String query) {
    return 'Nema rezultata za „$query“';
  }

  @override
  String get clearSearch => 'Obriši pretragu';

  @override
  String get filterAll => 'Sve';

  @override
  String get filterRooms => 'Sale';

  @override
  String get filterStands => 'Štandovi';

  @override
  String get filterPois => 'Ostalo';

  @override
  String get typeRoom => 'Sala';

  @override
  String get typeStand => 'Štand';

  @override
  String get typePoi => 'Mesto';

  @override
  String get poiEntrance => 'Ulaz';

  @override
  String get poiToilet => 'Toalet';

  @override
  String get poiInfo => 'Info pult';

  @override
  String get poiCloakroom => 'Garderoba';

  @override
  String get poiFood => 'Hrana i piće';

  @override
  String get poiLift => 'Lift';

  @override
  String get poiStairs => 'Stepenice';

  @override
  String get sponsorGold => 'Zlatni sponzor';

  @override
  String get sponsorSilver => 'Srebrni sponzor';

  @override
  String get sponsorBronze => 'Bronzani sponzor';

  @override
  String capacity(int count) {
    return 'Kapacitet: $count';
  }

  @override
  String get company => 'Kompanija';

  @override
  String get category => 'Kategorija';

  @override
  String get website => 'Sajt';

  @override
  String get floor => 'Sprat';

  @override
  String get legend => 'Legenda';

  @override
  String get fitPlan => 'Prikaži ceo plan';

  @override
  String onFloor(String floor) {
    return 'Sprat: $floor';
  }
}
