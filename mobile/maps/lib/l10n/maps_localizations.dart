import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'maps_localizations_en.dart';
import 'maps_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MapsLocalizations
/// returned by `MapsLocalizations.of(context)`.
///
/// Applications need to include `MapsLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/maps_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MapsLocalizations.localizationsDelegates,
///   supportedLocales: MapsLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MapsLocalizations.supportedLocales
/// property.
abstract class MapsLocalizations {
  MapsLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MapsLocalizations of(BuildContext context) {
    return Localizations.of<MapsLocalizations>(context, MapsLocalizations)!;
  }

  static const LocalizationsDelegate<MapsLocalizations> delegate =
      _MapsLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sr'),
  ];

  /// No description provided for @mapLoading.
  ///
  /// In sr, this message translates to:
  /// **'Učitavam plan…'**
  String get mapLoading;

  /// No description provided for @mapNotFound.
  ///
  /// In sr, this message translates to:
  /// **'Događaj nije pronađen ili još nije objavljen.'**
  String get mapNotFound;

  /// No description provided for @mapUnavailable.
  ///
  /// In sr, this message translates to:
  /// **'Server trenutno nije dostupan. Proverite internet vezu i pokušajte ponovo.'**
  String get mapUnavailable;

  /// No description provided for @mapEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Plan još nema nijedan sprat.'**
  String get mapEmpty;

  /// No description provided for @retry.
  ///
  /// In sr, this message translates to:
  /// **'Pokušaj ponovo'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In sr, this message translates to:
  /// **'Zatvori'**
  String get close;

  /// No description provided for @searchHint.
  ///
  /// In sr, this message translates to:
  /// **'Pretraži štandove, sale, kompanije…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In sr, this message translates to:
  /// **'Nema rezultata za „{query}“'**
  String searchNoResults(String query);

  /// No description provided for @clearSearch.
  ///
  /// In sr, this message translates to:
  /// **'Obriši pretragu'**
  String get clearSearch;

  /// No description provided for @filterAll.
  ///
  /// In sr, this message translates to:
  /// **'Sve'**
  String get filterAll;

  /// No description provided for @filterRooms.
  ///
  /// In sr, this message translates to:
  /// **'Sale'**
  String get filterRooms;

  /// No description provided for @filterStands.
  ///
  /// In sr, this message translates to:
  /// **'Štandovi'**
  String get filterStands;

  /// No description provided for @filterPois.
  ///
  /// In sr, this message translates to:
  /// **'Ostalo'**
  String get filterPois;

  /// No description provided for @typeRoom.
  ///
  /// In sr, this message translates to:
  /// **'Sala'**
  String get typeRoom;

  /// No description provided for @typeStand.
  ///
  /// In sr, this message translates to:
  /// **'Štand'**
  String get typeStand;

  /// No description provided for @typePoi.
  ///
  /// In sr, this message translates to:
  /// **'Mesto'**
  String get typePoi;

  /// No description provided for @poiEntrance.
  ///
  /// In sr, this message translates to:
  /// **'Ulaz'**
  String get poiEntrance;

  /// No description provided for @poiToilet.
  ///
  /// In sr, this message translates to:
  /// **'Toalet'**
  String get poiToilet;

  /// No description provided for @poiInfo.
  ///
  /// In sr, this message translates to:
  /// **'Info pult'**
  String get poiInfo;

  /// No description provided for @poiCloakroom.
  ///
  /// In sr, this message translates to:
  /// **'Garderoba'**
  String get poiCloakroom;

  /// No description provided for @poiFood.
  ///
  /// In sr, this message translates to:
  /// **'Hrana i piće'**
  String get poiFood;

  /// No description provided for @poiLift.
  ///
  /// In sr, this message translates to:
  /// **'Lift'**
  String get poiLift;

  /// No description provided for @poiStairs.
  ///
  /// In sr, this message translates to:
  /// **'Stepenice'**
  String get poiStairs;

  /// No description provided for @sponsorGold.
  ///
  /// In sr, this message translates to:
  /// **'Zlatni sponzor'**
  String get sponsorGold;

  /// No description provided for @sponsorSilver.
  ///
  /// In sr, this message translates to:
  /// **'Srebrni sponzor'**
  String get sponsorSilver;

  /// No description provided for @sponsorBronze.
  ///
  /// In sr, this message translates to:
  /// **'Bronzani sponzor'**
  String get sponsorBronze;

  /// No description provided for @capacity.
  ///
  /// In sr, this message translates to:
  /// **'Kapacitet: {count}'**
  String capacity(int count);

  /// No description provided for @company.
  ///
  /// In sr, this message translates to:
  /// **'Kompanija'**
  String get company;

  /// No description provided for @category.
  ///
  /// In sr, this message translates to:
  /// **'Kategorija'**
  String get category;

  /// No description provided for @website.
  ///
  /// In sr, this message translates to:
  /// **'Sajt'**
  String get website;

  /// No description provided for @floor.
  ///
  /// In sr, this message translates to:
  /// **'Sprat'**
  String get floor;

  /// No description provided for @legend.
  ///
  /// In sr, this message translates to:
  /// **'Legenda'**
  String get legend;

  /// No description provided for @fitPlan.
  ///
  /// In sr, this message translates to:
  /// **'Prikaži ceo plan'**
  String get fitPlan;

  /// No description provided for @onFloor.
  ///
  /// In sr, this message translates to:
  /// **'Sprat: {floor}'**
  String onFloor(String floor);

  /// No description provided for @organizerTitle.
  ///
  /// In sr, this message translates to:
  /// **'Moji događaji'**
  String get organizerTitle;

  /// No description provided for @signInTitle.
  ///
  /// In sr, this message translates to:
  /// **'Prijava organizatora'**
  String get signInTitle;

  /// No description provided for @email.
  ///
  /// In sr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In sr, this message translates to:
  /// **'Lozinka'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In sr, this message translates to:
  /// **'Prijavi se'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In sr, this message translates to:
  /// **'Napravi nalog'**
  String get createAccount;

  /// No description provided for @signOut.
  ///
  /// In sr, this message translates to:
  /// **'Odjavi se'**
  String get signOut;

  /// No description provided for @signInFailed.
  ///
  /// In sr, this message translates to:
  /// **'Prijava nije uspela: {error}'**
  String signInFailed(String error);

  /// No description provided for @newEvent.
  ///
  /// In sr, this message translates to:
  /// **'Novi događaj'**
  String get newEvent;

  /// No description provided for @eventName.
  ///
  /// In sr, this message translates to:
  /// **'Naziv događaja'**
  String get eventName;

  /// No description provided for @eventDates.
  ///
  /// In sr, this message translates to:
  /// **'Datumi: {start} – {end}'**
  String eventDates(String start, String end);

  /// No description provided for @pickDates.
  ///
  /// In sr, this message translates to:
  /// **'Izaberi datume'**
  String get pickDates;

  /// No description provided for @create.
  ///
  /// In sr, this message translates to:
  /// **'Napravi'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In sr, this message translates to:
  /// **'Otkaži'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In sr, this message translates to:
  /// **'Sačuvaj'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In sr, this message translates to:
  /// **'Obriši'**
  String get delete;

  /// No description provided for @noEvents.
  ///
  /// In sr, this message translates to:
  /// **'Još nemate nijedan događaj.'**
  String get noEvents;

  /// No description provided for @publishedVersion.
  ///
  /// In sr, this message translates to:
  /// **'Objavljeno, verzija {version}'**
  String publishedVersion(int version);

  /// No description provided for @notPublished.
  ///
  /// In sr, this message translates to:
  /// **'Nije objavljeno'**
  String get notPublished;

  /// No description provided for @toolSelect.
  ///
  /// In sr, this message translates to:
  /// **'Izaberi'**
  String get toolSelect;

  /// No description provided for @toolRoom.
  ///
  /// In sr, this message translates to:
  /// **'Sala'**
  String get toolRoom;

  /// No description provided for @toolStand.
  ///
  /// In sr, this message translates to:
  /// **'Štand'**
  String get toolStand;

  /// No description provided for @toolPoi.
  ///
  /// In sr, this message translates to:
  /// **'Mesto'**
  String get toolPoi;

  /// No description provided for @toolMarker.
  ///
  /// In sr, this message translates to:
  /// **'QR marker'**
  String get toolMarker;

  /// No description provided for @toolWalkway.
  ///
  /// In sr, this message translates to:
  /// **'Staza'**
  String get toolWalkway;

  /// No description provided for @hintSelect.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite objekat ili čvor staze da ga izmenite.'**
  String get hintSelect;

  /// No description provided for @hintRoom.
  ///
  /// In sr, this message translates to:
  /// **'Dodirujte uglove sale. 2 tačke = pravougaonik, 3 ili više = mnogougao.'**
  String get hintRoom;

  /// No description provided for @hintStand.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite dva suprotna ugla štanda.'**
  String get hintStand;

  /// No description provided for @hintPoi.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite mesto: ulaz, toalet, info pult, hrana…'**
  String get hintPoi;

  /// No description provided for @hintMarker.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite gde stoji QR kod „Vi ste ovde“.'**
  String get hintMarker;

  /// No description provided for @hintWalkway.
  ///
  /// In sr, this message translates to:
  /// **'Dodirujte duž hodnika. Dodir na postojeći čvor ga povezuje.'**
  String get hintWalkway;

  /// No description provided for @hintMove.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite novo mesto za „{name}“.'**
  String hintMove(String name);

  /// No description provided for @finishShape.
  ///
  /// In sr, this message translates to:
  /// **'Završi'**
  String get finishShape;

  /// No description provided for @undoPoint.
  ///
  /// In sr, this message translates to:
  /// **'Poništi tačku'**
  String get undoPoint;

  /// No description provided for @endWalkway.
  ///
  /// In sr, this message translates to:
  /// **'Prekini stazu'**
  String get endWalkway;

  /// No description provided for @addFloor.
  ///
  /// In sr, this message translates to:
  /// **'Dodaj sprat'**
  String get addFloor;

  /// No description provided for @floorName.
  ///
  /// In sr, this message translates to:
  /// **'Naziv sprata'**
  String get floorName;

  /// No description provided for @floorOrder.
  ///
  /// In sr, this message translates to:
  /// **'Redosled (0 = prizemlje)'**
  String get floorOrder;

  /// No description provided for @pickImage.
  ///
  /// In sr, this message translates to:
  /// **'Izaberi sliku plana (PNG/JPEG)'**
  String get pickImage;

  /// No description provided for @imageTooLarge.
  ///
  /// In sr, this message translates to:
  /// **'Slika je veća od 10 MB.'**
  String get imageTooLarge;

  /// No description provided for @renameFloor.
  ///
  /// In sr, this message translates to:
  /// **'Preimenuj sprat'**
  String get renameFloor;

  /// No description provided for @deleteFloor.
  ///
  /// In sr, this message translates to:
  /// **'Obriši sprat'**
  String get deleteFloor;

  /// No description provided for @deleteFloorConfirm.
  ///
  /// In sr, this message translates to:
  /// **'Obrisati sprat „{name}“ sa svim objektima i stazama?'**
  String deleteFloorConfirm(String name);

  /// No description provided for @noFloorsYet.
  ///
  /// In sr, this message translates to:
  /// **'Dodajte prvi sprat: otpremite sliku plana.'**
  String get noFloorsYet;

  /// No description provided for @publish.
  ///
  /// In sr, this message translates to:
  /// **'Objavi'**
  String get publish;

  /// No description provided for @publishedOk.
  ///
  /// In sr, this message translates to:
  /// **'Objavljeno, verzija {version}. Posetioci odmah vide izmene.'**
  String publishedOk(int version);

  /// No description provided for @publishBlocked.
  ///
  /// In sr, this message translates to:
  /// **'Objavljivanje nije moguće. Ispravite:'**
  String get publishBlocked;

  /// No description provided for @publishWarnings.
  ///
  /// In sr, this message translates to:
  /// **'Upozorenja (ne sprečavaju objavljivanje):'**
  String get publishWarnings;

  /// No description provided for @attendeeLink.
  ///
  /// In sr, this message translates to:
  /// **'Link za posetioce'**
  String get attendeeLink;

  /// No description provided for @savingGraph.
  ///
  /// In sr, this message translates to:
  /// **'Čuvam stazu…'**
  String get savingGraph;

  /// No description provided for @graphSaveFailed.
  ///
  /// In sr, this message translates to:
  /// **'Staza nije sačuvana: {error}'**
  String graphSaveFailed(String error);

  /// No description provided for @saveFailed.
  ///
  /// In sr, this message translates to:
  /// **'Čuvanje nije uspelo: {error}'**
  String saveFailed(String error);

  /// No description provided for @name.
  ///
  /// In sr, this message translates to:
  /// **'Naziv'**
  String get name;

  /// No description provided for @description.
  ///
  /// In sr, this message translates to:
  /// **'Opis'**
  String get description;

  /// No description provided for @capacityField.
  ///
  /// In sr, this message translates to:
  /// **'Kapacitet'**
  String get capacityField;

  /// No description provided for @sponsorTier.
  ///
  /// In sr, this message translates to:
  /// **'Sponzorstvo'**
  String get sponsorTier;

  /// No description provided for @sponsorNone.
  ///
  /// In sr, this message translates to:
  /// **'Bez sponzorstva'**
  String get sponsorNone;

  /// No description provided for @poiKind.
  ///
  /// In sr, this message translates to:
  /// **'Vrsta mesta'**
  String get poiKind;

  /// No description provided for @entrance.
  ///
  /// In sr, this message translates to:
  /// **'Ulaz za rutu'**
  String get entrance;

  /// No description provided for @entranceNone.
  ///
  /// In sr, this message translates to:
  /// **'Nije povezan sa stazom'**
  String get entranceNone;

  /// No description provided for @entranceSet.
  ///
  /// In sr, this message translates to:
  /// **'Čvor {node}'**
  String entranceSet(String node);

  /// No description provided for @entranceNearest.
  ///
  /// In sr, this message translates to:
  /// **'Najbliži čvor'**
  String get entranceNearest;

  /// No description provided for @move.
  ///
  /// In sr, this message translates to:
  /// **'Premesti'**
  String get move;

  /// No description provided for @newFeature.
  ///
  /// In sr, this message translates to:
  /// **'Novo: {kind}'**
  String newFeature(String kind);

  /// No description provided for @editFeature.
  ///
  /// In sr, this message translates to:
  /// **'Izmena: {name}'**
  String editFeature(String name);

  /// No description provided for @nameRequired.
  ///
  /// In sr, this message translates to:
  /// **'Unesite naziv'**
  String get nameRequired;

  /// No description provided for @invalidUrl.
  ///
  /// In sr, this message translates to:
  /// **'Unesite http(s) adresu'**
  String get invalidUrl;

  /// No description provided for @deleteConfirm.
  ///
  /// In sr, this message translates to:
  /// **'Obrisati „{name}“?'**
  String deleteConfirm(String name);

  /// No description provided for @walkwayNode.
  ///
  /// In sr, this message translates to:
  /// **'Čvor staze'**
  String get walkwayNode;

  /// No description provided for @nodeEdges.
  ///
  /// In sr, this message translates to:
  /// **'Veza: {count}'**
  String nodeEdges(int count);

  /// No description provided for @typeMarker.
  ///
  /// In sr, this message translates to:
  /// **'QR marker'**
  String get typeMarker;

  /// No description provided for @openViewer.
  ///
  /// In sr, this message translates to:
  /// **'Pogledaj kao posetilac'**
  String get openViewer;

  /// No description provided for @copied.
  ///
  /// In sr, this message translates to:
  /// **'Kopirano'**
  String get copied;

  /// No description provided for @reload.
  ///
  /// In sr, this message translates to:
  /// **'Osveži'**
  String get reload;

  /// No description provided for @issueNoFloors.
  ///
  /// In sr, this message translates to:
  /// **'Dodajte bar jedan sprat pre objavljivanja.'**
  String get issueNoFloors;

  /// No description provided for @issueInvalidGraph.
  ///
  /// In sr, this message translates to:
  /// **'Staza na spratu „{floor}“ nije ispravna: {detail}'**
  String issueInvalidGraph(String floor, String detail);

  /// No description provided for @issueInvalidFeature.
  ///
  /// In sr, this message translates to:
  /// **'„{name}“ nije ispravan: {detail}'**
  String issueInvalidFeature(String name, String detail);

  /// No description provided for @issueNoEntrance.
  ///
  /// In sr, this message translates to:
  /// **'„{name}“ nije povezan sa stazom, pa ruta do njega nije moguća.'**
  String issueNoEntrance(String name);

  /// No description provided for @issueUnknownEntrance.
  ///
  /// In sr, this message translates to:
  /// **'„{name}“ kao ulaz koristi obrisan čvor staze. Izaberite ga i kliknite „Najbliži čvor“.'**
  String issueUnknownEntrance(String name);

  /// No description provided for @issueUnreachable.
  ///
  /// In sr, this message translates to:
  /// **'„{name}“ je na delu staze koji nije povezan sa ostatkom.'**
  String issueUnreachable(String name);

  /// No description provided for @showRoute.
  ///
  /// In sr, this message translates to:
  /// **'Prikaži put'**
  String get showRoute;

  /// No description provided for @routeFromTitle.
  ///
  /// In sr, this message translates to:
  /// **'Odakle krećete?'**
  String get routeFromTitle;

  /// No description provided for @routePickOnMap.
  ///
  /// In sr, this message translates to:
  /// **'Izaberite na mapi'**
  String get routePickOnMap;

  /// No description provided for @routePickHint.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite mesto na mapi gde se nalazite'**
  String get routePickHint;

  /// No description provided for @youAreHere.
  ///
  /// In sr, this message translates to:
  /// **'Vi ste ovde'**
  String get youAreHere;

  /// No description provided for @routeTo.
  ///
  /// In sr, this message translates to:
  /// **'Do: {name}'**
  String routeTo(String name);

  /// No description provided for @routeSummary.
  ///
  /// In sr, this message translates to:
  /// **'{meters} m · {minutes} min'**
  String routeSummary(int meters, int minutes);

  /// No description provided for @routeEstimated.
  ///
  /// In sr, this message translates to:
  /// **'procena'**
  String get routeEstimated;

  /// No description provided for @routeNoStairs.
  ///
  /// In sr, this message translates to:
  /// **'Bez stepenica'**
  String get routeNoStairs;

  /// No description provided for @routeLoading.
  ///
  /// In sr, this message translates to:
  /// **'Tražim put…'**
  String get routeLoading;

  /// No description provided for @routeNoRoute.
  ///
  /// In sr, this message translates to:
  /// **'Do ovog mesta nema puta na mapi.'**
  String get routeNoRoute;

  /// No description provided for @routeFailed.
  ///
  /// In sr, this message translates to:
  /// **'Put trenutno nije moguće izračunati. Proverite vezu.'**
  String get routeFailed;

  /// No description provided for @routeByLift.
  ///
  /// In sr, this message translates to:
  /// **'Idite liftom na sprat {floor}'**
  String routeByLift(String floor);

  /// No description provided for @routeByStairs.
  ///
  /// In sr, this message translates to:
  /// **'Idite stepenicama na sprat {floor}'**
  String routeByStairs(String floor);

  /// No description provided for @routeContinue.
  ///
  /// In sr, this message translates to:
  /// **'Nastavite na sprat {floor}'**
  String routeContinue(String floor);

  /// No description provided for @routeStartsOn.
  ///
  /// In sr, this message translates to:
  /// **'Put počinje na spratu {floor}'**
  String routeStartsOn(String floor);

  /// No description provided for @routeShowFloor.
  ///
  /// In sr, this message translates to:
  /// **'Prikaži'**
  String get routeShowFloor;

  /// No description provided for @closeRoute.
  ///
  /// In sr, this message translates to:
  /// **'Zatvori put'**
  String get closeRoute;

  /// No description provided for @routeAlreadyHere.
  ///
  /// In sr, this message translates to:
  /// **'Već ste ovde.'**
  String get routeAlreadyHere;

  /// No description provided for @gpsMyLocation.
  ///
  /// In sr, this message translates to:
  /// **'Moja lokacija'**
  String get gpsMyLocation;

  /// No description provided for @gpsSearching.
  ///
  /// In sr, this message translates to:
  /// **'Tražim GPS signal…'**
  String get gpsSearching;

  /// No description provided for @gpsWeak.
  ///
  /// In sr, this message translates to:
  /// **'GPS je neprecizan (±{meters} m). Skenirajte QR kod ili izaberite mesto na mapi.'**
  String gpsWeak(int meters);

  /// No description provided for @gpsOutside.
  ///
  /// In sr, this message translates to:
  /// **'Izgleda da niste u objektu.'**
  String get gpsOutside;

  /// No description provided for @gpsNoGeoref.
  ///
  /// In sr, this message translates to:
  /// **'Za ovaj sprat GPS nije podešen.'**
  String get gpsNoGeoref;

  /// No description provided for @gpsDenied.
  ///
  /// In sr, this message translates to:
  /// **'Lokacija nije dozvoljena. Skenirajte QR kod ili izaberite mesto na mapi.'**
  String get gpsDenied;

  /// No description provided for @gpsServiceOff.
  ///
  /// In sr, this message translates to:
  /// **'Lokacija je isključena na uređaju.'**
  String get gpsServiceOff;

  /// No description provided for @gpsFailed.
  ///
  /// In sr, this message translates to:
  /// **'Lokacija trenutno nije dostupna.'**
  String get gpsFailed;

  /// No description provided for @arrived.
  ///
  /// In sr, this message translates to:
  /// **'Stigli ste: {name}'**
  String arrived(String name);

  /// No description provided for @georefMenu.
  ///
  /// In sr, this message translates to:
  /// **'Podesi GPS (georeferenciranje)'**
  String get georefMenu;

  /// No description provided for @georefMenuSet.
  ///
  /// In sr, this message translates to:
  /// **'GPS je podešen: izmeni'**
  String get georefMenuSet;

  /// No description provided for @georefTitle.
  ///
  /// In sr, this message translates to:
  /// **'GPS za sprat „{floor}“'**
  String georefTitle(String floor);

  /// No description provided for @georefIntro.
  ///
  /// In sr, this message translates to:
  /// **'Izaberite 3 mesta koja lako nađete i na planu i na Google mapama (uglovi zgrade, ulazi), što dalje jedno od drugog. Za svako: dodirnite plan, pa nalepite koordinate (u Google mapama: desni klik na mesto → kliknite na koordinate).'**
  String get georefIntro;

  /// No description provided for @georefPoint.
  ///
  /// In sr, this message translates to:
  /// **'Tačka {n}'**
  String georefPoint(int n);

  /// No description provided for @georefTapPlan.
  ///
  /// In sr, this message translates to:
  /// **'Dodirnite plan'**
  String get georefTapPlan;

  /// No description provided for @georefCoordsHint.
  ///
  /// In sr, this message translates to:
  /// **'npr. 44.81234, 20.46123'**
  String get georefCoordsHint;

  /// No description provided for @georefCoordsInvalid.
  ///
  /// In sr, this message translates to:
  /// **'Unesite „širina, dužina“'**
  String get georefCoordsInvalid;

  /// No description provided for @georefScale.
  ///
  /// In sr, this message translates to:
  /// **'Razmera: {cm} cm po pikselu · moguća greška ±{meters} m'**
  String georefScale(String cm, String meters);

  /// No description provided for @georefDegenerate.
  ///
  /// In sr, this message translates to:
  /// **'Tačke su na jednoj liniji ili preblizu. Izaberite mesta dalje jedno od drugog.'**
  String get georefDegenerate;

  /// No description provided for @georefBadPoint.
  ///
  /// In sr, this message translates to:
  /// **'Moguća greška je velika: neka tačka je verovatno pogrešno postavljena.'**
  String get georefBadPoint;

  /// No description provided for @georefRemove.
  ///
  /// In sr, this message translates to:
  /// **'Ukloni GPS'**
  String get georefRemove;

  /// No description provided for @georefSaved.
  ///
  /// In sr, this message translates to:
  /// **'GPS je podešen. Posetioci ga dobijaju posle objave.'**
  String get georefSaved;

  /// No description provided for @georefRemoved.
  ///
  /// In sr, this message translates to:
  /// **'GPS je uklonjen.'**
  String get georefRemoved;

  /// No description provided for @statsOpen.
  ///
  /// In sr, this message translates to:
  /// **'Statistika'**
  String get statsOpen;

  /// No description provided for @statsTitle.
  ///
  /// In sr, this message translates to:
  /// **'Statistika mape'**
  String get statsTitle;

  /// No description provided for @statsRangeToday.
  ///
  /// In sr, this message translates to:
  /// **'Danas'**
  String get statsRangeToday;

  /// No description provided for @statsRange7.
  ///
  /// In sr, this message translates to:
  /// **'7 dana'**
  String get statsRange7;

  /// No description provided for @statsRange30.
  ///
  /// In sr, this message translates to:
  /// **'30 dana'**
  String get statsRange30;

  /// No description provided for @statsRangeEvent.
  ///
  /// In sr, this message translates to:
  /// **'Tokom događaja'**
  String get statsRangeEvent;

  /// No description provided for @statsSearches.
  ///
  /// In sr, this message translates to:
  /// **'Pretrage'**
  String get statsSearches;

  /// No description provided for @statsNoResults.
  ///
  /// In sr, this message translates to:
  /// **'Bez rezultata'**
  String get statsNoResults;

  /// No description provided for @statsFeatureViews.
  ///
  /// In sr, this message translates to:
  /// **'Otvoreni detalji'**
  String get statsFeatureViews;

  /// No description provided for @statsRoutes.
  ///
  /// In sr, this message translates to:
  /// **'Tražene rute'**
  String get statsRoutes;

  /// No description provided for @statsQrScans.
  ///
  /// In sr, this message translates to:
  /// **'QR skeniranja'**
  String get statsQrScans;

  /// No description provided for @statsPerDay.
  ///
  /// In sr, this message translates to:
  /// **'Aktivnost po danu'**
  String get statsPerDay;

  /// No description provided for @statsPerDayHint.
  ///
  /// In sr, this message translates to:
  /// **'Pretrage, otvoreni detalji, rute i QR skeniranja zajedno'**
  String get statsPerDayHint;

  /// No description provided for @statsDayTooltip.
  ///
  /// In sr, this message translates to:
  /// **'{date}: {count}'**
  String statsDayTooltip(String date, int count);

  /// No description provided for @statsNotFound.
  ///
  /// In sr, this message translates to:
  /// **'Traže, a ne nalaze'**
  String get statsNotFound;

  /// No description provided for @statsNotFoundHint.
  ///
  /// In sr, this message translates to:
  /// **'Pretrage bez ijednog rezultata. Možda na planu fali mesto, naziv ili kategorija.'**
  String get statsNotFoundHint;

  /// No description provided for @statsTopSearches.
  ///
  /// In sr, this message translates to:
  /// **'Najčešće pretrage'**
  String get statsTopSearches;

  /// No description provided for @statsTopFeatures.
  ///
  /// In sr, this message translates to:
  /// **'Najčešće otvarano'**
  String get statsTopFeatures;

  /// No description provided for @statsTopRoutes.
  ///
  /// In sr, this message translates to:
  /// **'Najčešći ciljevi ruta'**
  String get statsTopRoutes;

  /// No description provided for @statsQrList.
  ///
  /// In sr, this message translates to:
  /// **'Skeniranja po QR markeru'**
  String get statsQrList;

  /// No description provided for @statsRemoved.
  ///
  /// In sr, this message translates to:
  /// **'(uklonjeno sa plana)'**
  String get statsRemoved;

  /// No description provided for @statsEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Još nema podataka za ovaj period. Brojke stižu kad posetioci koriste mapu, uz kašnjenje do 10 sekundi.'**
  String get statsEmpty;

  /// No description provided for @statsError.
  ///
  /// In sr, this message translates to:
  /// **'Statistika trenutno nije dostupna.'**
  String get statsError;

  /// No description provided for @statsPrivacy.
  ///
  /// In sr, this message translates to:
  /// **'Samo zbirni brojevi po danu. Bez lokacija i bez podataka o osobama.'**
  String get statsPrivacy;

  /// No description provided for @qrOpen.
  ///
  /// In sr, this message translates to:
  /// **'QR oznake za štampu'**
  String get qrOpen;

  /// No description provided for @qrTitle.
  ///
  /// In sr, this message translates to:
  /// **'QR oznake'**
  String get qrTitle;

  /// No description provided for @qrIntro.
  ///
  /// In sr, this message translates to:
  /// **'Odštampajte i postavite svaku oznaku na mesto koje ste označili na planu. Posetilac skenira kod i odmah vidi gde je i put do štanda ili sale.'**
  String get qrIntro;

  /// No description provided for @qrNotPublished.
  ///
  /// In sr, this message translates to:
  /// **'Događaj još nije objavljen. Kodovi rade tek kad objavite mapu.'**
  String get qrNotPublished;

  /// No description provided for @qrPublishFirst.
  ///
  /// In sr, this message translates to:
  /// **'Nova ili pomerena oznaka radi tek posle objave.'**
  String get qrPublishFirst;

  /// No description provided for @qrNone.
  ///
  /// In sr, this message translates to:
  /// **'Još nema QR oznaka. Dodajte ih alatom „QR marker“ na planu, pa objavite.'**
  String get qrNone;

  /// No description provided for @qrPrint.
  ///
  /// In sr, this message translates to:
  /// **'Štampaj'**
  String get qrPrint;

  /// No description provided for @qrScanHint.
  ///
  /// In sr, this message translates to:
  /// **'Skenirajte kamerom telefona: plan objekta i put do štanda ili sale.'**
  String get qrScanHint;

  /// No description provided for @qrPopupBlocked.
  ///
  /// In sr, this message translates to:
  /// **'Pregledač je blokirao novu karticu. Dozvolite iskačuće prozore za ovu stranicu.'**
  String get qrPopupBlocked;

  /// No description provided for @qrCopy.
  ///
  /// In sr, this message translates to:
  /// **'Kopiraj link'**
  String get qrCopy;

  /// No description provided for @qrCopied.
  ///
  /// In sr, this message translates to:
  /// **'Link je kopiran.'**
  String get qrCopied;

  /// No description provided for @qrLoadFailed.
  ///
  /// In sr, this message translates to:
  /// **'Oznake trenutno nije moguće učitati.'**
  String get qrLoadFailed;
}

class _MapsLocalizationsDelegate
    extends LocalizationsDelegate<MapsLocalizations> {
  const _MapsLocalizationsDelegate();

  @override
  Future<MapsLocalizations> load(Locale locale) {
    return SynchronousFuture<MapsLocalizations>(
      lookupMapsLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_MapsLocalizationsDelegate old) => false;
}

MapsLocalizations lookupMapsLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return MapsLocalizationsEn();
    case 'sr':
      return MapsLocalizationsSr();
  }

  throw FlutterError(
    'MapsLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
