import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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

  /// App name.
  ///
  /// In en, this message translates to:
  /// **'Eho'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @myEvents.
  ///
  /// In en, this message translates to:
  /// **'My events'**
  String get myEvents;

  /// No description provided for @joinEvent.
  ///
  /// In en, this message translates to:
  /// **'Join event'**
  String get joinEvent;

  /// No description provided for @lookingFor.
  ///
  /// In en, this message translates to:
  /// **'Looking for'**
  String get lookingFor;

  /// No description provided for @showMeInFind.
  ///
  /// In en, this message translates to:
  /// **'Show me in Find'**
  String get showMeInFind;

  /// No description provided for @allowContactRequests.
  ///
  /// In en, this message translates to:
  /// **'Allow contact requests'**
  String get allowContactRequests;

  /// No description provided for @allowMeetingSpots.
  ///
  /// In en, this message translates to:
  /// **'Allow meeting spots'**
  String get allowMeetingSpots;

  /// No description provided for @startTagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI companion for events. The agenda, the venue, every talk, and the people worth meeting.'**
  String get startTagline;

  /// No description provided for @startJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Join with a link or code'**
  String get startJoinButton;

  /// No description provided for @startOrganizerButton.
  ///
  /// In en, this message translates to:
  /// **'I\'m an organizer'**
  String get startOrganizerButton;

  /// No description provided for @joinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Join an event'**
  String get joinDialogTitle;

  /// No description provided for @joinDialogLabel.
  ///
  /// In en, this message translates to:
  /// **'Event link or code'**
  String get joinDialogLabel;

  /// Bottom tab and agenda title fallback.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get tabAgenda;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get tabFind;

  /// Bottom tab and profile screen title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Label of the meeting spot pin on the map.
  ///
  /// In en, this message translates to:
  /// **'Meeting: {name}'**
  String mapMeetingHighlight(String name);

  /// No description provided for @mapMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting {name}'**
  String mapMeetingTitle(String name);

  /// No description provided for @mapMeetingAt.
  ///
  /// In en, this message translates to:
  /// **'at {place}'**
  String mapMeetingAt(String place);

  /// No description provided for @mapShowSpot.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get mapShowSpot;

  /// No description provided for @mapSheetCapacity.
  ///
  /// In en, this message translates to:
  /// **'up to {count} seats'**
  String mapSheetCapacity(int count);

  /// Walking time to the selected room, big blue number in the map details sheet.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String mapSheetWalkMinutes(int minutes);

  /// No description provided for @mapSheetWalkDistance.
  ///
  /// In en, this message translates to:
  /// **'~{meters} m walk'**
  String mapSheetWalkDistance(int meters);

  /// Overline of the live session in the map details sheet.
  ///
  /// In en, this message translates to:
  /// **'Now · {start}–{end}'**
  String mapSheetNow(String start, String end);

  /// No description provided for @mapSheetNext.
  ///
  /// In en, this message translates to:
  /// **'Next · {start}'**
  String mapSheetNext(String start);

  /// No description provided for @mapSheetStartRoute.
  ///
  /// In en, this message translates to:
  /// **'Start route'**
  String get mapSheetStartRoute;

  /// No description provided for @mapSheetOpenEcho.
  ///
  /// In en, this message translates to:
  /// **'Open Echo'**
  String get mapSheetOpenEcho;

  /// No description provided for @profileYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileYourName;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacy;

  /// No description provided for @profileJoinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 joined} other{{count} joined}}'**
  String profileJoinedCount(int count);

  /// No description provided for @profileTalkSummaries.
  ///
  /// In en, this message translates to:
  /// **'Talk summaries'**
  String get profileTalkSummaries;

  /// No description provided for @profileUnlockedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unlocked} other{{count} unlocked}}'**
  String profileUnlockedCount(int count);

  /// No description provided for @profileForOrganizers.
  ///
  /// In en, this message translates to:
  /// **'For organizers'**
  String get profileForOrganizers;

  /// No description provided for @profileCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get profileCreateEvent;

  /// No description provided for @profileEditVenueMap.
  ///
  /// In en, this message translates to:
  /// **'Edit venue map'**
  String get profileEditVenueMap;

  /// No description provided for @agendaAllStages.
  ///
  /// In en, this message translates to:
  /// **'All stages'**
  String get agendaAllStages;

  /// No description provided for @agendaLiveEchoOn.
  ///
  /// In en, this message translates to:
  /// **'Live now · Echo on'**
  String get agendaLiveEchoOn;

  /// No description provided for @agendaLiveNow.
  ///
  /// In en, this message translates to:
  /// **'Live now'**
  String get agendaLiveNow;

  /// No description provided for @agendaEchoOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Echo is on for this talk'**
  String get agendaEchoOnTitle;

  /// No description provided for @agendaEchoOnBody.
  ///
  /// In en, this message translates to:
  /// **'Live transcript, translation, ask the AI about what was said, and send questions to the speaker.'**
  String get agendaEchoOnBody;

  /// No description provided for @sessionOpenEcho.
  ///
  /// In en, this message translates to:
  /// **'Open Echo'**
  String get sessionOpenEcho;

  /// No description provided for @sessionTrack.
  ///
  /// In en, this message translates to:
  /// **'{track} track'**
  String sessionTrack(String track);

  /// No description provided for @sessionSave.
  ///
  /// In en, this message translates to:
  /// **'Save to my agenda'**
  String get sessionSave;

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from my agenda'**
  String get sessionSaved;

  /// No description provided for @sessionShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show {stage} on map'**
  String sessionShowOnMap(String stage);

  /// No description provided for @joinLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load event: {error}'**
  String joinLoadError(String error);

  /// No description provided for @joinInvited.
  ///
  /// In en, this message translates to:
  /// **'You\'re invited to'**
  String get joinInvited;

  /// No description provided for @joinPerkAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda for every stage'**
  String get joinPerkAgenda;

  /// No description provided for @joinPerkMap.
  ///
  /// In en, this message translates to:
  /// **'Venue map and directions'**
  String get joinPerkMap;

  /// No description provided for @joinPerkEcho.
  ///
  /// In en, this message translates to:
  /// **'Live transcripts and AI answers in every talk'**
  String get joinPerkEcho;

  /// No description provided for @joinPerkFind.
  ///
  /// In en, this message translates to:
  /// **'Find the people worth meeting'**
  String get joinPerkFind;

  /// No description provided for @joinWithEho.
  ///
  /// In en, this message translates to:
  /// **'With Eho you get'**
  String get joinWithEho;

  /// No description provided for @joinJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get joinJoining;

  /// No description provided for @onboardingStep.
  ///
  /// In en, this message translates to:
  /// **'{step} of {total}'**
  String onboardingStep(int step, int total);

  /// No description provided for @onboardingWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get onboardingWhoTitle;

  /// No description provided for @onboardingWhoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is how other attendees see you in Find. Only if you choose to be visible.'**
  String get onboardingWhoSubtitle;

  /// No description provided for @onboardingName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardingName;

  /// No description provided for @onboardingHeadline.
  ///
  /// In en, this message translates to:
  /// **'What you do'**
  String get onboardingHeadline;

  /// No description provided for @onboardingHeadlineHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Android dev at Fintio'**
  String get onboardingHeadlineHint;

  /// No description provided for @onboardingInterestsTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you into?'**
  String get onboardingInterestsTitle;

  /// No description provided for @onboardingInterestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We use this to recommend talks and people. Pick a few.'**
  String get onboardingInterestsSubtitle;

  /// No description provided for @onboardingLookingForLabel.
  ///
  /// In en, this message translates to:
  /// **'Who do you want to meet?'**
  String get onboardingLookingForLabel;

  /// No description provided for @onboardingLookingForHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. people who shipped on-device ML'**
  String get onboardingLookingForHint;

  /// No description provided for @onboardingLookingForNote.
  ///
  /// In en, this message translates to:
  /// **'The AI reads this to find your matches.'**
  String get onboardingLookingForNote;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'You decide what others see'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Each switch is separate. You can change them any time in Profile.'**
  String get onboardingPrivacyBody;

  /// No description provided for @showMeInFindSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People at this event can get you as a recommendation.'**
  String get showMeInFindSubtitle;

  /// No description provided for @allowContactRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your details are shared only if you accept.'**
  String get allowContactRequestsSubtitle;

  /// No description provided for @allowMeetingSpotsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Agree on a place to meet. Never your live location.'**
  String get allowMeetingSpotsSubtitle;

  /// No description provided for @onboardingPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your profile only ever goes to the AI to find matches, and only while \"Show me in Find\" is on.'**
  String get onboardingPrivacyNote;

  /// No description provided for @myEventsNow.
  ///
  /// In en, this message translates to:
  /// **'Happening now'**
  String get myEventsNow;

  /// No description provided for @myEventsLiveDay.
  ///
  /// In en, this message translates to:
  /// **'Live · Day 1'**
  String get myEventsLiveDay;

  /// No description provided for @myEventsPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get myEventsPast;

  /// No description provided for @myEventsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open an event link to join your first event.'**
  String get myEventsEmpty;

  /// No description provided for @leaveEvent.
  ///
  /// In en, this message translates to:
  /// **'Leave event'**
  String get leaveEvent;

  /// No description provided for @myEventsNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {session} · {time} · {stage}'**
  String myEventsNext(String session, String time, String stage);

  /// No description provided for @findTitle.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get findTitle;

  /// No description provided for @findSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Describe who you want to meet'**
  String get findSearchHint;

  /// No description provided for @findSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching attendees…'**
  String get findSearching;

  /// No description provided for @findRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get findRecommended;

  /// No description provided for @findFromInterests.
  ///
  /// In en, this message translates to:
  /// **'from your interests'**
  String get findFromInterests;

  /// No description provided for @findTopMatch.
  ///
  /// In en, this message translates to:
  /// **'Top match'**
  String get findTopMatch;

  /// No description provided for @findResultsCaption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person here fits} other{{count} people here fit}} · only people who opted in'**
  String findResultsCaption(int count);

  /// No description provided for @findThinking.
  ///
  /// In en, this message translates to:
  /// **'Finding your best matches…'**
  String get findThinking;

  /// No description provided for @findNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No one matches yet. Try describing it differently.'**
  String get findNoMatches;

  /// No description provided for @personWhyMeet.
  ///
  /// In en, this message translates to:
  /// **'Why you should meet'**
  String get personWhyMeet;

  /// No description provided for @personSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send contact request'**
  String get personSendRequest;

  /// No description provided for @personRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent · waiting…'**
  String get personRequestSent;

  /// No description provided for @personRequestSentTo.
  ///
  /// In en, this message translates to:
  /// **'Request sent · waiting for {name}'**
  String personRequestSentTo(String name);

  /// No description provided for @personDetailsNote.
  ///
  /// In en, this message translates to:
  /// **'Your details are shared only after {name} accepts.'**
  String personDetailsNote(String name);

  /// No description provided for @personAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted · Message'**
  String personAccepted(String name);

  /// No description provided for @messagesMeetAt.
  ///
  /// In en, this message translates to:
  /// **'Meet at {place}'**
  String messagesMeetAt(String place);

  /// No description provided for @messagesSpotWhen.
  ///
  /// In en, this message translates to:
  /// **'{time} · {floor}'**
  String messagesSpotWhen(String time, String floor);

  /// No description provided for @messagesSuggestSpot.
  ///
  /// In en, this message translates to:
  /// **'Suggest a meeting spot'**
  String get messagesSuggestSpot;

  /// No description provided for @messagesMatchedOn.
  ///
  /// In en, this message translates to:
  /// **'Matched on {topics}'**
  String messagesMatchedOn(String topics);

  /// No description provided for @messagesTopicsTwo.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String messagesTopicsTwo(String first, String second);

  /// No description provided for @messagesAcceptedPill.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your contact request'**
  String messagesAcceptedPill(String name);

  /// No description provided for @messagesShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get messagesShowOnMap;

  /// No description provided for @messagesHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messagesHint;

  /// Echo screen title fallback (feature name).
  ///
  /// In en, this message translates to:
  /// **'Echo'**
  String get echoTitle;

  /// Prefilled question when asking about a transcript line.
  ///
  /// In en, this message translates to:
  /// **'What did the speaker mean by: \"{line}\"'**
  String echoAskAboutPrefill(String line);

  /// No description provided for @echoQuestionSent.
  ///
  /// In en, this message translates to:
  /// **'Question sent to the speaker'**
  String get echoQuestionSent;

  /// No description provided for @echoQuestionMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged with a similar question · your vote counts'**
  String get echoQuestionMerged;

  /// No description provided for @echoMergedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 similar question merged} other{{count} similar questions merged}}'**
  String echoMergedCount(int count);

  /// No description provided for @echoJumpToTime.
  ///
  /// In en, this message translates to:
  /// **'Show {time} in the transcript'**
  String echoJumpToTime(String time);

  /// No description provided for @echoShowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get echoShowOriginal;

  /// No description provided for @echoTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate to Serbian'**
  String get echoTranslate;

  /// No description provided for @echoJumpToLive.
  ///
  /// In en, this message translates to:
  /// **'Jump to live'**
  String get echoJumpToLive;

  /// No description provided for @echoQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Questions for the speaker'**
  String get echoQuestionsTitle;

  /// No description provided for @echoYourQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your question'**
  String get echoYourQuestion;

  /// No description provided for @echoFullSummary.
  ///
  /// In en, this message translates to:
  /// **'Full talk summary'**
  String get echoFullSummary;

  /// No description provided for @echoUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get echoUnlocked;

  /// No description provided for @echoPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Premium · AI summary of the whole talk'**
  String get echoPremiumSubtitle;

  /// No description provided for @echoCatchUp.
  ///
  /// In en, this message translates to:
  /// **'Catch up'**
  String get echoCatchUp;

  /// No description provided for @echoCatchUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What was said so far'**
  String get echoCatchUpSubtitle;

  /// No description provided for @echoSummarizing.
  ///
  /// In en, this message translates to:
  /// **'Summarizing…'**
  String get echoSummarizing;

  /// No description provided for @echoNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get echoNotNow;

  /// No description provided for @echoAskAboutThis.
  ///
  /// In en, this message translates to:
  /// **'Ask about this'**
  String get echoAskAboutThis;

  /// No description provided for @echoTalkEnded.
  ///
  /// In en, this message translates to:
  /// **'Talk ended'**
  String get echoTalkEnded;

  /// No description provided for @echoAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get echoAskAi;

  /// No description provided for @echoAskSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Ask speaker'**
  String get echoAskSpeaker;

  /// No description provided for @echoAskHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about this talk…'**
  String get echoAskHint;

  /// No description provided for @echoSpeakerHint.
  ///
  /// In en, this message translates to:
  /// **'Question for the speaker…'**
  String get echoSpeakerHint;

  /// No description provided for @orgNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get orgNewEvent;

  /// No description provided for @orgUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop in whatever you have'**
  String get orgUploadTitle;

  /// No description provided for @orgUploadBody.
  ///
  /// In en, this message translates to:
  /// **'Agenda PDFs, speaker spreadsheets, venue plans, slides. Eho reads them and builds your event.'**
  String get orgUploadBody;

  /// No description provided for @orgChooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get orgChooseFiles;

  /// No description provided for @orgFileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{kb} KB'**
  String orgFileSizeKb(int kb);

  /// No description provided for @orgReading.
  ///
  /// In en, this message translates to:
  /// **'Reading your files and extracting stages, sessions and speakers…'**
  String get orgReading;

  /// No description provided for @orgFoundSoFar.
  ///
  /// In en, this message translates to:
  /// **'Found {stages}, {sessions}, {speakers} so far…'**
  String orgFoundSoFar(String stages, String sessions, String speakers);

  /// No description provided for @orgBuild.
  ///
  /// In en, this message translates to:
  /// **'Build my event with AI'**
  String get orgBuild;

  /// No description provided for @orgStartByUploading.
  ///
  /// In en, this message translates to:
  /// **'Start by uploading files'**
  String get orgStartByUploading;

  /// No description provided for @orgReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review your event'**
  String get orgReviewTitle;

  /// No description provided for @orgStagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stage} other{{count} stages}}'**
  String orgStagesCount(int count);

  /// No description provided for @orgSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String orgSessionsCount(int count);

  /// No description provided for @orgSpeakersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 speaker} other{{count} speakers}}'**
  String orgSpeakersCount(int count);

  /// No description provided for @orgCheckRoomMissing.
  ///
  /// In en, this message translates to:
  /// **'Check: room missing in the PDF'**
  String get orgCheckRoomMissing;

  /// No description provided for @orgSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get orgSessions;

  /// No description provided for @orgEditSession.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get orgEditSession;

  /// No description provided for @orgPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish & get join link'**
  String get orgPublish;

  /// No description provided for @orgTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get orgTitleRequired;

  /// No description provided for @orgEndAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get orgEndAfterStart;

  /// No description provided for @orgTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get orgTitleLabel;

  /// No description provided for @orgStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start {time}'**
  String orgStartTime(String time);

  /// No description provided for @orgEndTime.
  ///
  /// In en, this message translates to:
  /// **'End {time}'**
  String orgEndTime(String time);

  /// No description provided for @orgStageLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get orgStageLabel;

  /// No description provided for @orgPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get orgPublished;

  /// No description provided for @orgIsLive.
  ///
  /// In en, this message translates to:
  /// **'{name} is live'**
  String orgIsLive(String name);

  /// No description provided for @orgShareBody.
  ///
  /// In en, this message translates to:
  /// **'Share this link or print the QR code. Attendees join in one tap, in the app or the browser.'**
  String get orgShareBody;

  /// No description provided for @orgCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get orgCopyLink;

  /// No description provided for @orgLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get orgLinkCopied;

  /// No description provided for @orgOpenAsAttendee.
  ///
  /// In en, this message translates to:
  /// **'Open as attendee'**
  String get orgOpenAsAttendee;

  /// No description provided for @devStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'System status'**
  String get devStatusTitle;

  /// No description provided for @backendLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backendLabel;

  /// No description provided for @authLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign-in'**
  String get authLabel;

  /// No description provided for @statusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get statusOk;

  /// No description provided for @statusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get statusChecking;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String statusError(String message);

  /// No description provided for @signedInAnonymously.
  ///
  /// In en, this message translates to:
  /// **'Anonymous user {uid}'**
  String signedInAnonymously(String uid);

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event {eventId}'**
  String eventTitle(String eventId);

  /// No description provided for @backendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server is not reachable right now. Check your connection and try again.'**
  String get backendUnavailable;

  /// No description provided for @openEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get openEventLabel;

  /// No description provided for @openEvent.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openEvent;

  /// No description provided for @echoThinking.
  ///
  /// In en, this message translates to:
  /// **'Echo is thinking…'**
  String get echoThinking;

  /// No description provided for @echoRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get echoRetry;

  /// No description provided for @echoErrorAiBusy.
  ///
  /// In en, this message translates to:
  /// **'Echo couldn\'t answer right now.'**
  String get echoErrorAiBusy;

  /// No description provided for @echoErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Lots of requests right now. Wait a moment and try again.'**
  String get echoErrorRateLimited;

  /// No description provided for @echoErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'Echo can\'t be reached. Check your connection.'**
  String get echoErrorOffline;

  /// No description provided for @echoErrorNoTranscript.
  ///
  /// In en, this message translates to:
  /// **'This talk has no live transcript yet.'**
  String get echoErrorNoTranscript;

  /// No description provided for @echoErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get echoErrorFailed;

  /// No description provided for @echoWaitingForTalk.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the talk to start…'**
  String get echoWaitingForTalk;

  /// No description provided for @echoTranscriptUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The live transcript isn\'t available right now.'**
  String get echoTranscriptUnavailable;

  /// Echo header overline while the talk is live (upper-cased in the UI).
  ///
  /// In en, this message translates to:
  /// **'Live · {stage}'**
  String echoLiveAt(String stage);

  /// Echo header overline after the talk ended (upper-cased in the UI).
  ///
  /// In en, this message translates to:
  /// **'Ended · {stage}'**
  String echoEndedAt(String stage);

  /// Banner under the Echo header while translate is on.
  ///
  /// In en, this message translates to:
  /// **'Translated live from English · tap SR for the original'**
  String get echoTranslatedBanner;

  /// Ask input placeholder while translate (to Serbian) is on. Intentionally Serbian in every locale.
  ///
  /// In en, this message translates to:
  /// **'Pitajte bilo šta o predavanju…'**
  String get echoAskHintTranslated;

  /// Translate pill label: transcript in the original language.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get echoLangOriginal;

  /// Translate pill label: transcript translated to Serbian.
  ///
  /// In en, this message translates to:
  /// **'SR'**
  String get echoLangTranslated;

  /// No description provided for @echoSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get echoSend;

  /// Q&A sheet title; name is the speaker's first name.
  ///
  /// In en, this message translates to:
  /// **'Questions for {name}'**
  String echoQuestionsFor(String name);

  /// No description provided for @echoQuestionsMeta.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No questions yet} =1{1 question} other{{count} questions}} · shown to the speaker at the end'**
  String echoQuestionsMeta(int count);

  /// Q&A sort chip: most votes first.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get echoSortTop;

  /// Q&A sort chip.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get echoSortNewest;

  /// Q&A sort chip: only my questions.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get echoSortMine;

  /// No description provided for @echoNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions yet. Ask the first one.'**
  String get echoNoQuestions;

  /// No description provided for @echoNoMyQuestions.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t asked anything yet.'**
  String get echoNoMyQuestions;

  /// Ask-speaker input in the Q&A sheet.
  ///
  /// In en, this message translates to:
  /// **'Ask {name} a question…'**
  String echoAskNameHint(String name);

  /// No description provided for @echoUpvote.
  ///
  /// In en, this message translates to:
  /// **'Upvote'**
  String get echoUpvote;

  /// No description provided for @echoSendQuestion.
  ///
  /// In en, this message translates to:
  /// **'Send question'**
  String get echoSendQuestion;

  /// No description provided for @echoPaywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Missed something? Get the whole talk in 2 minutes.'**
  String get echoPaywallTitle;

  /// No description provided for @echoPaywallBody.
  ///
  /// In en, this message translates to:
  /// **'An AI summary with key points, trade-offs and takeaways, built from the full transcript.'**
  String get echoPaywallBody;

  /// No description provided for @echoPaywallThisTalk.
  ///
  /// In en, this message translates to:
  /// **'This talk'**
  String get echoPaywallThisTalk;

  /// No description provided for @echoPaywallEveryTalk.
  ///
  /// In en, this message translates to:
  /// **'Every talk at {event}'**
  String echoPaywallEveryTalk(String event);

  /// No description provided for @echoPaywallEveryTalkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 talk} other{{count} talks}}, all stages'**
  String echoPaywallEveryTalkSubtitle(int count);

  /// Mock price for one talk summary (paywall is mocked; real price TBD).
  ///
  /// In en, this message translates to:
  /// **'€2.99'**
  String get echoPriceTalk;

  /// Mock price for every talk at the event (paywall is mocked; real price TBD).
  ///
  /// In en, this message translates to:
  /// **'€9.99'**
  String get echoPriceEvent;

  /// No description provided for @echoUnlockSummary.
  ///
  /// In en, this message translates to:
  /// **'Unlock summary'**
  String get echoUnlockSummary;

  /// Badge on the summary screen (upper-cased in the UI).
  ///
  /// In en, this message translates to:
  /// **'AI summary · Premium'**
  String get echoSummaryBadge;

  /// Overline of the dark takeaway card (upper-cased in the UI).
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get echoTakeaway;

  /// No description provided for @echoKeyPoints.
  ///
  /// In en, this message translates to:
  /// **'Key points'**
  String get echoKeyPoints;

  /// No description provided for @echoTradeoffs.
  ///
  /// In en, this message translates to:
  /// **'Trade-offs and fixes'**
  String get echoTradeoffs;

  /// No description provided for @echoTalkMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min talk'**
  String echoTalkMinutes(int minutes);

  /// No description provided for @echoReadMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read'**
  String echoReadMinutes(int minutes);

  /// No description provided for @echoCopySummary.
  ///
  /// In en, this message translates to:
  /// **'Copy summary'**
  String get echoCopySummary;

  /// No description provided for @echoSummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Summary copied'**
  String get echoSummaryCopied;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
