/// Client state for the demo session (profile, joined events, contacts,
/// meeting spot, unlocked summaries). Saved to local storage on every change
/// and restored in `build()` (see `local_store.dart`); the backend will own it
/// later (see `mobile/docs/api-needs.md`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart' as demo;
import 'local_store.dart';
import 'models.dart';

class ProfileNotifier extends Notifier<Profile> {
  @override
  Profile build() =>
      ref
          .read(localStoreProvider)
          .readAs(
            'profile',
            (j) => Profile.fromJson(j as Map<String, dynamic>),
          ) ??
      const Profile();

  void save(Profile p) {
    state = p;
    ref.read(localStoreProvider).write('profile', p.toJson());
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile>(
  ProfileNotifier.new,
);

/// Events the user joined via links, newest first. Seeded with one past event.
class JoinedEventsNotifier extends Notifier<List<EventSummary>> {
  @override
  List<EventSummary> build() =>
      ref.read(localStoreProvider).readAs('joinedEvents', (j) {
        return [
          for (final e in j as List)
            EventSummary.fromJson(e as Map<String, dynamic>),
        ];
      }) ??
      const [demo.pastEvent];

  bool isJoined(String id) => state.any((e) => e.id == id);

  void _set(List<EventSummary> events) {
    state = events;
    ref.read(localStoreProvider).write('joinedEvents', [
      for (final e in events) e.toJson(),
    ]);
  }

  void add(EventSummary e) {
    if (isJoined(e.id)) return;
    _set([e, ...state]);
  }

  void remove(String id) => _set(state.where((e) => e.id != id).toList());
}

final joinedEventsProvider =
    NotifierProvider<JoinedEventsNotifier, List<EventSummary>>(
      JoinedEventsNotifier.new,
    );

/// Contact state per person ID.
class ContactsNotifier extends Notifier<Map<String, ContactState>> {
  @override
  Map<String, ContactState> build() =>
      ref.read(localStoreProvider).readAs('contacts', (j) {
        return {
          for (final e in (j as Map<String, dynamic>).entries)
            e.key: ContactState.values.byName(e.value as String),
        };
      }) ??
      const {};

  void set(String personId, ContactState s) {
    state = {...state, personId: s};
    ref.read(localStoreProvider).write('contacts', {
      for (final e in state.entries) e.key: e.value.name,
    });
  }
}

final contactsProvider =
    NotifierProvider<ContactsNotifier, Map<String, ContactState>>(
      ContactsNotifier.new,
    );

class MeetingSpotNotifier extends Notifier<MeetingSpot?> {
  @override
  MeetingSpot? build() => ref
      .read(localStoreProvider)
      .readAs(
        'meetingSpot',
        (j) => MeetingSpot.fromJson(j as Map<String, dynamic>),
      );

  void set(MeetingSpot? spot) {
    state = spot;
    ref.read(localStoreProvider).write('meetingSpot', spot?.toJson());
  }
}

final meetingSpotProvider = NotifierProvider<MeetingSpotNotifier, MeetingSpot?>(
  MeetingSpotNotifier.new,
);

/// Session IDs whose premium summary was unlocked (mock paywall).
class UnlockedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref
          .read(localStoreProvider)
          .readAs(
            'unlockedSummaries',
            (j) => (j as List).cast<String>().toSet(),
          ) ??
      const {};

  void unlock(String sessionId) {
    state = {...state, sessionId};
    ref.read(localStoreProvider).write('unlockedSummaries', state.toList());
  }
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
