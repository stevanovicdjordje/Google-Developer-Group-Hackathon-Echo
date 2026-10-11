/// Data access for the non-map parts of the app.
///
/// Each interface maps to a backend need listed in `mobile/docs/api-needs.md`.
/// Today every provider below returns a demo implementation with hardcoded
/// data; when an endpoint lands, swap the provider to an HTTP implementation
/// (see `core/api/api_client.dart`) without touching the screens.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import 'app_state.dart' show profileProvider;
import 'demo_data.dart' as demo;
import 'echo_api_repository.dart';
import 'echo_models.dart';
import 'find_api_repository.dart';
import 'models.dart';

// ---------------------------------------------------------------- interfaces

abstract interface class EventRepository {
  /// Event shown on the join screen for `/e/{eventId}`. [API-1]
  Future<EventSummary> getEvent(String eventId);

  /// Registers the current user for the event. [API-2]
  Future<void> join(String eventId);

  /// Agenda of an event. [API-3]
  Future<List<Session>> agenda(String eventId);

  /// Topics offered in onboarding and on the profile.
  List<String> get interestOptions;
}

abstract interface class EchoRepository {
  /// Live transcript of a session. [API-4]
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId);

  /// Short rolling "catch up" summary of the talk so far, written in
  /// [language] (`contracts/echo` `Language`, e.g. `en`, `sr`). [API-5]
  Future<String> catchUp(
    String eventId,
    String sessionId, {
    String language = 'en',
  });

  /// Answer a question about the talk, grounded in the transcript, in
  /// [language]. [API-6]
  Future<String> ask(
    String eventId,
    String sessionId,
    String question, {
    String language = 'en',
  });

  /// Audience questions for the speaker. [API-7]
  Future<List<SpeakerQuestion>> questions(String eventId, String sessionId);

  /// Submit a question for the speaker. The server may merge it into a
  /// similar existing question (`merged`). [API-7]
  Future<QuestionSubmission> submitQuestion(
    String eventId,
    String sessionId,
    String text,
  );

  /// Add ([up]) or take back the current user's vote; returns the question
  /// as it is now. [API-7]
  Future<SpeakerQuestion> vote(
    String eventId,
    String sessionId,
    SpeakerQuestion question, {
    required bool up,
  });

  /// Full post-talk summary (premium), in [language]. [API-8]
  Future<EchoSummary> fullSummary(
    String eventId,
    String sessionId, {
    String language = 'en',
  });

  /// Translations of the transcript lines from [fromIndex] on (a line's index
  /// is its position in [transcript]). Call again from `nextIndex` when new
  /// lines arrive. [translation]
  Future<TranscriptTranslation> translate(
    String eventId,
    String sessionId, {
    required String language,
    int fromIndex = 0,
  });
}

/// Translated lines by index, and the first index not translated yet.
typedef TranscriptTranslation = ({Map<int, String> lines, int nextIndex});

enum EchoErrorKind {
  /// The AI failed or was too slow; safe to retry.
  aiBusy,

  /// Too many requests; retry after [EchoException.retryAfter].
  rateLimited,

  /// The service can't be reached.
  offline,

  /// The session has no transcript (yet).
  noTranscript,
  failed,
}

/// Failure of an [EchoRepository] call, for the screen to explain.
class EchoException implements Exception {
  const EchoException(this.kind, [this.message = '', this.retryAfter]);

  final EchoErrorKind kind;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => 'EchoException(${kind.name}): $message';
}

abstract interface class FindRepository {
  /// Saves the attendee's profile and consent switches, exactly as set.
  /// Does nothing until onboarding is done ([Profile.onboarded]). [API-14]
  Future<void> saveProfile(Profile profile);

  /// Deletes the profile, event presence and contacts on the server
  /// (`DATA_PRIVACY.md` -> Deletion). No screen offers it yet.
  Future<void> deleteProfile();

  /// AI-ranked people to meet, based on the user's profile. [API-9]
  Future<List<PersonMatch>> recommendations(String eventId, Profile me);

  /// AI people search from a free-text prompt. [API-10]
  Future<List<PersonMatch>> search(String eventId, String prompt);

  /// One person at the event; null when they aren't (or no longer) visible.
  Future<PersonDetail?> person(String eventId, String personId);

