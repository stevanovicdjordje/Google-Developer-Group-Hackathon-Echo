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
    show
        EventsException,
        FindException,
        demoEventId,
        eventRepositoryProvider,
        findRepositoryProvider;

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
    Future.microtask(_syncFromServer);
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

  /// Ids `listMyEvents` returned, so a demo-only event the server really
  /// lists still counts as real.
  final _serverIds = <String>{};

  bool _isDemoOnly(String id) =>
      demoOnlyEventIds.contains(id) && !_serverIds.contains(id);

  /// With the live Events service: drops the demo-only events (the demo past
  /// event) the server doesn't know, and adds the events it knows the user
  /// joined (`listMyEvents`) on top, server order first; events only the app
  /// knows stay below. The demo repository knows none and keeps the demo
  /// events, so demo state is unchanged.
  Future<void> _syncFromServer() async {
    final repo = ref.read(eventRepositoryProvider);
    var live = false;
    var server = const <EventSummary>[];
    try {
      live = await repo.isLive;
      server = await repo.myEvents();
    } catch (e) {
      debugPrint(
        'My events sync failed: '
        '${e is EventsException ? e.kind.name : e.runtimeType}',
      );
    }
    if (!ref.mounted) return;
    _serverIds
      ..clear()
      ..addAll(server.map((e) => e.id));
    if (!live && server.isEmpty) return;
    final ids = {for (final e in server) e.id};
    final merged = [
      ...server,
      for (final e in state)
        if (!ids.contains(e.id) && !(live && _isDemoOnly(e.id))) e,
    ];
    final same =
        merged.length == state.length &&
        [
          for (var i = 0; i < merged.length; i++)
            merged[i].toJson().toString() == state[i].toJson().toString(),
        ].every((b) => b);
    if (!same) _set(merged);
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

  /// Removes the event here and on the Events service (`leaveEvent`, in the
  /// background; a failure only logs the error kind). Demo-only events are
  /// never sent: the server doesn't know them.
  void remove(String id) {
    final demoOnly = _isDemoOnly(id);
    _set(state.where((e) => e.id != id).toList());
    if (demoOnly) return;
    ref
        .read(eventRepositoryProvider)
        .leave(id)
        .catchError(
          (Object e) => debugPrint(
            'Leave event failed: '
            '${e is EventsException ? e.kind.name : e.runtimeType}',
          ),
        );
  }
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

  /// Reads back the spot stored with [personId] (`listContacts`), so a spot
  /// the other person set or changed shows up. The server's value wins: it
  /// is the single stored spot, so it replaces a different local one for
  /// that person (the local floor is kept when the place is the same). No
  /// server spot, or a failed call, leaves the state alone; so does a spot
  /// set here while the call was running.
  Future<void> loadFromContacts(String eventId, String personId) async {
    final before = state;
    final List<Contact> contacts;
    try {
      contacts = await ref.read(findRepositoryProvider).listContacts(eventId);
    } catch (e) {
      debugPrint(
        'Contacts load failed: '
        '${e is FindException ? e.kind.name : e.runtimeType}',
      );
      return;
    }
    if (!ref.mounted || !identical(state, before)) return;
    final contact = contacts.where((c) => c.person.id == personId).firstOrNull;
    final stored = contact?.meetingSpot;
    if (contact == null || stored == null) return;
    final cur = state;
    final same = cur != null && cur.personId == personId;
    if (same && cur.place == stored.place && cur.time == stored.time) return;
    set(
      MeetingSpot(
        personName: contact.person.name,
        place: stored.place,
        time: stored.time,
        floor: same && cur.place == stored.place ? cur.floor : null,
        personId: personId,
      ),
    );
  }
}

/// Loads the spot stored with a contact into [meetingSpotProvider] when
/// Messages opens: watch it with `(eventId, personId)`; it runs again each
/// time the screen is reopened (or when invalidated), never on a timer.
final contactSpotSyncProvider = FutureProvider.autoDispose
    .family<void, (String, String)>(
      (ref, key) => ref
          .read(meetingSpotProvider.notifier)
          .loadFromContacts(key.$1, key.$2),
    );

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
