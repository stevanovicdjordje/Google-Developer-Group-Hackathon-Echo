// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Eho';

  @override
  String get cancel => 'Cancel';

  @override
  String get open => 'Open';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get continueButton => 'Continue';

  @override
  String get myEvents => 'My events';

  @override
  String get joinEvent => 'Join event';

  @override
  String get lookingFor => 'Looking for';

  @override
  String get showMeInFind => 'Show me in Find';

  @override
  String get allowContactRequests => 'Allow contact requests';

  @override
  String get allowMeetingSpots => 'Allow meeting spots';

  @override
  String get startTagline =>
      'Your AI companion for events: agenda, venue, talks and people.';

  @override
  String get startJoinButton => 'Join with a link or code';

  @override
  String get startOrganizerButton => 'I\'m an organizer';

  @override
  String get joinDialogTitle => 'Join an event';

  @override
  String get joinDialogLabel => 'Event link or code';

  @override
  String get tabAgenda => 'Agenda';

  @override
  String get tabMap => 'Map';

  @override
  String get tabFind => 'Find';

  @override
  String get tabProfile => 'Profile';

  @override
  String mapMeetingHighlight(String name) {
    return 'Meeting: $name';
  }

  @override
  String mapMeetingTitle(String name) {
    return 'Meeting $name';
  }

  @override
  String mapMeetingAt(String place) {
    return 'at $place';
  }

  @override
  String get mapShowSpot => 'Show';

  @override
  String get profileYourName => 'Your name';

  @override
  String get profilePrivacy => 'Privacy';

  @override
  String profileJoinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count joined',
      one: '1 joined',
    );
    return '$_temp0';
  }

  @override
  String get profileTalkSummaries => 'Talk summaries';

  @override
  String profileUnlockedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unlocked',
      one: '1 unlocked',
    );
    return '$_temp0';
  }

  @override
  String get profileForOrganizers => 'For organizers';

  @override
  String get profileCreateEvent => 'Create event';

  @override
  String get profileEditVenueMap => 'Edit venue map';

  @override
  String get agendaAllStages => 'All stages';

  @override
  String get sessionOpenEcho => 'Open Echo: live transcript & AI';

  @override
  String sessionShowOnMap(String stage) {
    return 'Show $stage on map';
  }

  @override
  String joinLoadError(String error) {
    return 'Could not load event: $error';
  }

  @override
  String get joinInvited => 'You\'re invited to';

  @override
  String get joinPerkAgenda => 'Agenda for every stage';

  @override
  String get joinPerkMap => 'Venue map';

  @override
  String get joinPerkEcho => 'Live transcripts and AI answers in every talk';

  @override
  String get joinPerkFind => 'Find the people worth meeting';

  @override
  String get joinJoining => 'Joining…';

  @override
  String onboardingStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingWhoTitle => 'Who are you?';

  @override
  String get onboardingName => 'Name';

  @override
  String get onboardingHeadline => 'What you do';

  @override
  String get onboardingHeadlineHint => 'e.g. Android dev at Fintio';

  @override
  String get onboardingInterestsTitle => 'What are you into?';

  @override
  String get onboardingLookingForLabel => 'Who do you want to meet?';

  @override
  String get onboardingLookingForHint => 'e.g. people who shipped on-device ML';

  @override
  String get onboardingPrivacyTitle => 'You decide what others see';

  @override
  String get onboardingPrivacyBody =>
      'You can change these any time in Profile.';

  @override
  String get showMeInFindSubtitle =>
      'Others at this event can get you as a recommendation.';

  @override
  String get allowContactRequestsSubtitle =>
      'Your details are shared only if you accept.';

  @override
  String get allowMeetingSpotsSubtitle =>
      'Agree on a place to meet. Never your live location.';

  @override
  String get myEventsUpcoming => 'Now & upcoming';

  @override
  String get myEventsPast => 'Past';

  @override
  String get myEventsEmpty => 'Open an event link to join your first event.';

  @override
  String get leaveEvent => 'Leave event';

  @override
  String get findTitle => 'Find people';

  @override
  String get findSearchHint => 'Describe who you want to meet…';

  @override
  String findResultsFor(String query) {
    return 'Results for \"$query\"';
  }

  @override
  String get findSearching => 'Searching attendees…';

  @override
  String get findRecommended => 'Recommended for you';

  @override
  String get findThinking => 'Finding your best matches…';

  @override
  String get findNoMatches =>
      'No one matches yet. Try describing it differently.';

  @override
  String get personWhyMeet => 'Why you should meet';

  @override
  String get personSendRequest => 'Send contact request';

  @override
  String get personRequestSent => 'Request sent · waiting…';

  @override
  String personAccepted(String name) {
    return '$name accepted · Message';
  }

  @override
  String messagesMeetAt(String place) {
    return '📍 Let\'s meet at $place';
  }

  @override
  String get messagesSuggestSpot => 'Suggest a meeting spot';

  @override
  String get messagesHint => 'Message';

  @override
  String get echoTitle => 'Echo';

  @override
  String echoAskAboutPrefill(String line) {
    return 'What did the speaker mean by: \"$line\"';
  }

  @override
  String get echoQuestionSent => 'Question sent to the speaker';

  @override
  String get echoShowOriginal => 'Show original';

  @override
  String get echoTranslate => 'Translate to Serbian';

  @override
  String get echoJumpToLive => 'Jump to live';

  @override
  String get echoQuestionsTitle => 'Questions for the speaker';

  @override
  String get echoYourQuestion => 'Your question';

  @override
  String get echoFullSummary => 'Full talk summary';

  @override
  String get echoUnlocked => 'Unlocked';

  @override
  String get echoPremiumSubtitle => 'Premium · AI summary of the whole talk';

  @override
  String get echoCatchUp => 'Catch up';

  @override
  String get echoCatchUpSubtitle => 'What was said so far';

  @override
  String get echoSummarizing => 'Summarizing…';

  @override
  String get echoUnlockTitle => 'Unlock talk summaries';

  @override
  String get echoUnlockBody =>
      'Get an AI summary of every talk at this event: key points, trade-offs and takeaways.';

  @override
  String get echoNotNow => 'Not now';

  @override
  String get echoUnlockPrice => 'Unlock · €2.99';

  @override
  String get echoAskAboutThis => 'Ask about this';

  @override
  String get echoTalkEnded => 'Talk ended';

  @override
  String get echoAskAi => 'Ask AI';

  @override
  String get echoAskSpeaker => 'Ask speaker';

  @override
  String get echoAskHint => 'Ask about this talk…';

  @override
  String get echoSpeakerHint => 'Question for the speaker…';

  @override
  String get orgNewEvent => 'New event';

  @override
  String get orgUploadTitle => 'Drop in whatever you have';

  @override
  String get orgUploadBody =>
      'Agenda PDFs, speaker spreadsheets, venue plans, slides. Eho reads them and builds your event.';

  @override
  String get orgChooseFiles => 'Choose files';

  @override
  String orgFileSizeKb(int kb) {
    return '$kb KB';
  }

  @override
  String get orgReading =>
      'Reading your files and extracting stages, sessions and speakers…';

  @override
  String get orgBuild => 'Build my event with AI';

  @override
  String get orgStartByUploading => 'Start by uploading files';

  @override
  String get orgReviewTitle => 'Review your event';

  @override
  String orgStagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stages',
      one: '1 stage',
    );
    return '$_temp0';
  }

  @override
  String orgSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String orgSpeakersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count speakers',
      one: '1 speaker',
    );
    return '$_temp0';
  }

  @override
  String get orgSessions => 'Sessions';

  @override
  String get orgEditSession => 'Edit session';

  @override
  String get orgPublish => 'Publish & get join link';

  @override
  String get orgTitleRequired => 'Title is required';

  @override
  String get orgEndAfterStart => 'End must be after start';

  @override
  String get orgTitleLabel => 'Title';

  @override
  String orgStartTime(String time) {
    return 'Start $time';
  }

  @override
  String orgEndTime(String time) {
    return 'End $time';
  }

  @override
  String get orgStageLabel => 'Stage';

  @override
  String get orgPublished => 'Published';

  @override
  String orgIsLive(String name) {
    return '$name is live';
  }

  @override
  String get orgShareBody =>
      'Share this link or print the QR code. Attendees join in one tap, in the app or the browser.';

  @override
  String get orgCopyLink => 'Copy link';

  @override
  String get orgLinkCopied => 'Link copied';

  @override
  String get orgOpenAsAttendee => 'Open as attendee';

  @override
  String get devStatusTitle => 'System status';

  @override
  String get backendLabel => 'Backend';

  @override
  String get authLabel => 'Sign-in';

  @override
  String get statusOk => 'OK';

  @override
  String get statusChecking => 'Checking…';

  @override
  String statusError(String message) {
    return 'Error: $message';
  }

  @override
  String signedInAnonymously(String uid) {
    return 'Anonymous user $uid';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get retry => 'Try again';

  @override
  String eventTitle(String eventId) {
    return 'Event $eventId';
  }

  @override
  String get backendUnavailable =>
      'The server is not reachable right now. Check your connection and try again.';

  @override
  String get openEventLabel => 'Event ID';

  @override
  String get openEvent => 'Open map';

  @override
  String get echoThinking => 'Echo is thinking…';

  @override
  String get echoRetry => 'Try again';

  @override
  String get echoErrorAiBusy => 'Echo couldn\'t answer right now.';

  @override
  String get echoErrorRateLimited =>
      'Lots of requests right now. Wait a moment and try again.';

  @override
  String get echoErrorOffline =>
      'Echo can\'t be reached. Check your connection.';

  @override
  String get echoErrorNoTranscript => 'This talk has no live transcript yet.';

  @override
  String get echoErrorFailed => 'Something went wrong.';

  @override
  String get echoWaitingForTalk => 'Waiting for the talk to start…';

  @override
  String get echoTranscriptUnavailable =>
      'The live transcript isn\'t available right now.';
}
