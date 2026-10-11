/// App data models for the attendee and organizer flows.
///
/// These mirror what the backend is asked to provide in
/// `mobile/docs/api-needs.md`. Until those endpoints exist, the demo
/// repositories in `demo_repositories.dart` return hardcoded data.
library;

class EventSummary {
  const EventSummary({
    required this.id,
    required this.name,
    required this.dates,
    required this.venue,
    this.isPast = false,
  });

  final String id;
  final String name;
  final String dates;
  final String venue;
  final bool isPast;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'dates': dates,
    'venue': venue,
    'isPast': isPast,
  };

  factory EventSummary.fromJson(Map<String, dynamic> j) => EventSummary(
    id: j['id'] as String,
    name: j['name'] as String,
    dates: j['dates'] as String,
    venue: j['venue'] as String,
    isPast: j['isPast'] as bool? ?? false,
  );
}

class Speaker {
  const Speaker({required this.id, required this.name, required this.title});

  final String id;
  final String name;
  final String title;
}

class Session {
  const Session({
    required this.id,
    required this.title,
    required this.stage,
    required this.start,
    required this.end,
    required this.speakers,
    this.description = '',
    this.track = '',
    this.isBreak = false,
    this.isLive = false,
  });

  final String id;
  final String title;

  /// Stage/room name. Matches a room name on the venue map.
  final String stage;
  final String start;
  final String end;
  final List<Speaker> speakers;
  final String description;
  final String track;
  final bool isBreak;

  /// The talk is on right now (Echo is on for it).
  final bool isLive;
}

class TranscriptLine {
  const TranscriptLine({
    required this.atSeconds,
    required this.text,
    required this.translated,
  });

  final int atSeconds;
  final String text;

  /// Demo translation (Serbian). Empty for lines from the Echo API, which
  /// translates on request (`EchoRepository.translate`).
  final String translated;
}

class AiAnswer {
  const AiAnswer({required this.question, required this.answer});

  final String question;
  final String answer;
}

class SpeakerQuestion {
  SpeakerQuestion({
    required this.id,
    required this.text,
    required this.votes,
    this.mine = false,
    this.voted = false,
    this.mergedCount = 0,
  });

  final String id;
  final String text;
  int votes;
  final bool mine;

  /// The current user has voted for it.
  bool voted;

  /// How many similar questions the AI merged into this one.
  final int mergedCount;
}

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.headline,
    required this.interests,
    required this.lookingFor,
  });

  final String id;
  final String name;
  final String headline;
  final List<String> interests;
  final String lookingFor;

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0])
      .take(2)
      .join();
}

class PersonMatch {
  const PersonMatch({required this.person, required this.why});

  final Person person;

  /// AI explanation of why this person fits.
  final String why;
}

class Profile {
  const Profile({
    this.name = '',
    this.headline = '',
    this.interests = const [],
    this.lookingFor = '',
    this.visibleInFind = false,
    this.allowContact = false,
    this.shareMeetingSpot = false,
    this.onboarded = false,
  });

  final String name;
  final String headline;
  final List<String> interests;
  final String lookingFor;
  final bool visibleInFind;
  final bool allowContact;
  final bool shareMeetingSpot;
  final bool onboarded;

  Profile copyWith({
    String? name,
    String? headline,
    List<String>? interests,
    String? lookingFor,
    bool? visibleInFind,
    bool? allowContact,
    bool? shareMeetingSpot,
    bool? onboarded,
  }) => Profile(
    name: name ?? this.name,
    headline: headline ?? this.headline,
    interests: interests ?? this.interests,
    lookingFor: lookingFor ?? this.lookingFor,
    visibleInFind: visibleInFind ?? this.visibleInFind,
    allowContact: allowContact ?? this.allowContact,
    shareMeetingSpot: shareMeetingSpot ?? this.shareMeetingSpot,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'headline': headline,
    'interests': interests,
    'lookingFor': lookingFor,
    'visibleInFind': visibleInFind,
    'allowContact': allowContact,
    'shareMeetingSpot': shareMeetingSpot,
    'onboarded': onboarded,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    name: j['name'] as String? ?? '',
    headline: j['headline'] as String? ?? '',
    interests: (j['interests'] as List?)?.cast<String>().toList() ?? const [],
    lookingFor: j['lookingFor'] as String? ?? '',
    visibleInFind: j['visibleInFind'] as bool? ?? false,
    allowContact: j['allowContact'] as bool? ?? false,
    shareMeetingSpot: j['shareMeetingSpot'] as bool? ?? false,
    onboarded: j['onboarded'] as bool? ?? false,
  );
}

enum ContactState { none, requested, accepted }

/// A person as the Person screen needs them (`PersonDetail` in
/// `contracts/find`).
class PersonDetail {
  const PersonDetail({
    required this.person,
    this.allowContact = true,
    this.contactState,
  });

  final Person person;

  /// Whether a contact request can be sent.
  final bool allowContact;

  /// The caller's contact state as the server knows it; null when only the
  /// app knows it (demo data), so the local state stays.
  final ContactState? contactState;
}

class MeetingSpot {
  const MeetingSpot({
    required this.personName,
    required this.place,
    this.time,
    this.floor,
    this.personId,
  });

  final String personName;

  /// The contact's `Person.id`, used to save the spot on the Find service.
  /// Null on spots saved before it existed.
  final String? personId;

  /// Name of a room/stand/POI on the venue map (`MeetingSpot.place` in
  /// `contracts/find`).
  final String place;

  /// Agreed time, "HH:mm" (`MeetingSpot.time` in `contracts/find` 0.2.0).
  final String? time;

  /// Name of the map floor the place is on, e.g. "Ground floor" (app-only,
  /// resolved from the published map when the spot is picked).
  final String? floor;

  Map<String, Object?> toJson() => {
    'personName': personName,
    'place': place,
    if (time != null) 'time': time,
    if (floor != null) 'floor': floor,
    if (personId != null) 'personId': personId,
  };

  factory MeetingSpot.fromJson(Map<String, dynamic> j) => MeetingSpot(
    personName: j['personName'] as String,
    place: j['place'] as String,
    time: j['time'] as String?,
    floor: j['floor'] as String?,
    personId: j['personId'] as String?,
  );
}

class UploadedFile {
  const UploadedFile({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;
}

/// What the AI extracted from the organizer's files, before publishing.
class EventDraft {
  const EventDraft({
    required this.name,
    required this.dates,
    required this.venue,
    required this.stages,
    required this.sessions,
    required this.speakers,
  });

  final String name;
  final String dates;
  final String venue;
  final List<String> stages;
  final List<Session> sessions;
  final List<Speaker> speakers;
}

class PublishedLink {
  const PublishedLink({required this.eventId, required this.url});

  final String eventId;
  final String url;
}
