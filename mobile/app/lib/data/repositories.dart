/// Data access for the non-map parts of the app.
///
/// Each interface maps to a backend need listed in `mobile/docs/api-needs.md`.
/// Today every provider below returns a demo implementation with hardcoded
/// data; when an endpoint lands, swap the provider to an HTTP implementation
/// (see `core/api/api_client.dart`) without touching the screens.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart' as demo;
import 'models.dart';

// ---------------------------------------------------------------- interfaces

abstract interface class EventRepository {
  /// Event shown on the join screen for `/e/{eventId}`. [API-1]
  Future<EventSummary> getEvent(String eventId);

  /// Registers the current user for the event. [API-2]
  Future<void> join(String eventId);

  /// Agenda of an event. [API-3]
  Future<List<Session>> agenda(String eventId);
}

abstract interface class EchoRepository {
  /// Live transcript of a session. [API-4]
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId);

  /// Short rolling "catch up" summary of the talk so far. [API-5]
  Future<String> catchUp(String eventId, String sessionId);

  /// Answer a question about the talk, grounded in the transcript. [API-6]
  Future<String> ask(String eventId, String sessionId, String question);

  /// Audience questions for the speaker. [API-7]
  Future<List<SpeakerQuestion>> questions(String eventId, String sessionId);

  /// Submit a question for the speaker. [API-7]
  Future<SpeakerQuestion> submitQuestion(
    String eventId,
    String sessionId,
    String text,
  );

  /// Full post-talk summary (premium). [API-8]
  Future<String> fullSummary(String eventId, String sessionId);
}

abstract interface class FindRepository {
  /// AI-ranked people to meet, based on the user's profile. [API-9]
  Future<List<PersonMatch>> recommendations(String eventId, Profile me);

  /// AI people search from a free-text prompt. [API-10]
  Future<List<PersonMatch>> search(String eventId, String prompt);

  Future<Person> person(String eventId, String personId);

  /// Send a contact request. [API-11]
  Future<void> requestContact(String eventId, String personId);
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

class DemoEventRepository implements EventRepository {
  @override
  Future<EventSummary> getEvent(String eventId) async {
    await _think(300);
    if (eventId == demo.pastEvent.id) return demo.pastEvent;
    return EventSummary(
      id: eventId,
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
  Future<String> catchUp(String eventId, String sessionId) async {
    await _think(500);
    return demo.keynoteCatchUp;
  }

  @override
  Future<String> ask(String eventId, String sessionId, String question) async {
    await _think(1400);
    final q = question.toLowerCase();
    for (final entry in demo.keynoteAnswers.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return demo.keynoteDefaultAnswer;
  }

  @override
  Future<List<SpeakerQuestion>> questions(
    String eventId,
    String sessionId,
  ) async {
    await _think(300);
    return [
      for (final (id, text, votes) in demo.keynoteQuestions)
        SpeakerQuestion(id: id, text: text, votes: votes),
    ];
  }

  @override
  Future<SpeakerQuestion> submitQuestion(
    String eventId,
    String sessionId,
    String text,
  ) async {
    await _think(400);
    return SpeakerQuestion(
      id: 'mine-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      votes: 1,
      mine: true,
    );
  }

  @override
  Future<String> fullSummary(String eventId, String sessionId) async {
    await _think(1600);
    return demo.keynoteSummary;
  }
}

class DemoFindRepository implements FindRepository {
  @override
  Future<List<PersonMatch>> recommendations(String eventId, Profile me) async {
    await _think(1500);
    final mine = me.interests.toSet();
    final scored = [
      for (final p in demo.people)
        (p, p.interests.where(mine.contains).length),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (p, score) in scored.take(5))
        PersonMatch(
          person: p,
          why: score > 0
              ? 'You both care about ${p.interests.where(mine.contains).join(' and ')}. '
                    '${p.name.split(' ').first} is looking for: ${p.lookingFor.toLowerCase()}.'
              : '${p.name.split(' ').first} is looking for: ${p.lookingFor.toLowerCase()}.',
        ),
    ];
  }

  @override
  Future<List<PersonMatch>> search(String eventId, String prompt) async {
    await _think(1700);
    final words = prompt
        .toLowerCase()
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
      for (final (p, score) in scored.where((s) => s.$2 > 0).take(4))
        PersonMatch(
          person: p,
          why: '${p.headline}. Matches "$prompt" on $score '
              '${score == 1 ? 'point' : 'points'}; looking for: ${p.lookingFor.toLowerCase()}.',
        ),
    ];
  }

  @override
  Future<Person> person(String eventId, String personId) async =>
      demo.people.firstWhere((p) => p.id == personId);

  @override
  Future<void> requestContact(String eventId, String personId) => _think(500);
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
    return PublishedLink(
      eventId: demoEventId,
      url: '$linkBase/e/$demoEventId',
    );
  }
}

// ---------------------------------------------------------------- providers

/// Event ID used by the demo. Set it to the ID printed by
/// `cd backend/maps && make seed` so the Map tab shows the real venue:
/// `--dart-define=DEMO_EVENT_ID=<id>`.
const demoEventId = String.fromEnvironment(
  'DEMO_EVENT_ID',
  defaultValue: 'devsummit',
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
final echoRepositoryProvider = Provider<EchoRepository>(
  (ref) => DemoEchoRepository(),
);
final findRepositoryProvider = Provider<FindRepository>(
  (ref) => DemoFindRepository(),
);
final organizerRepositoryProvider = Provider<OrganizerRepository>(
  (ref) => DemoOrganizerRepository(demoEventId, linkBase()),
);
