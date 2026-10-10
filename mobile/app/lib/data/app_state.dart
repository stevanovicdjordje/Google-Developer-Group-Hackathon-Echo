/// In-memory client state for the demo session (profile, joined events,
/// contacts, meeting spot). Lost on reload; the backend will own it later
/// (see `mobile/docs/api-needs.md`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart' as demo;
import 'models.dart';

class ProfileNotifier extends Notifier<Profile> {
  @override
  Profile build() => const Profile();

  void save(Profile p) => state = p;
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile>(
  ProfileNotifier.new,
);

/// Events the user joined via links, newest first. Seeded with one past event.
class JoinedEventsNotifier extends Notifier<List<EventSummary>> {
  @override
  List<EventSummary> build() => const [demo.pastEvent];

  bool isJoined(String id) => state.any((e) => e.id == id);

  void add(EventSummary e) {
    if (isJoined(e.id)) return;
    state = [e, ...state];
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();
}

final joinedEventsProvider =
    NotifierProvider<JoinedEventsNotifier, List<EventSummary>>(
      JoinedEventsNotifier.new,
    );

/// Contact state per person ID.
class ContactsNotifier extends Notifier<Map<String, ContactState>> {
  @override
  Map<String, ContactState> build() => const {};

  void set(String personId, ContactState s) => state = {...state, personId: s};
}

final contactsProvider =
    NotifierProvider<ContactsNotifier, Map<String, ContactState>>(
      ContactsNotifier.new,
    );

class MeetingSpotNotifier extends Notifier<MeetingSpot?> {
  @override
  MeetingSpot? build() => null;

  void set(MeetingSpot? spot) => state = spot;
}

final meetingSpotProvider = NotifierProvider<MeetingSpotNotifier, MeetingSpot?>(
  MeetingSpotNotifier.new,
);

/// Session IDs whose premium summary was unlocked (mock paywall).
class UnlockedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void unlock(String sessionId) => state = {...state, sessionId};
}

final unlockedSummariesProvider = NotifierProvider<UnlockedNotifier, Set<String>>(
  UnlockedNotifier.new,
);

/// The draft the organizer is reviewing (between extract and publish).
class DraftNotifier extends Notifier<EventDraft?> {
  @override
  EventDraft? build() => null;

  void set(EventDraft? d) => state = d;
}

final organizerDraftProvider = NotifierProvider<DraftNotifier, EventDraft?>(
  DraftNotifier.new,
);