  /// Send a contact request; emits the contact state as it changes
  /// (`requested`, then `accepted` when the person accepts). [API-11]
  Stream<ContactState> requestContact(String eventId, String personId);

  /// Agree on [place] (a feature name on the venue map) with an accepted
  /// contact; returns the place as stored (the map's spelling). [API-15]
  Future<String> setMeetingSpot(String eventId, String personId, String place);
}

enum FindErrorKind {
  /// The service can't be reached.
  offline,

  /// Too many AI requests; retry after [FindException.retryAfter].
  rateLimited,

  /// The AI failed or was too slow; safe to retry.
  aiBusy,

  /// The person isn't visible (or the event isn't published).
  notFound,

  /// The person doesn't take contact requests, or a meeting spot isn't
  /// allowed (both sides need the switch on).
  notAllowed,

  /// No saved profile yet (onboarding not done).
  profileRequired,
  failed,
}

/// Failure of a [FindRepository] call, for the screen to explain.
class FindException implements Exception {
  const FindException(this.kind, [this.message = '', this.retryAfter]);

  final FindErrorKind kind;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => 'FindException(${kind.name}): $message';
}

abstract interface class OrganizerRepository {
  /// Upload files and let the AI extract the event. [API-12]
  Future<EventDraft> extract(List<UploadedFile> files);

  /// Publish the draft and get the join link. [API-13]
  Future<PublishedLink> publish(EventDraft draft);
}

// ---------------------------------------------------------- demo versions

