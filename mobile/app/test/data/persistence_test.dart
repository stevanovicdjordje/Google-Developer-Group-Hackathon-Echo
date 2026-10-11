import 'dart:convert';

import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/local_store.dart';
import 'package:eho/data/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('fresh storage gives the demo defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final c = _container(await SharedPreferences.getInstance());
    expect(c.read(profileProvider).onboarded, isFalse);
    expect(c.read(joinedEventsProvider), [demo.pastEvent]);
    expect(c.read(contactsProvider), isEmpty);
    expect(c.read(meetingSpotProvider), isNull);
    expect(c.read(unlockedSummariesProvider), isEmpty);
  });

  test('state survives a rebuild with the same prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = _container(prefs);

    a
        .read(profileProvider.notifier)
        .save(
          const Profile(
            name: 'Ana',
            headline: 'ML engineer',
            interests: ['AI', 'Maps'],
            lookingFor: 'Mentors',
            visibleInFind: true,
            allowContact: true,
            onboarded: true,
          ),
        );
    a
        .read(joinedEventsProvider.notifier)
        .add(
          const EventSummary(
            id: 'devfest',
            name: 'Dev Summit',
            dates: 'Oct 1',
            venue: 'Hall',
          ),
        );
    a.read(contactsProvider.notifier).set('p1', ContactState.requested);
    a.read(contactsProvider.notifier).set('p2', ContactState.accepted);
    a
        .read(meetingSpotProvider.notifier)
        .set(const MeetingSpot(personName: 'Marko', place: 'Glavna sala'));
    a.read(unlockedSummariesProvider.notifier).unlock('s1');

    final b = _container(prefs);
    final p = b.read(profileProvider);
    expect(p.name, 'Ana');
    expect(p.interests, ['AI', 'Maps']);
    expect(p.visibleInFind, isTrue);
    expect(p.shareMeetingSpot, isFalse);
    expect(p.onboarded, isTrue);
    expect(b.read(joinedEventsProvider).map((e) => e.id), [
      'devfest',
      demo.pastEvent.id,
    ]);
    expect(b.read(contactsProvider), {
      'p1': ContactState.requested,
      'p2': ContactState.accepted,
    });
    expect(b.read(meetingSpotProvider)?.place, 'Glavna sala');
    expect(b.read(unlockedSummariesProvider), {'s1'});

    // Clearing values persists too.
    b.read(meetingSpotProvider.notifier).set(null);
    b.read(joinedEventsProvider.notifier).remove('devfest');
    final c = _container(prefs);
    expect(c.read(meetingSpotProvider), isNull);
    expect(c.read(joinedEventsProvider).map((e) => e.id), [demo.pastEvent.id]);
  });

  test('saved legacy devsummit event becomes devfest, saved once', () async {
    Map<String, Object> ev(String id, {bool past = false}) => {
      'id': id,
      'name': 'Event $id',
      'dates': 'Oct 1',
      'venue': 'Hall',
      'isPast': past,
    };
    SharedPreferences.setMockInitialValues({
      'eho.joinedEvents': jsonEncode([
        ev('devsummit'),
        ev('devfest'),
        ev(demo.pastEvent.id, past: true),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final a = _container(prefs);
    expect(a.read(joinedEventsProvider).map((e) => e.id), [
      'devfest',
      demo.pastEvent.id,
    ]);
    final saved = jsonDecode(prefs.getString('eho.joinedEvents')!) as List;
    expect(saved.map((e) => (e as Map)['id']), ['devfest', demo.pastEvent.id]);

    // Only the legacy entry saved: it is renamed to the current demo event.
    SharedPreferences.setMockInitialValues({
      'eho.joinedEvents': jsonEncode([ev('devsummit')]),
    });
    final b = _container(await SharedPreferences.getInstance());
    final only = b.read(joinedEventsProvider).single;
    expect(only.id, 'devfest');
    expect(only.name, demo.demoEventName);
  });

  test('corrupt saved data is ignored and cleared', () async {
    SharedPreferences.setMockInitialValues({
      'eho.profile': '{not json',
      'eho.joinedEvents': '[{"id": 1}]',
      'eho.contacts': '{"p1": "bogus"}',
      'eho.unlockedSummaries': '"oops"',
    });
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    expect(c.read(profileProvider).name, '');
    expect(c.read(joinedEventsProvider), [demo.pastEvent]);
    expect(c.read(contactsProvider), isEmpty);
    expect(c.read(unlockedSummariesProvider), isEmpty);
    expect(prefs.getKeys(), isEmpty);
  });
}
