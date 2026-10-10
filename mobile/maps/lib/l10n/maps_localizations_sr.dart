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

  @override
  String get showRoute => 'Prikaži put';

  @override
  String get routeFromTitle => 'Odakle krećete?';

  @override
  String get routePickOnMap => 'Izaberite na mapi';

  @override
  String get routePickHint => 'Dodirnite mesto na mapi gde se nalazite';

  @override
  String get youAreHere => 'Vi ste ovde';

  @override
  String routeTo(String name) {
    return 'Do: $name';
  }

  @override
  String routeSummary(int meters, int minutes) {
    return '$meters m · $minutes min';
  }

  @override
  String get routeEstimated => 'procena';

  @override
  String get routeNoStairs => 'Bez stepenica';

  @override
  String get routeLoading => 'Tražim put…';

  @override
  String get routeNoRoute => 'Do ovog mesta nema puta na mapi.';

  @override
  String get routeFailed =>
      'Put trenutno nije moguće izračunati. Proverite vezu.';

  @override
  String routeByLift(String floor) {
    return 'Idite liftom na sprat $floor';
  }

  @override
  String routeByStairs(String floor) {
    return 'Idite stepenicama na sprat $floor';
  }

  @override
  String routeContinue(String floor) {
    return 'Nastavite na sprat $floor';
  }

  @override
  String routeStartsOn(String floor) {
    return 'Put počinje na spratu $floor';
  }

  @override
  String get routeShowFloor => 'Prikaži';

  @override
  String get closeRoute => 'Zatvori put';

  @override
  String get routeAlreadyHere => 'Već ste ovde.';

  @override
  String get gpsMyLocation => 'Moja lokacija';

  @override
  String get gpsSearching => 'Tražim GPS signal…';

  @override
  String gpsWeak(int meters) {
    return 'GPS je neprecizan (±$meters m). Skenirajte QR kod ili izaberite mesto na mapi.';
  }

  @override
  String get gpsOutside => 'Izgleda da niste u objektu.';

  @override
  String get gpsNoGeoref => 'Za ovaj sprat GPS nije podešen.';

  @override
  String get gpsDenied =>
      'Lokacija nije dozvoljena. Skenirajte QR kod ili izaberite mesto na mapi.';

  @override
  String get gpsServiceOff => 'Lokacija je isključena na uređaju.';

  @override
  String get gpsFailed => 'Lokacija trenutno nije dostupna.';

  @override
  String arrived(String name) {
    return 'Stigli ste: $name';
  }

  @override
  String get georefMenu => 'Podesi GPS (georeferenciranje)';

  @override
  String get georefMenuSet => 'GPS je podešen: izmeni';

  @override
  String georefTitle(String floor) {
    return 'GPS za sprat „$floor“';
  }

  @override
  String get georefIntro =>
      'Izaberite 3 mesta koja lako nađete i na planu i na Google mapama (uglovi zgrade, ulazi), što dalje jedno od drugog. Za svako: dodirnite plan, pa nalepite koordinate (u Google mapama: desni klik na mesto → kliknite na koordinate).';

  @override
  String georefPoint(int n) {
    return 'Tačka $n';
  }

  @override
  String get georefTapPlan => 'Dodirnite plan';

  @override
  String get georefCoordsHint => 'npr. 44.81234, 20.46123';

  @override
  String get georefCoordsInvalid => 'Unesite „širina, dužina“';

  @override
  String georefScale(String cm, String meters) {
    return 'Razmera: $cm cm po pikselu · moguća greška ±$meters m';
  }

  @override
  String get georefDegenerate =>
      'Tačke su na jednoj liniji ili preblizu. Izaberite mesta dalje jedno od drugog.';

  @override
  String get georefBadPoint =>
      'Moguća greška je velika: neka tačka je verovatno pogrešno postavljena.';

  @override
  String get georefRemove => 'Ukloni GPS';

  @override
  String get georefSaved =>
      'GPS je podešen. Posetioci ga dobijaju posle objave.';

  @override
  String get georefRemoved => 'GPS je uklonjen.';

  @override
  String get statsOpen => 'Statistika';

  @override
  String get statsTitle => 'Statistika mape';

  @override
  String get statsRangeToday => 'Danas';

  @override
  String get statsRange7 => '7 dana';

  @override
  String get statsRange30 => '30 dana';

  @override
  String get statsRangeEvent => 'Tokom događaja';

  @override
  String get statsSearches => 'Pretrage';

  @override
  String get statsNoResults => 'Bez rezultata';

  @override
  String get statsFeatureViews => 'Otvoreni detalji';

  @override
  String get statsRoutes => 'Tražene rute';

  @override
  String get statsQrScans => 'QR skeniranja';

  @override
  String get statsPerDay => 'Aktivnost po danu';

  @override
  String get statsPerDayHint =>
      'Pretrage, otvoreni detalji, rute i QR skeniranja zajedno';

  @override
  String statsDayTooltip(String date, int count) {
    return '$date: $count';
  }

  @override
  String get statsNotFound => 'Traže, a ne nalaze';

  @override
  String get statsNotFoundHint =>
      'Pretrage bez ijednog rezultata. Možda na planu fali mesto, naziv ili kategorija.';

  @override
  String get statsTopSearches => 'Najčešće pretrage';

  @override
  String get statsTopFeatures => 'Najčešće otvarano';

  @override
  String get statsTopRoutes => 'Najčešći ciljevi ruta';

  @override
  String get statsQrList => 'Skeniranja po QR markeru';

  @override
  String get statsRemoved => '(uklonjeno sa plana)';

  @override
  String get statsEmpty =>
      'Još nema podataka za ovaj period. Brojke stižu kad posetioci koriste mapu, uz kašnjenje do 10 sekundi.';

  @override
  String get statsError => 'Statistika trenutno nije dostupna.';

  @override
  String get statsPrivacy =>
      'Samo zbirni brojevi po danu. Bez lokacija i bez podataka o osobama.';

  @override
  String get qrOpen => 'QR oznake za štampu';

  @override
  String get qrTitle => 'QR oznake';

  @override
  String get qrIntro =>
      'Odštampajte i postavite svaku oznaku na mesto koje ste označili na planu. Posetilac skenira kod i odmah vidi gde je i put do štanda ili sale.';

  @override
  String get qrNotPublished =>
      'Događaj još nije objavljen. Kodovi rade tek kad objavite mapu.';

  @override
  String get qrPublishFirst =>
      'Nova ili pomerena oznaka radi tek posle objave.';

  @override
  String get qrNone =>
      'Još nema QR oznaka. Dodajte ih alatom „QR marker“ na planu, pa objavite.';

  @override
  String get qrPrint => 'Štampaj';

  @override
  String get qrScanHint =>
      'Skenirajte kamerom telefona: plan objekta i put do štanda ili sale.';

  @override
  String get qrPopupBlocked =>
      'Pregledač je blokirao novu karticu. Dozvolite iskačuće prozore za ovu stranicu.';

  @override
  String get qrCopy => 'Kopiraj link';

  @override
  String get qrCopied => 'Link je kopiran.';

  @override
  String get qrLoadFailed => 'Oznake trenutno nije moguće učitati.';
}
