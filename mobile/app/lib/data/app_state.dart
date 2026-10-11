/// Client state for the demo session (profile, joined events, contacts,
/// meeting spot, unlocked summaries). Saved to local storage on every change
/// and restored in `build()` (see `local_store.dart`); the backend will own it
/// later (see `mobile/docs/api-needs.md`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart' as demo;
import 'demo_ids.dart';
import 'local_store.dart';
import 'models.dart';
import 'repositories.dart'
    show FindException, demoEventId, findRepositoryProvider;

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

  /// Saves locally and, once onboarding is done, on the Find service
  /// (`FindRepository.saveProfile`; consents exactly as set).
  void save(Profile p) {
    // Before the state change, so Find calls it triggers wait for this save.
    _sync(ref.read(findRepositoryProvider).saveProfile(p));
    state = p;
    ref.read(localStoreProvider).write('profile', p.toJson());
  }
}

/// Background push to the Find service. A failure keeps the local state (the
/// next Find call saves again); only the error kind is logged, never data.
void _sync(Future<void> push) => push.catchError((Object e) {
  debugPrint(
    'Find sync failed: ${e is FindException ? e.kind.name : e.runtimeType}',
  );
});

final profileProvider = NotifierProvider<ProfileNotifier, Profile>(
  ProfileNotifier.new,
);

/// The demo event id the joined-events migration maps aliases to. Overridable
/// so tests can simulate a `DEMO_EVENT_ID` build.
final demoEventIdProvider = Provider<String>((ref) => demoEventId);

/// Events the user joined via links, newest first. Seeded with one past event.
class JoinedEventsNotifier extends Notifier<List<EventSummary>> {
  @override
  List<EventSummary> build() {
    final store = ref.read(localStoreProvider);
    final saved = store.readAs('joinedEvents', (j) {
      return [
        for (final e in j as List)
          EventSummary.fromJson(e as Map<String, dynamic>),
      ];
    });
    if (saved == null) return const [demo.pastEvent];
    // Saved demo aliases (`devfest`, legacy `devsummit`) become the current
    // demo event id: `devfest` by default, the backend id with DEMO_EVENT_ID,
    // so `/e/<backend id>/...` counts as joined. No duplicates. Saved once.
    final demoId = ref.read(demoEventIdProvider);
    final seen = <String>{};
    final migrated = <EventSummary>[];
    var changed = false;
    for (final e in saved) {
      final legacy = demoEventAliases.contains(e.id) && e.id != demoId;
      final fixed = legacy
          ? EventSummary(
              id: demoId,
              name: demo.demoEventName,
              dates: demo.demoEventDates,
              venue: demo.demoEventVenue,
            )
          : e;
      if (seen.add(fixed.id)) {
        migrated.add(fixed);
      } else {
        changed = true;
      }
      if (legacy) changed = true;
    }
    if (changed) {
      store.write('joinedEvents', [for (final e in migrated) e.toJson()]);
    }
    return migrated;
  }

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

  /// Sets [spot] and saves it with the contact on the Find service
  /// (`putMeetingSpot`; the floor stays in the app). The place comes back in
  /// the map's spelling and the time as the service stored it.
  void agree(String eventId, MeetingSpot spot) {
    set(spot);
    final personId = spot.personId;
    if (personId == null) return;
    _sync(
      ref
          .read(findRepositoryProvider)
          .setMeetingSpot(eventId, personId, spot.place, time: spot.time)
          .then((stored) {
            if (identical(state, spot) &&
                (stored.place != spot.place || stored.time != spot.time)) {
              set(
                MeetingSpot(
                  personName: spot.personName,
                  place: stored.place,
                  time: stored.time,
                  floor: spot.floor,
                  personId: spot.personId,
                ),
              );
            }
          }),
    );
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

final unlockedSummariesProvider =
    NotifierProvider<UnlockedNotifier, Set<String>>(UnlockedNotifier.new);

/// The draft the organizer is reviewing (between extract and publish).
class DraftNotifier extends Notifier<EventDraft?> {
  @override
  EventDraft? build() => null;

  void set(EventDraft? d) => state = d;
}

final organizerDraftProvider = NotifierProvider<DraftNotifier, EventDraft?>(
  DraftNotifier.new,
);
