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
      'Your AI companion for events. The agenda, the venue, every talk, and the people worth meeting.';

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
  String mapSheetCapacity(int count) {
    return 'up to $count seats';
  }

  @override
  String mapSheetWalkMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String mapSheetWalkDistance(int meters) {
    return '~$meters m walk';
  }

  @override
  String mapSheetNow(String start, String end) {
    return 'Now · $start–$end';
  }

  @override
  String mapSheetNext(String start) {
    return 'Next · $start';
  }

  @override
  String get mapSheetStartRoute => 'Start route';

  @override
  String get mapSheetOpenEcho => 'Open Echo';

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
  String get agendaLiveEchoOn => 'Live now · Echo on';

  @override
  String get agendaLiveNow => 'Live now';

  @override
  String get agendaEchoOnTitle => 'Echo is on for this talk';

  @override
  String get agendaEchoOnBody =>
      'Live transcript, translation, ask the AI about what was said, and send questions to the speaker.';

  @override
  String get sessionOpenEcho => 'Open Echo';

  @override
  String sessionTrack(String track) {
    return '$track track';
  }

  @override
  String get sessionSave => 'Save to my agenda';

  @override
  String get sessionSaved => 'Remove from my agenda';

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
  String get joinPerkMap => 'Venue map and directions';

  @override
  String get joinPerkEcho => 'Live transcripts and AI answers in every talk';

  @override
  String get joinPerkFind => 'Find the people worth meeting';

  @override
  String get joinWithEho => 'With Eho you get';

  @override
  String get joinJoining => 'Joining…';

  @override
  String onboardingStep(int step, int total) {
    return '$step of $total';
  }

  @override
  String get onboardingWhoTitle => 'Who are you?';

  @override
  String get onboardingWhoSubtitle =>
      'This is how other attendees see you in Find. Only if you choose to be visible.';

  @override
  String get onboardingName => 'Name';

  @override
  String get onboardingHeadline => 'What you do';

  @override
  String get onboardingHeadlineHint => 'e.g. Android dev at Fintio';

  @override
  String get onboardingInterestsTitle => 'What are you into?';

  @override
  String get onboardingInterestsSubtitle =>
      'We use this to recommend talks and people. Pick a few.';

  @override
  String get onboardingLookingForLabel => 'Who do you want to meet?';

  @override
  String get onboardingLookingForHint => 'e.g. people who shipped on-device ML';

  @override
  String get onboardingLookingForNote =>
      'The AI reads this to find your matches.';

  @override
  String get onboardingPrivacyTitle => 'You decide what others see';

  @override
  String get onboardingPrivacyBody =>
      'Each switch is separate. You can change them any time in Profile.';

  @override
  String get showMeInFindSubtitle =>
      'People at this event can get you as a recommendation.';

  @override
  String get allowContactRequestsSubtitle =>
      'Your details are shared only if you accept.';

  @override
  String get allowMeetingSpotsSubtitle =>
      'Agree on a place to meet. Never your live location.';

  @override
  String get onboardingPrivacyNote =>
      'Your profile only ever goes to the AI to find matches, and only while \"Show me in Find\" is on.';

  @override
  String get myEventsNow => 'Happening now';

  @override
  String get myEventsLiveDay => 'Live · Day 1';

  @override
  String get myEventsPast => 'Past';

  @override
  String get myEventsEmpty => 'Open an event link to join your first event.';

  @override
  String get leaveEvent => 'Leave event';

  @override
  String myEventsNext(String session, String time, String stage) {
    return 'Next: $session · $time · $stage';
  }

  @override
  String get findTitle => 'Find people';

  @override
  String get findSearchHint => 'Describe who you want to meet';

  @override
  String get findSearching => 'Searching attendees…';

  @override
  String get findRecommended => 'Recommended for you';

  @override
  String get findFromInterests => 'from your interests';

  @override
  String get findTopMatch => 'Top match';

  @override
  String findResultsCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people here fit',
      one: '1 person here fits',
    );
    return '$_temp0 · only people who opted in';
  }

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
  String personRequestSentTo(String name) {
    return 'Request sent · waiting for $name';
  }

  @override
  String personDetailsNote(String name) {
    return 'Your details are shared only after $name accepts.';
  }

  @override
  String personAccepted(String name) {
    return '$name accepted · Message';
  }

  @override
  String messagesMeetAt(String place) {
    return 'Meet at $place';
  }

  @override
  String messagesSpotWhen(String time, String floor) {
    return '$time · $floor';
  }

  @override
  String get messagesSuggestSpot => 'Suggest a meeting spot';

  @override
  String messagesMatchedOn(String topics) {
    return 'Matched on $topics';
  }

  @override
  String messagesTopicsTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String messagesAcceptedPill(String name) {
    return '$name accepted your contact request';
  }

  @override
  String get messagesShowOnMap => 'Show on map';

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
  String get echoQuestionMerged =>
      'Merged with a similar question · your vote counts';

  @override
  String echoMergedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count similar questions merged',
      one: '1 similar question merged',
    );
    return '$_temp0';
  }

  @override
  String echoJumpToTime(String time) {
    return 'Show $time in the transcript';
  }

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
  String get echoNotNow => 'Not now';

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
  String orgFoundSoFar(String stages, String sessions, String speakers) {
    return 'Found $stages, $sessions, $speakers so far…';
  }

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
  String get orgCheckRoomMissing => 'Check: room missing in the PDF';

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

  @override
  String echoLiveAt(String stage) {
    return 'Live · $stage';
  }

  @override
  String echoEndedAt(String stage) {
    return 'Ended · $stage';
  }

  @override
  String get echoTranslatedBanner =>
      'Translated live from English · tap SR for the original';

  @override
  String get echoAskHintTranslated => 'Pitajte bilo šta o predavanju…';

  @override
  String get echoLangOriginal => 'EN';

  @override
  String get echoLangTranslated => 'SR';

  @override
  String get echoSend => 'Send';

  @override
  String echoQuestionsFor(String name) {
    return 'Questions for $name';
  }

  @override
  String echoQuestionsMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
      zero: 'No questions yet',
    );
    return '$_temp0 · shown to the speaker at the end';
  }

  @override
  String get echoSortTop => 'Top';

  @override
  String get echoSortNewest => 'Newest';

  @override
  String get echoSortMine => 'Mine';

  @override
  String get echoNoQuestions => 'No questions yet. Ask the first one.';

  @override
  String get echoNoMyQuestions => 'You haven\'t asked anything yet.';

  @override
  String echoAskNameHint(String name) {
    return 'Ask $name a question…';
  }

  @override
  String get echoUpvote => 'Upvote';

  @override
  String get echoSendQuestion => 'Send question';

  @override
  String get echoPaywallTitle =>
      'Missed something? Get the whole talk in 2 minutes.';

  @override
  String get echoPaywallBody =>
      'An AI summary with key points, trade-offs and takeaways, built from the full transcript.';

  @override
  String get echoPaywallThisTalk => 'This talk';

  @override
  String echoPaywallEveryTalk(String event) {
    return 'Every talk at $event';
  }

  @override
  String echoPaywallEveryTalkSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count talks',
      one: '1 talk',
    );
    return '$_temp0, all stages';
  }

  @override
  String get echoPriceTalk => '€2.99';

  @override
  String get echoPriceEvent => '€9.99';

  @override
  String get echoUnlockSummary => 'Unlock summary';

  @override
  String get echoSummaryBadge => 'AI summary · Premium';

  @override
  String get echoTakeaway => 'Takeaway';

  @override
  String get echoKeyPoints => 'Key points';

  @override
  String get echoTradeoffs => 'Trade-offs and fixes';

  @override
  String echoTalkMinutes(int minutes) {
    return '$minutes min talk';
  }

  @override
  String echoReadMinutes(int minutes) {
    return '$minutes min read';
  }

  @override
  String get echoCopySummary => 'Copy summary';

  @override
  String get echoSummaryCopied => 'Summary copied';
}
