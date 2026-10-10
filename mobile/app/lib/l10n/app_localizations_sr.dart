// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get appTitle => 'Eho';

  @override
  String get cancel => 'Otkaži';

  @override
  String get open => 'Otvori';

  @override
  String get save => 'Sačuvaj';

  @override
  String get done => 'Gotovo';

  @override
  String get continueButton => 'Nastavi';

  @override
  String get myEvents => 'Moji događaji';

  @override
  String get joinEvent => 'Pridruži se';

  @override
  String get lookingFor => 'Traži';

  @override
  String get showMeInFind => 'Prikaži me u Pronađi';

  @override
  String get allowContactRequests => 'Dozvoli zahteve za kontakt';

  @override
  String get allowMeetingSpots => 'Dozvoli mesta za sastanak';

  @override
  String get startTagline =>
      'Tvoj AI pratilac na događajima: program, prostor, predavanja i ljudi.';

  @override
  String get startJoinButton => 'Pridruži se linkom ili kodom';

  @override
  String get startOrganizerButton => 'Ja sam organizator';

  @override
  String get joinDialogTitle => 'Pridruži se događaju';

  @override
  String get joinDialogLabel => 'Link ili kod događaja';

  @override
  String get tabAgenda => 'Program';

  @override
  String get tabMap => 'Mapa';

  @override
  String get tabFind => 'Pronađi';

  @override
  String get tabProfile => 'Profil';

  @override
  String mapMeetingHighlight(String name) {
    return 'Sastanak: $name';
  }

  @override
  String mapMeetingTitle(String name) {
    return 'Sastanak sa $name';
  }

  @override
  String mapMeetingAt(String place) {
    return 'kod: $place';
  }

  @override
  String get mapShowSpot => 'Prikaži';

  @override
  String get profileYourName => 'Tvoje ime';

  @override
  String get profilePrivacy => 'Privatnost';

  @override
  String profileJoinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count događaja',
      few: '$count događaja',
      one: '$count događaj',
    );
    return '$_temp0';
  }

  @override
  String get profileTalkSummaries => 'Rezimei predavanja';

  @override
  String profileUnlockedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count otključanih',
      few: '$count otključana',
      one: '$count otključan',
    );
    return '$_temp0';
  }

  @override
  String get profileForOrganizers => 'Za organizatore';

  @override
  String get profileCreateEvent => 'Napravi događaj';

  @override
  String get profileEditVenueMap => 'Uredi mapu prostora';

  @override
  String get agendaAllStages => 'Sve bine';

  @override
  String get sessionOpenEcho => 'Otvori Eho: transkript uživo i AI';

  @override
  String sessionShowOnMap(String stage) {
    return 'Prikaži $stage na mapi';
  }

  @override
  String joinLoadError(String error) {
    return 'Događaj nije učitan: $error';
  }

  @override
  String get joinInvited => 'Pozvani ste na';

  @override
  String get joinPerkAgenda => 'Program za svaku binu';

  @override
  String get joinPerkMap => 'Mapa prostora';

  @override
  String get joinPerkEcho =>
      'Transkript uživo i AI odgovori na svakom predavanju';

  @override
  String get joinPerkFind => 'Pronađi ljude koje vredi upoznati';

  @override
  String get joinJoining => 'Pridružujem…';

  @override
  String onboardingStep(int step, int total) {
    return 'Korak $step od $total';
  }

  @override
  String get onboardingWhoTitle => 'Ko si ti?';

  @override
  String get onboardingName => 'Ime';

  @override
  String get onboardingHeadline => 'Čime se baviš';

  @override
  String get onboardingHeadlineHint => 'npr. Android programer u Fintiju';

  @override
  String get onboardingInterestsTitle => 'Šta te zanima?';

  @override
  String get onboardingLookingForLabel => 'Koga želiš da upoznaš?';

  @override
  String get onboardingLookingForHint =>
      'npr. ljude koji su isporučili ML na uređaju';

  @override
  String get onboardingPrivacyTitle => 'Ti biraš šta drugi vide';

  @override
  String get onboardingPrivacyBody =>
      'Ovo možeš promeniti bilo kada u Profilu.';

  @override
  String get showMeInFindSubtitle =>
      'Drugi na ovom događaju mogu te dobiti kao preporuku.';

  @override
  String get allowContactRequestsSubtitle =>
      'Tvoji podaci se dele samo ako prihvatiš.';

  @override
  String get allowMeetingSpotsSubtitle =>
      'Dogovorite mesto sastanka. Nikad tvoja lokacija uživo.';

  @override
  String get myEventsUpcoming => 'Sada i uskoro';

  @override
  String get myEventsPast => 'Prošli';

  @override
  String get myEventsEmpty =>
      'Otvori link događaja da se pridružiš prvom događaju.';

  @override
  String get leaveEvent => 'Napusti događaj';

  @override
  String get findTitle => 'Pronađi ljude';

  @override
  String get findSearchHint => 'Opiši koga želiš da upoznaš…';

  @override
  String findResultsFor(String query) {
    return 'Rezultati za „$query”';
  }

  @override
  String get findSearching => 'Pretražujem posetioce…';

  @override
  String get findRecommended => 'Preporučeno za tebe';

  @override
  String get findThinking => 'Tražim najbolja poklapanja…';

  @override
  String get findNoMatches =>
      'Još niko ne odgovara. Pokušaj da opišeš drugačije.';

  @override
  String get personWhyMeet => 'Zašto da se upoznate';

  @override
  String get personSendRequest => 'Pošalji zahtev za kontakt';

  @override
  String get personRequestSent => 'Zahtev poslat · čeka se…';

  @override
  String personAccepted(String name) {
    return '$name je prihvatio/la · Poruka';
  }

  @override
  String messagesMeetAt(String place) {
    return '📍 Vidimo se kod: $place';
  }

  @override
  String get messagesSuggestSpot => 'Predloži mesto sastanka';

  @override
  String get messagesHint => 'Poruka';

  @override
  String get echoTitle => 'Eho';

  @override
  String echoAskAboutPrefill(String line) {
    return 'Šta je predavač mislio pod: „$line”';
  }

  @override
  String get echoQuestionSent => 'Pitanje je poslato predavaču';

  @override
  String get echoShowOriginal => 'Prikaži original';

  @override
  String get echoTranslate => 'Prevedi na srpski';

  @override
  String get echoJumpToLive => 'Nazad na uživo';

  @override
  String get echoQuestionsTitle => 'Pitanja za predavača';

  @override
  String get echoYourQuestion => 'Tvoje pitanje';

  @override
  String get echoFullSummary => 'Ceo rezime predavanja';

  @override
  String get echoUnlocked => 'Otključano';

  @override
  String get echoPremiumSubtitle => 'Premium · AI rezime celog predavanja';

  @override
  String get echoCatchUp => 'Sustigni';

  @override
  String get echoCatchUpSubtitle => 'Šta je do sada rečeno';

  @override
  String get echoSummarizing => 'Pravim rezime…';

  @override
  String get echoUnlockTitle => 'Otključaj rezimee predavanja';

  @override
  String get echoUnlockBody =>
      'Dobij AI rezime svakog predavanja na ovom događaju: ključne tačke, kompromise i zaključke.';

  @override
  String get echoNotNow => 'Ne sada';

  @override
  String get echoUnlockPrice => 'Otključaj · 2,99 €';

  @override
  String get echoAskAboutThis => 'Pitaj o ovome';

  @override
  String get echoTalkEnded => 'Predavanje je završeno';

  @override
  String get echoAskAi => 'Pitaj AI';

  @override
  String get echoAskSpeaker => 'Pitaj predavača';

  @override
  String get echoAskHint => 'Pitaj o ovom predavanju…';

  @override
  String get echoSpeakerHint => 'Pitanje za predavača…';

  @override
  String get orgNewEvent => 'Novi događaj';

  @override
  String get orgUploadTitle => 'Ubaci šta god imaš';

  @override
  String get orgUploadBody =>
      'PDF programa, tabele predavača, planove prostora, slajdove. Eho ih čita i pravi tvoj događaj.';

  @override
  String get orgChooseFiles => 'Izaberi fajlove';

  @override
  String orgFileSizeKb(int kb) {
    return '$kb KB';
  }

  @override
  String get orgReading =>
      'Čitam fajlove i izdvajam bine, predavanja i predavače…';

  @override
  String get orgBuild => 'Napravi događaj uz AI';

  @override
  String get orgStartByUploading => 'Počni otpremanjem fajlova';

  @override
  String get orgReviewTitle => 'Pregledaj događaj';

  @override
  String orgStagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bina',
      few: '$count bine',
      one: '$count bina',
    );
    return '$_temp0';
  }

  @override
  String orgSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count predavanja',
      few: '$count predavanja',
      one: '$count predavanje',
    );
    return '$_temp0';
  }

  @override
  String orgSpeakersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count predavača',
      few: '$count predavača',
      one: '$count predavač',
    );
    return '$_temp0';
  }

  @override
  String get orgSessions => 'Predavanja';

  @override
  String get orgEditSession => 'Uredi predavanje';

  @override
  String get orgPublish => 'Objavi i dobij link';

  @override
  String get orgTitleRequired => 'Naslov je obavezan';

  @override
  String get orgEndAfterStart => 'Kraj mora biti posle početka';

  @override
  String get orgTitleLabel => 'Naslov';

  @override
  String orgStartTime(String time) {
    return 'Početak $time';
  }

  @override
  String orgEndTime(String time) {
    return 'Kraj $time';
  }

  @override
  String get orgStageLabel => 'Bina';

  @override
  String get orgPublished => 'Objavljeno';

  @override
  String orgIsLive(String name) {
    return '$name je objavljen';
  }

  @override
  String get orgShareBody =>
      'Podeli ovaj link ili odštampaj QR kod. Posetioci se pridružuju jednim dodirom, u aplikaciji ili pregledaču.';

  @override
  String get orgCopyLink => 'Kopiraj link';

  @override
  String get orgLinkCopied => 'Link je kopiran';

  @override
  String get orgOpenAsAttendee => 'Otvori kao posetilac';

  @override
  String get devStatusTitle => 'Status sistema';

  @override
  String get backendLabel => 'Backend';

  @override
  String get authLabel => 'Prijava';

  @override
  String get statusOk => 'Radi';

  @override
  String get statusChecking => 'Proveravam…';

  @override
  String statusError(String message) {
    return 'Greška: $message';
  }

  @override
  String signedInAnonymously(String uid) {
    return 'Anonimni korisnik $uid';
  }

  @override
  String get notSignedIn => 'Niste prijavljeni';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String eventTitle(String eventId) {
    return 'Događaj $eventId';
  }

  @override
  String get backendUnavailable =>
      'Server trenutno nije dostupan. Proverite internet vezu i pokušajte ponovo.';

  @override
  String get openEventLabel => 'ID događaja';

  @override
  String get openEvent => 'Otvori plan';

  @override
  String get echoThinking => 'Echo razmišlja…';

  @override
  String get echoRetry => 'Pokušaj ponovo';

  @override
  String get echoErrorAiBusy => 'Echo trenutno ne može da odgovori.';

  @override
  String get echoErrorRateLimited =>
      'Trenutno ima mnogo zahteva. Sačekaj malo i pokušaj ponovo.';

  @override
  String get echoErrorOffline => 'Echo nije dostupan. Proveri vezu.';

  @override
  String get echoErrorNoTranscript =>
      'Ovo predavanje još nema transkript uživo.';

  @override
  String get echoErrorFailed => 'Nešto nije u redu.';

  @override
  String get echoWaitingForTalk => 'Čekamo da predavanje počne…';

  @override
  String get echoTranscriptUnavailable =>
      'Transkript uživo trenutno nije dostupan.';
}
