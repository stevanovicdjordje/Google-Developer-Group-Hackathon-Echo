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
