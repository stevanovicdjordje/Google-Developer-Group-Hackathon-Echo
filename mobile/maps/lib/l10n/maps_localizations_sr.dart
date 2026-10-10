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

  @override
  String get organizerTitle => 'Moji događaji';

  @override
  String get signInTitle => 'Prijava organizatora';

  @override
  String get email => 'Email';

  @override
  String get password => 'Lozinka';

  @override
  String get signIn => 'Prijavi se';

  @override
  String get createAccount => 'Napravi nalog';

  @override
  String get signOut => 'Odjavi se';

  @override
  String signInFailed(String error) {
    return 'Prijava nije uspela: $error';
  }

  @override
  String get newEvent => 'Novi događaj';

  @override
  String get eventName => 'Naziv događaja';

  @override
  String eventDates(String start, String end) {
    return 'Datumi: $start – $end';
  }

  @override
  String get pickDates => 'Izaberi datume';

  @override
  String get create => 'Napravi';

  @override
  String get cancel => 'Otkaži';

  @override
  String get save => 'Sačuvaj';

  @override
  String get delete => 'Obriši';

  @override
  String get noEvents => 'Još nemate nijedan događaj.';

  @override
  String publishedVersion(int version) {
    return 'Objavljeno, verzija $version';
  }

  @override
  String get notPublished => 'Nije objavljeno';

  @override
  String get toolSelect => 'Izaberi';

  @override
  String get toolRoom => 'Sala';

  @override
  String get toolStand => 'Štand';

  @override
  String get toolPoi => 'Mesto';

  @override
  String get toolMarker => 'QR marker';

  @override
  String get toolWalkway => 'Staza';

  @override
  String get hintSelect => 'Dodirnite objekat ili čvor staze da ga izmenite.';

  @override
  String get hintRoom =>
      'Dodirujte uglove sale. 2 tačke = pravougaonik, 3 ili više = mnogougao.';

  @override
  String get hintStand => 'Dodirnite dva suprotna ugla štanda.';

  @override
  String get hintPoi => 'Dodirnite mesto: ulaz, toalet, info pult, hrana…';

  @override
  String get hintMarker => 'Dodirnite gde stoji QR kod „Vi ste ovde“.';

  @override
  String get hintWalkway =>
      'Dodirujte duž hodnika. Dodir na postojeći čvor ga povezuje.';

  @override
  String hintMove(String name) {
    return 'Dodirnite novo mesto za „$name“.';
  }

  @override
  String get finishShape => 'Završi';

  @override
  String get undoPoint => 'Poništi tačku';

  @override
  String get endWalkway => 'Prekini stazu';

  @override
  String get addFloor => 'Dodaj sprat';

  @override
  String get floorName => 'Naziv sprata';

  @override
  String get floorOrder => 'Redosled (0 = prizemlje)';

  @override
  String get pickImage => 'Izaberi sliku plana (PNG/JPEG)';

  @override
  String get imageTooLarge => 'Slika je veća od 10 MB.';

  @override
  String get renameFloor => 'Preimenuj sprat';

  @override
  String get deleteFloor => 'Obriši sprat';

  @override
  String deleteFloorConfirm(String name) {
    return 'Obrisati sprat „$name“ sa svim objektima i stazama?';
  }

  @override
  String get noFloorsYet => 'Dodajte prvi sprat: otpremite sliku plana.';

  @override
  String get publish => 'Objavi';

  @override
  String publishedOk(int version) {
    return 'Objavljeno, verzija $version. Posetioci odmah vide izmene.';
  }

  @override
  String get publishBlocked => 'Objavljivanje nije moguće. Ispravite:';

  @override
  String get publishWarnings => 'Upozorenja (ne sprečavaju objavljivanje):';

  @override
  String get attendeeLink => 'Link za posetioce';

  @override
  String get savingGraph => 'Čuvam stazu…';

  @override
  String graphSaveFailed(String error) {
    return 'Staza nije sačuvana: $error';
  }

  @override
  String saveFailed(String error) {
    return 'Čuvanje nije uspelo: $error';
  }

  @override
  String get name => 'Naziv';

  @override
  String get description => 'Opis';

  @override
  String get capacityField => 'Kapacitet';

  @override
  String get sponsorTier => 'Sponzorstvo';

  @override
  String get sponsorNone => 'Bez sponzorstva';

  @override
  String get poiKind => 'Vrsta mesta';

  @override
  String get entrance => 'Ulaz za rutu';

  @override
  String get entranceNone => 'Nije povezan sa stazom';

  @override
  String entranceSet(String node) {
    return 'Čvor $node';
  }

  @override
  String get entranceNearest => 'Najbliži čvor';

  @override
  String get move => 'Premesti';

  @override
  String newFeature(String kind) {
    return 'Novo: $kind';
  }

  @override
  String editFeature(String name) {
    return 'Izmena: $name';
  }

  @override
  String get nameRequired => 'Unesite naziv';

  @override
  String get invalidUrl => 'Unesite http(s) adresu';

  @override
  String deleteConfirm(String name) {
    return 'Obrisati „$name“?';
  }

  @override
  String get walkwayNode => 'Čvor staze';

  @override
  String nodeEdges(int count) {
    return 'Veza: $count';
  }

  @override
  String get typeMarker => 'QR marker';

  @override
  String get openViewer => 'Pogledaj kao posetilac';

  @override
  String get copied => 'Kopirano';

  @override
  String get reload => 'Osveži';

  @override
  String get issueNoFloors => 'Dodajte bar jedan sprat pre objavljivanja.';

  @override
  String issueInvalidGraph(String floor, String detail) {
    return 'Staza na spratu „$floor“ nije ispravna: $detail';
  }

  @override
  String issueInvalidFeature(String name, String detail) {
    return '„$name“ nije ispravan: $detail';
  }

  @override
  String issueNoEntrance(String name) {
    return '„$name“ nije povezan sa stazom, pa ruta do njega nije moguća.';
  }

  @override
  String issueUnknownEntrance(String name) {
    return '„$name“ kao ulaz koristi obrisan čvor staze. Izaberite ga i kliknite „Najbliži čvor“.';
  }

  @override
  String issueUnreachable(String name) {
    return '„$name“ je na delu staze koji nije povezan sa ostatkom.';
  }
}