Future<void> _think([int ms = 900]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Event ID the demo used before the rename to DevFest. Old QR codes and
/// links still point at it, so it resolves to the demo event.
const _legacyDemoEventId = 'devsummit';

String _canonicalEventId(String eventId) =>
    eventId == _legacyDemoEventId ? demoEventId : eventId;

/// Lowercases only the first letter so acronyms and names survive
/// ("on-device ML", "senior Go engineers").
String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

class DemoEventRepository implements EventRepository {
  @override
  List<String> get interestOptions => demo.interestOptions;

  @override
  Future<EventSummary> getEvent(String eventId) async {
    await _think(300);
    if (eventId == demo.pastEvent.id) return demo.pastEvent;
    return EventSummary(
      id: _canonicalEventId(eventId),
      name: demo.demoEventName,
      dates: demo.demoEventDates,
      venue: demo.demoEventVenue,
    );
  }

  @override
  Future<void> join(String eventId) => _think(400);

  @override
  Future<List<Session>> agenda(String eventId) async {
    await _think(300);
    return demo.sessions;
  }
}

class DemoEchoRepository implements EchoRepository {
  /// Seconds of transcript per real second; speeds up the replay for the video.
  static const replaySpeed = 2;

  @override
  Stream<List<TranscriptLine>> transcript(
    String eventId,
    String sessionId,
  ) async* {
    final shown = <TranscriptLine>[];
    var elapsed = 0;
    for (final line in demo.keynoteTranscript) {
      final wait = (line.atSeconds - elapsed) * 1000 ~/ replaySpeed;
      if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      elapsed = line.atSeconds;
      shown.add(line);
      yield List.unmodifiable(shown);
    }
  }

  @override
  Future<String> catchUp(
    String eventId,
    String sessionId, {
    String language = 'en',
  }) async {
    await _think(500);
    return language == 'sr' ? demo.keynoteCatchUpSr : demo.keynoteCatchUp;
  }

  @override
  Future<String> ask(
    String eventId,
    String sessionId,
    String question, {
    String language = 'en',
  }) async {
    await _think(1400);
    final sr = language == 'sr';
    final q = question.toLowerCase();
    for (final entry in demo.keynoteAnswers.entries) {
      final serbian = demo.keynoteAnswerKeywordsSr[entry.key] ?? entry.key;
      if (q.contains(entry.key) || q.contains(serbian)) {
        return sr ? demo.keynoteAnswersSr[entry.key]! : entry.value;
      }
    }
    return sr ? demo.keynoteDefaultAnswerSr : demo.keynoteDefaultAnswer;
  }

  @override
  Future<List<SpeakerQuestion>> questions(
    String eventId,
    String sessionId,
  ) async {
    await _think(300);
    return [
      for (final (id, text, votes, merged, mine, voted)
          in demo.keynoteQuestions)
        SpeakerQuestion(
          id: id,
          text: text,
          votes: votes,
          mergedCount: merged,
          mine: mine,
          voted: voted,
        ),
    ];
  }

  /// Like the server's AI grouping, but by keyword: a question that mentions
  /// [demo.keynoteMergeKeyword] is merged into the first demo question.
  @override
  Future<QuestionSubmission> submitQuestion(
    String eventId,
    String sessionId,
    String text,
  ) async {
    await _think(400);
    if (text.toLowerCase().contains(demo.keynoteMergeKeyword)) {
      final (id, original, votes, merged, _, _) = demo.keynoteQuestions.first;
      return QuestionSubmission(
        SpeakerQuestion(
          id: id,
          text: original,
          votes: votes + 1,
          mine: true,
          voted: true,
          mergedCount: merged + 1,
        ),
        merged: true,
      );
    }
    return QuestionSubmission(
      SpeakerQuestion(
        id: 'mine-${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        votes: 1,
        mine: true,
        voted: true,
      ),
    );
  }

  @override
  Future<SpeakerQuestion> vote(
    String eventId,
    String sessionId,
    SpeakerQuestion question, {
    required bool up,
  }) async {
    await _think(200);
    final change = up == question.voted ? 0 : (up ? 1 : -1);
    return SpeakerQuestion(
      id: question.id,
      text: question.text,
      votes: (question.votes + change).clamp(0, 1 << 30),
      mine: question.mine,
      voted: up,
      mergedCount: question.mergedCount,
    );
  }

  @override
  Future<EchoSummary> fullSummary(
    String eventId,
    String sessionId, {
    String language = 'en',
  }) async {
    await _think(1600);
    return language == 'sr'
        ? const EchoSummary(
            text: demo.keynoteSummaryTextSr,
            summary: demo.keynoteTalkSummarySr,
          )
        : const EchoSummary(
            text: demo.keynoteSummary,
            summary: demo.keynoteTalkSummary,
          );
  }

  @override
  Future<TranscriptTranslation> translate(
    String eventId,
    String sessionId, {
    required String language,
    int fromIndex = 0,
  }) async {
    await _think(300);
    final lines = demo.keynoteTranscript;
    return (
      lines: {
        for (var i = fromIndex; i < lines.length; i++) i: lines[i].translated,
      },
      nextIndex: lines.length,
    );
  }
}

class DemoFindRepository implements FindRepository {
  /// Most shared interests first, ties in [demo.recommendationOrder]; the
  /// reasons are the hand-written [demo.fitLines]. Speakers are left out.
  @override
  Future<List<PersonMatch>> recommendations(String eventId, Profile me) async {
    await _think(1500);
    final mine = me.interests.toSet();
    int rank(String id) {
      final i = demo.recommendationOrder.indexOf(id);
      return i < 0 ? demo.recommendationOrder.length : i;
    }

    final scored =
        [
          for (final p in demo.people)
            if (!demo.speakerPersonIds.contains(p.id))
              (p, p.interests.where(mine.contains).length),
        ]..sort((a, b) {
          final byScore = b.$2.compareTo(a.$2);
          return byScore != 0
              ? byScore
              : rank(a.$1.id).compareTo(rank(b.$1.id));
        });
    return [
      for (final (p, _) in scored.take(3)) PersonMatch(person: p, why: _fit(p)),
    ];
  }

  /// A canned result set from [demo.demoSearches] when the prompt mentions
  /// one of its keywords, otherwise people whose profile mentions the
  /// prompt's words.
  @override
  Future<List<PersonMatch>> search(String eventId, String prompt) async {
    await _think(1700);
    final text = prompt.toLowerCase();
    for (final (keywords, results) in demo.demoSearches) {
      if (keywords.any(
        (k) =>
            RegExp('(^|[^a-z])${RegExp.escape(k)}(\$|[^a-z])').hasMatch(text),
      )) {
        return [
          for (final (id, why) in results)
            PersonMatch(
              person: demo.people.firstWhere((p) => p.id == id),
              why: why,
            ),
        ];
      }
    }
    final words = text
        .split(RegExp(r'[^a-zšđčćž0-9]+'))
        .where((w) => w.length > 2)
        .toSet();
    final scored = [
      for (final p in demo.people)
        (
          p,
          words
              .where(
                (w) => '${p.headline} ${p.interests.join(' ')} ${p.lookingFor}'
                    .toLowerCase()
                    .contains(w),
              )
              .length,
        ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (p, _) in scored.where((s) => s.$2 > 0).take(3))
        PersonMatch(person: p, why: _fit(p)),
    ];
  }

  String _fit(Person p) =>
      demo.fitLines[p.id] ??
      '${p.headline}. Looking for ${_lowerFirst(p.lookingFor)}.';

  @override
  Future<PersonDetail?> person(String eventId, String personId) async {
    final p = demo.people.where((p) => p.id == personId).firstOrNull;
    return p == null ? null : PersonDetail(person: p);
  }

  /// Demo: the other person accepts shortly after the request.
  @override
  Stream<ContactState> requestContact(String eventId, String personId) async* {
    await _think(500);
    yield ContactState.requested;
    await Future<void>.delayed(const Duration(seconds: 2));
    yield ContactState.accepted;
  }

  @override
  Future<void> saveProfile(Profile profile) async {}

  @override
  Future<void> deleteProfile() async {}

  @override
  Future<String> setMeetingSpot(
    String eventId,
    String personId,
    String place,
  ) async => place;
}

class DemoOrganizerRepository implements OrganizerRepository {
  DemoOrganizerRepository(this.demoEventId, this.linkBase);

  /// Event ID the demo "publishes" to (the seeded venue-map event).
  final String demoEventId;
  final String linkBase;

  @override
  Future<EventDraft> extract(List<UploadedFile> files) async {
    await _think(2600);
    return EventDraft(
      name: demo.demoEventName,
      dates: demo.demoEventDates,
      venue: demo.demoEventVenue,
      stages: demo.stages,
      sessions: demo.sessions.where((s) => !s.isBreak).toList(),
      speakers: demo.speakers,
    );
  }

  @override
  Future<PublishedLink> publish(EventDraft draft) async {
    await _think(1000);
    return PublishedLink(eventId: demoEventId, url: '$linkBase/e/$demoEventId');
  }
}

// ---------------------------------------------------------------- providers

/// Event ID used by the demo. Set it to the ID printed by
/// `cd backend/maps && make seed` so the Map tab shows the real venue:
/// `--dart-define=DEMO_EVENT_ID=<id>`.
const demoEventId = String.fromEnvironment(
  'DEMO_EVENT_ID',
  defaultValue: 'devfest',
);

/// Base URL for join links. On web, the app's own origin.
String linkBase() {
  final base = Uri.base;
  if (base.scheme.startsWith('http')) return base.origin;
  return const String.fromEnvironment(
    'LINK_BASE',
    defaultValue: 'https://eho.app',
  );
}

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => DemoEventRepository(),
);

