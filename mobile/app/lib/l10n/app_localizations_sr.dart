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
      'Tvoj AI pratilac za događaje. Program, prostor, svako predavanje i ljudi koje vredi upoznati.';

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
  String mapSheetCapacity(int count) {
    return 'do $count mesta';
  }

  @override
  String mapSheetWalkMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String mapSheetWalkDistance(int meters) {
    return '~$meters m hoda';
  }

  @override
  String mapSheetNow(String start, String end) {
    return 'Sada · $start–$end';
  }

  @override
  String mapSheetNext(String start) {
    return 'Sledeće · $start';
  }

  @override
  String get mapSheetStartRoute => 'Kreni';

  @override
  String get mapSheetOpenEcho => 'Otvori Echo';

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
  String get profilePremium => 'Premium';

  @override
  String get profileForOrganizers => 'Za organizatore';

  @override
  String get profileCreateEvent => 'Napravi događaj';

  @override
  String get profileEditVenueMap => 'Uredi mapu prostora';

  @override
  String agendaEventDay(String event, int day) {
    return '$event · Dan $day';
  }

  @override
  String get agendaAllStages => 'Sve bine';

  @override
  String get agendaLiveEchoOn => 'Uživo · Eho uključen';

  @override
  String get agendaLiveNow => 'Uživo';

  @override
  String get agendaEchoOnTitle => 'Eho je uključen za ovo predavanje';

  @override
  String get agendaEchoOnBody =>
      'Transkript uživo, prevod, pitaj AI o onome što je rečeno i pošalji pitanja predavaču.';

  @override
  String get sessionOpenEcho => 'Otvori Eho';

  @override
  String sessionTrack(String track) {
    return 'Tok: $track';
  }

  @override
  String get sessionSave => 'Sačuvaj u moj program';

  @override
  String get sessionSaved => 'Ukloni iz mog programa';

  @override
  String sessionShowOnMap(String stage) {
    return 'Prikaži $stage na mapi';
  }

  @override
  String get joinErrorNotFoundTitle => 'Ovaj događaj još nije dostupan';

  @override
  String get joinErrorNotFoundBody =>
      'Proveri link koji si otvorio/la ili zamoli organizatora da ga ponovo podeli. Događaj možda još nije objavljen.';

  @override
  String get joinErrorOfflineTitle => 'Eho trenutno nije dostupan';

  @override
  String get joinErrorOfflineBody => 'Proveri vezu i pokušaj ponovo.';

  @override
  String get joinErrorFailedTitle => 'Nešto nije u redu';

  @override
  String get joinErrorFailedBody =>
      'Nismo uspeli da učitamo ovaj događaj. Pokušaj ponovo za trenutak.';

  @override
  String get joinBackToStart => 'Nazad na početak';

  @override
  String get joinInvited => 'Pozvani ste na';

  @override
  String get joinPerkAgenda => 'Program za svaku binu';

  @override
  String get joinPerkMap => 'Mapa prostora i uputstva za snalaženje';

  @override
  String get joinPerkEcho =>
      'Transkript uživo i AI odgovori na svakom predavanju';

  @override
  String get joinPerkFind => 'Pronađi ljude koje vredi upoznati';

  @override
  String get joinWithEho => 'Uz Eho dobijaš';

  @override
  String get joinJoining => 'Pridružujem…';

  @override
  String onboardingStep(int step, int total) {
    return '$step od $total';
  }

  @override
  String get onboardingWhoTitle => 'Ko si ti?';

  @override
  String get onboardingWhoSubtitle =>
      'Ovako te drugi posetioci vide u Pronađi. Samo ako izabereš da budeš vidljiv/a.';

  @override
  String get onboardingName => 'Ime';

  @override
  String get onboardingHeadline => 'Čime se baviš';

  @override
  String get onboardingHeadlineHint => 'npr. Android programer u Fintiju';

  @override
  String get onboardingInterestsTitle => 'Šta te zanima?';

  @override
  String get onboardingInterestsSubtitle =>
      'Na osnovu ovoga preporučujemo predavanja i ljude. Izaberi nekoliko.';

  @override
  String get onboardingLookingForLabel => 'Koga želiš da upoznaš?';

  @override
  String get onboardingLookingForHint =>
      'npr. ljude koji su isporučili ML na uređaju';

  @override
  String get onboardingLookingForNote =>
      'AI ovo čita da bi pronašao tvoja poklapanja.';

  @override
  String get onboardingPrivacyTitle => 'Ti biraš šta drugi vide';

  @override
  String get onboardingPrivacyBody =>
      'Svaki prekidač je zaseban. Možeš ih promeniti bilo kada u Profilu.';

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
  String get onboardingPrivacyNote =>
      'Tvoj profil ide samo do AI-ja radi pronalaženja poklapanja, i samo dok je „Prikaži me u Pronađi” uključeno.';

  @override
  String get myEventsNow => 'Trenutno aktivni';

  @override
  String myEventsLiveDay(int day) {
    return 'Uživo · Dan $day';
  }

  @override
  String get myEventsPast => 'Prošli';

  @override
  String get myEventsEmpty =>
      'Otvori link događaja da se pridružiš prvom događaju.';

  @override
  String get leaveEvent => 'Napusti događaj';

  @override
  String myEventsNext(String session, String time, String stage) {
    return 'Sledeće: $session · $time · $stage';
  }

  @override
  String get findTitle => 'Pronađi ljude';

  @override
  String get findSearchHint => 'Opiši koga želiš da upoznaš';

  @override
  String get findSearching => 'Pretražujem posetioce…';

  @override
  String get findRecommended => 'Preporučeno za tebe';

  @override
  String get findFromInterests => 'na osnovu tvojih interesovanja';

  @override
  String get findTopMatch => 'Najbolje poklapanje';

  @override
  String findResultsCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osoba ovde odgovara',
      few: '$count osobe ovde odgovaraju',
      one: '$count osoba ovde odgovara',
    );
    return '$_temp0 · samo osobe koje su pristale';
  }

  @override
  String get findThinking => 'Tražim najbolja poklapanja…';

  @override
  String get findNoMatches =>
      'Još niko ne odgovara. Pokušaj da opišeš drugačije.';

  @override
  String get findErrorOffline =>
      'Find trenutno nije dostupan. Proveri internet vezu i pokušaj ponovo.';

  @override
  String get findErrorRateLimited =>
      'Previše zahteva. Sačekaj nekoliko sekundi i pokušaj ponovo.';

  @override
  String get findErrorAiBusy =>
      'Trenutno ne mogu da pronađem poklapanja. Pokušaj ponovo za trenutak.';

  @override
  String get findErrorNotFound => 'Ova osoba više nije vidljiva u Find-u.';

  @override
  String get findErrorNotAllowed => 'Ova osoba ne prima zahteve za kontakt.';

  @override
  String get findErrorProfileRequired =>
      'Dovrši profil da bi koristio/la Find.';

  @override
  String get findErrorFailed =>
      'Nešto je pošlo naopako u Find-u. Pokušaj ponovo.';

  @override
  String get findCompleteProfile => 'Dovrši profil';

  @override
  String findRetryIn(int seconds) {
    return 'Pokušaj ponovo za ${seconds}s';
  }

  @override
  String get personWhyMeet => 'Zašto da se upoznate';

  @override
  String get personSendRequest => 'Pošalji zahtev za kontakt';

  @override
  String get personRequestSent => 'Zahtev poslat · čeka se…';

  @override
  String personRequestSentTo(String name) {
    return 'Zahtev poslat · čeka se $name';
  }

  @override
  String personDetailsNote(String name) {
    return 'Tvoji podaci se dele tek kada $name prihvati.';
  }

  @override
  String personDetailsAccepted(String name) {
    return 'Povezani ste. $name može da vidi tvoje podatke.';
  }

  @override
  String personAccepted(String name) {
    return '$name je prihvatio/la · Poruka';
  }

  @override
  String personNotAccepting(String name) {
    return '$name ne prima zahteve za kontakt.';
  }

  @override
  String messagesMeetAt(String place) {
    return 'Sastanak kod: $place';
  }

  @override
  String messagesSpotWhen(String time, String floor) {
    return '$time · $floor';
  }

  @override
  String get messagesSuggestSpot => 'Predloži mesto sastanka';

  @override
  String messagesMatchedOn(String topics) {
    return 'Poklapanje: $topics';
  }

  @override
  String messagesTopicsTwo(String first, String second) {
    return '$first i $second';
  }

  @override
  String messagesAcceptedPill(String name) {
    return '$name je prihvatio/la tvoj zahtev za kontakt';
  }

  @override
  String get messagesShowOnMap => 'Prikaži na mapi';

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
  String get echoQuestionMerged =>
      'Spojeno sa sličnim pitanjem · vaš glas se računa';

  @override
  String echoMergedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spojeno je $count sličnih pitanja',
      few: 'Spojena su $count slična pitanja',
      one: 'Spojeno 1 slično pitanje',
    );
    return '$_temp0';
  }

  @override
  String echoJumpToTime(String time) {
    return 'Prikaži $time u transkriptu';
  }

  @override
  String get echoShowOriginal => 'Prikaži original';

  @override
  String get echoTranslate => 'Prevedi na srpski';

  @override
  String get echoJumpToLive => 'Nazad na uživo';

  @override
  String get echoJumpToEnd => 'Na kraj';

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
  String get echoNotNow => 'Ne sada';

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
  String orgFileSizeMb(String mb) {
    return '$mb MB';
  }

  @override
  String get orgReading =>
      'Čitam fajlove i izdvajam bine, predavanja i predavače…';

  @override
  String orgFoundSoFar(String stages, String sessions, String speakers) {
    return 'Do sada pronađeno: $stages, $sessions, $speakers…';
  }

  @override
  String get orgBuild => 'Napravi događaj uz AI';

  @override
  String get orgStartByUploading => 'Počni otpremanjem fajlova';

  @override
  String get orgReviewTitle => 'Pregledaj događaj';

  @override
  String orgExtractedFrom(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fajlova',
      few: '$count fajla',
      one: '$count fajla',
    );
    return 'Izdvojeno iz $_temp0';
  }

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
  String get orgCheckRoomMissing => 'Proveri: sala nedostaje u PDF-u';

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
  String get orgCopy => 'Kopiraj';

  @override
  String get orgLinkCopied => 'Link je kopiran';

  @override
  String get orgOpenAsAttendee => 'Otvori kao posetilac';

  @override
  String get orgErrorOffline =>
      'Eho ne može da dođe do servisa za događaje. Proveri vezu i pokušaj ponovo.';

  @override
  String get orgErrorOrganizerRequired =>
      'Prvo se prijavi kao organizator (Profil → Za organizatore).';

  @override
  String get orgErrorForbidden =>
      'Tvoj organizatorski nalog ne može da objavi ovaj događaj.';

  @override
  String get orgErrorTooLarge =>
      'Previše ili preveliki fajlovi. Do 10 fajlova, 10 MB svaki, ukupno 20 MB.';

  @override
  String orgErrorUnsupportedFile(String file) {
    return 'Eho ne može da pročita $file. Koristi PDF, slike, tabele, CSV, tekst ili Word fajlove.';
  }

  @override
  String get orgErrorNothingExtracted =>
      'U ovim fajlovima nema sesija. Dodaj agendu i pokušaj ponovo.';

  @override
  String get orgErrorInvalid =>
      'Neki podaci nisu ispravni. Proveri sesije i pokušaj ponovo.';

  @override
  String get orgErrorRateLimited =>
      'Previše zahteva. Sačekaj nekoliko sekundi i pokušaj ponovo.';

  @override
  String get orgErrorAiBusy =>
      'AI trenutno ne može da pročita fajlove. Pokušaj ponovo za trenutak.';

  @override
  String get orgErrorFailed => 'Nešto nije u redu. Pokušaj ponovo.';

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

  @override
  String echoLiveAt(String stage) {
    return 'Uživo · $stage';
  }

  @override
  String echoEndedAt(String stage) {
    return 'Završeno · $stage';
  }

  @override
  String get echoTranslatedBanner =>
      'Prevedeno uživo sa engleskog · dodirni SR za original';

  @override
  String get echoTranslatedBannerEnded =>
      'Prevedeno sa engleskog · dodirni SR za original';

  @override
  String get echoLangOriginal => 'EN';

  @override
  String get echoLangTranslated => 'SR';

  @override
  String get echoSend => 'Pošalji';

  @override
  String echoQuestionsFor(String name) {
    return 'Pitanja za: $name';
  }

  @override
  String echoQuestionsMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pitanja',
      few: '$count pitanja',
      one: '1 pitanje',
      zero: 'Još nema pitanja',
    );
    return '$_temp0 · predavač ih vidi na kraju';
  }

  @override
  String get echoSortTop => 'Najbolja';

  @override
  String get echoSortNewest => 'Najnovija';

  @override
  String get echoSortMine => 'Moja';

  @override
  String get echoNoQuestions => 'Još nema pitanja. Postavi prvo.';

  @override
  String get echoNoMyQuestions => 'Još nisi ništa pitao.';

  @override
  String echoAskNameHint(String name) {
    return 'Pitaj: $name…';
  }

  @override
  String get echoUpvote => 'Glasaj';

  @override
  String get echoSendQuestion => 'Pošalji pitanje';

  @override
  String get echoPaywallTitle =>
      'Nešto ti je promaklo? Celo predavanje za 2 minuta.';

  @override
  String get echoPaywallBody =>
      'AI rezime sa ključnim tačkama, kompromisima i zaključcima, iz celog transkripta.';

  @override
  String get echoPaywallThisTalk => 'Ovo predavanje';

  @override
  String echoPaywallEveryTalk(String event) {
    return 'Sva predavanja: $event';
  }

  @override
  String echoPaywallEveryTalkSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count predavanja',
      few: '$count predavanja',
      one: '1 predavanje',
    );
    return '$_temp0, sve sale';
  }

  @override
  String get echoPriceTalk => '€2.99';

  @override
  String get echoPriceEvent => '€9.99';

  @override
  String get echoUnlockSummary => 'Otključaj rezime';

  @override
  String get echoSummaryBadge => 'AI rezime · Premium';

  @override
  String get echoTakeaway => 'Zaključak';

  @override
  String get echoKeyPoints => 'Ključne tačke';

  @override
  String get echoTradeoffs => 'Kompromisi i rešenja';

  @override
  String echoTalkMinutes(int minutes) {
    return '$minutes min predavanje';
  }

  @override
  String echoReadMinutes(int minutes) {
    return '$minutes min čitanja';
  }

  @override
  String get echoCopySummary => 'Kopiraj rezime';

  @override
  String get echoSummaryCopied => 'Rezime je kopiran';
}