/// Interest topics for onboarding and the profile.
final interestOptionsProvider = Provider<List<String>>(
  (ref) => ref.watch(eventRepositoryProvider).interestOptions,
);

/// Echo API when enabled (`USE_ECHO_API`, default on), Firebase is up and
/// the service answers `/healthz`; demo data otherwise (and in tests).
final echoRepositoryProvider = Provider<EchoRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useEchoApi || !_firebaseReady()) return DemoEchoRepository();
  final token = anonymousIdToken(ref.watch(firebaseAuthProvider));
  return FallbackEchoRepository(
    primary: EchoApiRepository(
      baseUrl: config.echoApiBaseUrl,
      tokenProvider: token,
      transcriptSource: FirestoreEchoTranscriptSource(
        FirebaseFirestore.instance,
        token,
      ),
    ),
    fallback: DemoEchoRepository(),
  );
});

bool _firebaseReady() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Find API when enabled (`USE_FIND_API`, default on), Firebase is up and
/// the service answers `/healthz`; demo data otherwise (and in tests).
final findRepositoryProvider = Provider<FindRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useFindApi || !_firebaseReady()) return DemoFindRepository();
  return FallbackFindRepository(
    primary: FindApiRepository(
      baseUrl: config.findApiBaseUrl,
      tokenProvider: anonymousIdToken(ref.watch(firebaseAuthProvider)),
      // Read when the service needs the profile first (before `joinFind`).
      profile: () => ref.read(profileProvider),
    ),
    fallback: DemoFindRepository(),
  );
});
final organizerRepositoryProvider = Provider<OrganizerRepository>(
  (ref) => DemoOrganizerRepository(demoEventId, linkBase()),
);
