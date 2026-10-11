import 'dart:convert';
import 'dart:io';

import 'package:eho/data/app_state.dart';
import 'package:eho/data/find_api_repository.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fixture from `contracts/find/examples/`, unchanged (tests run in
/// `mobile/app`).
Object? _fixture(String name) =>
    jsonDecode(File('../../contracts/find/examples/$name').readAsStringSync());

/// The onboarded profile behind `profile-input.json`.
const _ana = Profile(
  name: 'Ana Petrović',
  headline: 'Android dev at Fintio',
  interests: ['Mobile', 'AI / ML'],
  lookingFor: 'People who shipped on-device ML in production',
  visibleInFind: true,
  allowContact: true,
  shareMeetingSpot: true,
  onboarded: true,
);

http.Response _json(Object? body, [int status = 200, Map<String, String>? h]) =>
    http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...?h},
    );

/// Records every call to the repository the notifiers push to.
class _RecordingFind extends DemoFindRepository {
  final saved = <Profile>[];
  final spots = <(String, String, String, String?)>[];
  Future<List<Contact>> Function() contacts = () async => const [];

  @override
  Future<void> saveProfile(Profile profile) async => saved.add(profile);

  @override
  Future<({String place, String? time})> setMeetingSpot(
    String eventId,
    String personId,
    String place, {
    String? time,
  }) async {
    spots.add((eventId, personId, place, time));
    return (place: 'Info pult', time: time);
  }

  @override
  Future<List<Contact>> listContacts(String eventId) => contacts();
}

void main() {
  late List<http.Request> requests;
  var me = _ana;

  /// A Find service that answers with the contract fixtures.
  Future<http.Response> service(http.Request r) async {
    final path = r.url.path;
    return switch ((r.method, path)) {
      ('GET', '/healthz') => _json({'status': 'ok', 'model': 'offline'}),
      ('PUT', '/v1/me/profile') => _json(_fixture('profile.json')),
      ('PUT', '/v1/events/ev/people/me') => _json(null, 204),
      ('GET', '/v1/events/ev/people/recommendations') => _json(
        _fixture('recommendations.response.json'),
      ),
      ('POST', '/v1/events/ev/people/search') => _json(
        _fixture('search.response.json'),
      ),
      ('GET', '/v1/events/ev/people/k7Qm2xLp') => _json(
        _fixture('person.response.json'),
      ),
      ('POST', '/v1/events/ev/contacts') => _json(
        _fixture('contact.response.json'),
      ),
      ('GET', '/v1/events/ev/contacts') => _json({
        'contacts': [
          _fixture('meeting-spot.response.json'),
          _fixture('contact.response.json'),
        ],
      }),
      ('PUT', '/v1/events/ev/contacts/k7Qm2xLp/meeting-spot') => _json(
        _fixture('meeting-spot.response.json'),
      ),
      _ => _json({'code': 'not_found', 'message': 'not found'}, 404),
    };
  }

  FindApiRepository repo([MockClientHandler? handler]) {
    requests = [];
    return FindApiRepository(
      baseUrl: 'http://find.test',
      tokenProvider: () async => 'tok',
      profile: () => me,
      httpClient: MockClient((req) {
        requests.add(req);
        return (handler ?? service)(req);
      }),
    );
  }

  List<String> calls() => [
    for (final r in requests) '${r.method} ${r.url.path}',
  ];

  setUp(() => me = _ana);

  test(
    'recommendations: saves the profile, joins, then maps matches',
    () async {
      final r = repo();
      final matches = await r.recommendations('ev', me);
      expect(calls(), [
        'PUT /v1/me/profile',
        'PUT /v1/events/ev/people/me',
        'GET /v1/events/ev/people/recommendations',
      ]);
      // The profile goes out exactly as the contract's request example:
      // consents as set, nothing app-only (`onboarded`).
      expect(jsonDecode(requests.first.body), _fixture('profile-input.json'));
      expect(
        requests.every((q) => q.headers['Authorization'] == 'Bearer tok'),
        isTrue,
      );
      expect(matches.map((m) => m.person.id), ['k7Qm2xLp', 'b3Vn8sTe']);
      final first = matches.first;
      expect(first.person.name, 'Teodora Nikolić');
      expect(first.person.headline, 'ML researcher, Univ. of Belgrade');
      expect(first.person.interests, ['AI / ML', 'Data']);
      expect(first.person.lookingFor, 'Industry partners for speech models');
      expect(first.why, startsWith('Works on speech models'));

      // Profile and presence are done once per run.
      await r.recommendations('ev', me);
      expect(calls().skip(3), ['GET /v1/events/ev/people/recommendations']);
    },
  );

  test('search sends the prompt and maps the results', () async {
    final r = repo();
    final matches = await r.search('ev', 'someone hiring mobile engineers');
    expect(calls().last, 'POST /v1/events/ev/people/search');
    expect(jsonDecode(requests.last.body), _fixture('search.request.json'));
    expect(matches.single.person.name, 'Vuk Tomić');
    expect(matches.single.why, 'CTO who is hiring mobile engineers right now.');
  });

  test('person maps contact state and allowContact; hidden is null', () async {
    final r = repo();
    final d = await r.person('ev', 'k7Qm2xLp');
    expect(d!.person.name, 'Teodora Nikolić');
    expect(d.allowContact, isTrue);
    expect(d.contactState, ContactState.none);
    expect(await r.person('ev', 'gone1234'), isNull); // 404
    expect(await r.person('ev', '../x'), isNull); // never sent
    expect(calls().where((c) => c.contains('../')), isEmpty);
  });

  test('contact request sends the person and maps the state', () async {
    final r = repo();
    final states = await r.requestContact('ev', 'k7Qm2xLp').toList();
    expect(jsonDecode(requests.last.body), _fixture('contact.request.json'));
    expect(states, [ContactState.requested]);
  });

  test('meeting spot sends place and time as in the 0.2.0 fixture', () async {
    final r = repo();
    final spot = await r.setMeetingSpot(
      'ev',
      'k7Qm2xLp',
      'Info pult',
      time: '15:20',
    );
    expect(calls().last, 'PUT /v1/events/ev/contacts/k7Qm2xLp/meeting-spot');
    expect(
      jsonDecode(requests.last.body),
      _fixture('meeting-spot.request.json'),
    );
    expect(spot.place, 'Info pult');
    expect(spot.time, '15:20');
  });

  test('meeting spot without a time omits the key', () async {
    final r = repo((req) async {
      if (req.method == 'PUT' && req.url.path.endsWith('/meeting-spot')) {
        final c = Map<String, Object?>.from(
          _fixture('meeting-spot.response.json') as Map,
        );
        c['meetingSpot'] = {
          'place': 'Info pult',
          'setByMe': true,
          'updatedAt': '2026-10-11T09:25:00Z',
        };
        return _json(c);
      }
      return service(req);
    });
    final spot = await r.setMeetingSpot('ev', 'k7Qm2xLp', 'info pult');
    expect(jsonDecode(requests.last.body), {'place': 'info pult'});
    expect(spot.place, 'Info pult'); // the map's spelling, from the response
    expect(spot.time, isNull);
  });

  test('meeting time is zero-padded; an invalid one is not sent', () {
    Object? body(String? t) => FindApiRepository.meetingSpotRequest('A', t);
    expect(body('9:05'), {'place': 'A', 'time': '09:05'});
    expect(body('00:00'), {'place': 'A', 'time': '00:00'});
    for (final bad in [null, '', '24:00', '12:60', '1530', 'noon']) {
      expect(body(bad), {'place': 'A'}, reason: '$bad');
    }
  });

  test('meeting spot parsing reads the time and ignores a bad one', () {
    final ok = FindApiRepository.parseMeetingSpot(
      _fixture('meeting-spot.response.json'),
    );
    expect(ok?.place, 'Info pult');
    expect(ok?.time, '15:20');
    for (final bad in ['25:00', '9:05', 1520, null]) {
      final c = {
        'meetingSpot': {'place': 'Info pult', 'time': bad},
      };
      final spot = FindApiRepository.parseMeetingSpot(c);
      expect(spot?.place, 'Info pult');
      expect(spot?.time, isNull, reason: '$bad');
    }
    expect(FindApiRepository.parseMeetingSpot({'state': 'accepted'}), isNull);
    expect(FindApiRepository.parseMeetingSpot('x'), isNull);
  });

  test('without onboarding the profile is never sent', () async {
    me = const Profile(name: 'Not onboarded');
    final r = repo((req) async {
      if (req.url.path.endsWith('/people/me')) {
        return _json({
          'code': 'profile_required',
          'message': 'save a profile',
        }, 409);
      }
      return service(req);
    });
    await r.saveProfile(me);
    await expectLater(
      r.recommendations('ev', me),
      throwsA(
        isA<FindException>().having(
          (e) => e.kind,
          'kind',
          FindErrorKind.profileRequired,
        ),
      ),
    );
    expect(calls().where((c) => c.contains('/me/profile')), isEmpty);
  });

  test('joins again when the server forgot the presence', () async {
    var forgot = true;
    final r = repo((req) async {
      if (req.url.path.endsWith('/recommendations') && forgot) {
        forgot = false;
        return _json({'code': 'not_present', 'message': 'join first'}, 409);
      }
      return service(req);
    });
    final matches = await r.recommendations('ev', me);
    expect(matches, hasLength(2));
    expect(
      calls().where((c) => c == 'PUT /v1/events/ev/people/me'),
      hasLength(2),
    );
  });

  test('errors map to kinds; invalid matches are skipped', () async {
    final limited = repo(
      (_) async => _json(
        {'code': 'rate_limited', 'message': 'slow down'},
        429,
        {'retry-after': '7'},
      ),
    );
    await expectLater(
      limited.search('ev', 'mobile'),
      throwsA(
        isA<FindException>()
            .having((e) => e.kind, 'kind', FindErrorKind.rateLimited)
            .having((e) => e.retryAfter, 'retryAfter', Duration(seconds: 7)),
      ),
    );

    final offline = repo((_) async => throw http.ClientException('down'));
    await expectLater(
      offline.recommendations('ev', me),
      throwsA(
        isA<FindException>().having(
          (e) => e.kind,
          'kind',
          FindErrorKind.offline,
        ),
      ),
    );

    final matches = FindApiRepository.parseMatches({
      'matches': [
        {
          'person': {'id': 'bad/id', 'name': 'X'},
          'why': 'x',
        },
        {
          'person': {'id': 'ok1', 'name': ''},
          'why': 'x',
        },
        {
          'person': {
            'id': 'ok2',
            'name': 'Ok',
            'interests': [1, 'Go'],
          },
        },
        'junk',
      ],
      'model': 'offline',
    });
    expect(matches.single.person.id, 'ok2');
    expect(matches.single.person.interests, ['Go']);
    expect(matches.single.why, '');
  });

  test('listContacts maps the contacts and their meeting spots', () async {
    final r = repo();
    final contacts = await r.listContacts('ev');
    expect(calls().last, 'GET /v1/events/ev/contacts');
    expect(contacts.map((c) => c.person.id), ['k7Qm2xLp', 'k7Qm2xLp']);
    expect(contacts.first.state, ContactState.accepted);
    expect(contacts.first.person.name, 'Teodora Nikolić');
    expect(contacts.first.meetingSpot, (place: 'Info pult', time: '15:20'));
    // contact.response.json has no spot yet.
    expect(contacts.last.state, ContactState.requested);
    expect(contacts.last.meetingSpot, isNull);
  });

  test('listContacts skips invalid entries and tolerates a bad spot', () {
    final contacts = FindApiRepository.parseContacts({
      'contacts': [
        'junk',
        {'person': null, 'state': 'accepted'},
        {
          'person': {'id': 'a1', 'name': 'A'},
        },
        {
          'person': {'id': 'a2', 'name': 'B'},
          'state': 'accepted',
          'meetingSpot': {'place': '  ', 'time': '9:99'},
        },
        {
          'person': {'id': 'a3', 'name': 'C'},
          'state': 'incoming',
          'meetingSpot': {'place': 'Info pult', 'time': '25:00'},
        },
      ],
    });
    expect(contacts.map((c) => c.person.id), ['a2', 'a3']);
    expect(contacts[0].meetingSpot, isNull);
    expect(contacts[1].state, ContactState.none);
    expect(contacts[1].meetingSpot, (place: 'Info pult', time: null));
    // A state this app doesn't know is ignored, not turned into `none`.
    expect(
      FindApiRepository.parseContacts({
        'contacts': [
          {
            'person': {'id': 'a4', 'name': 'D'},
            'state': 'blocked',
          },
        ],
      }),
      isEmpty,
    );
    expect(() => FindApiRepository.parseContacts({}), throwsA(anything));
  });

  test('profile edits during a save are coalesced to the latest', () async {
    final r = repo();
    final a = r.saveProfile(_ana);
    r.saveProfile(_ana.copyWith(visibleInFind: false));
    final c = r.saveProfile(_ana.copyWith(allowContact: false));
    await Future.wait([a, c]);
    expect(calls(), ['PUT /v1/me/profile', 'PUT /v1/me/profile']);
    final last = jsonDecode(requests.last.body) as Map;
    expect(last['visibleInFind'], isTrue);
    expect(last['allowContact'], isFalse);
  });

  group('fallback', () {
    test('uses demo data when /healthz fails', () async {
      final api = repo((req) async {
        if (req.url.path == '/healthz') throw http.ClientException('refused');
        fail('no API call expected, got ${req.method} ${req.url}');
      });
      final r = FallbackFindRepository(
        primary: api,
        fallback: DemoFindRepository(),
      );
      await r.saveProfile(_ana);
      final d = await r.person('ev', 'p1');
      expect(d!.person.name, 'Ana Petrović'); // demo.people
      expect(d.contactState, isNull); // the app's own state stays
      expect(calls(), ['GET /healthz']);
    });

    test('uses the service when /healthz answers', () async {
      final r = FallbackFindRepository(
        primary: repo(),
        fallback: DemoFindRepository(),
      );
      final d = await r.person('ev', 'k7Qm2xLp');
      expect(d!.person.name, 'Teodora Nikolić');
      expect(calls().first, 'GET /healthz');
    });
  });

  group('app state pushes through the repository', () {
    late _RecordingFind find;
    late ProviderContainer c;

    setUp(() {
      find = _RecordingFind();
      c = ProviderContainer(
        overrides: [findRepositoryProvider.overrideWithValue(find)],
      );
      addTearDown(c.dispose);
    });

    test('profile saves reach the repository with consents as set', () async {
      c.read(profileProvider.notifier).save(_ana.copyWith(onboarded: false));
      c.read(profileProvider.notifier).save(_ana.copyWith(allowContact: false));
      await pumpEventQueue();
      // The repository itself skips profiles before onboarding.
      expect(find.saved.map((p) => p.allowContact), [true, false]);
      expect(find.saved.last.visibleInFind, isTrue);
    });

    test(
      'a meeting spot is saved with the contact and keeps time/floor',
      () async {
        c
            .read(meetingSpotProvider.notifier)
            .agree(
              'ev',
              const MeetingSpot(
                personName: 'Teodora Nikolić',
                place: 'info pult',
                time: '15:20',
                floor: 'Ground floor',
                personId: 'p3',
              ),
            );
        expect(c.read(meetingSpotProvider)?.place, 'info pult');
        await pumpEventQueue();
        expect(find.spots, [('ev', 'p3', 'info pult', '15:20')]);
        final spot = c.read(meetingSpotProvider)!;
        expect(spot.place, 'Info pult');
        expect(spot.time, '15:20');
        expect(spot.floor, 'Ground floor');
        expect(spot.personId, 'p3');
      },
    );

    group('spot set by the other person', () {
      const mine = MeetingSpot(
        personName: 'Teodora Nikolić',
        place: 'Info pult',
        time: '15:20',
        floor: 'Ground floor',
        personId: 'p3',
      );
      Contact contact(String id, {({String place, String? time})? spot}) =>
          Contact(
            person: Person(
              id: id,
              name: 'Teodora Nikolić',
              headline: '',
              interests: const [],
              lookingFor: '',
            ),
            state: ContactState.accepted,
            meetingSpot: spot,
          );

      test('a contact\'s server spot surfaces in the notifier', () async {
        find.contacts = () async => [
          contact('p3', spot: (place: 'Main stage', time: '11:00')),
        ];
        await c.read(contactSpotSyncProvider(('ev', 'p3')).future);
        final spot = c.read(meetingSpotProvider)!;
        expect(spot.personName, 'Teodora Nikolić');
        expect(spot.place, 'Main stage');
        expect(spot.time, '11:00');
        expect(spot.personId, 'p3');
      });

      test('the server wins over a different local spot; floor kept only '
          'for the same place', () async {
        c.read(meetingSpotProvider.notifier).set(mine);
        find.contacts = () async => [
          contact('p3', spot: (place: 'Info pult', time: '16:00')),
        ];
        await c.read(meetingSpotProvider.notifier).loadFromContacts('ev', 'p3');
        expect(c.read(meetingSpotProvider)?.time, '16:00');
        expect(c.read(meetingSpotProvider)?.floor, 'Ground floor');
        find.contacts = () async => [
          contact('p3', spot: (place: 'Main stage', time: null)),
        ];
        await c.read(meetingSpotProvider.notifier).loadFromContacts('ev', 'p3');
        expect(c.read(meetingSpotProvider)?.place, 'Main stage');
        expect(c.read(meetingSpotProvider)?.floor, isNull);
      });

      test(
        'no server spot, another contact or a failure change nothing',
        () async {
          c.read(meetingSpotProvider.notifier).set(mine);
          final n = c.read(meetingSpotProvider.notifier);
          find.contacts = () async => [contact('p3')];
          await n.loadFromContacts('ev', 'p3');
          find.contacts = () async => [
            contact('p9', spot: (place: 'Main stage', time: null)),
          ];
          await n.loadFromContacts('ev', 'p3');
          find.contacts = () async =>
              throw const FindException(FindErrorKind.offline);
          await n.loadFromContacts('ev', 'p3');
          expect(c.read(meetingSpotProvider), same(mine));
        },
      );

      test('a spot set here while loading is not overwritten', () async {
        find.contacts = () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return [contact('p3', spot: (place: 'Main stage', time: '11:00'))];
        };
        final load = c
            .read(meetingSpotProvider.notifier)
            .loadFromContacts('ev', 'p3');
        c.read(meetingSpotProvider.notifier).set(mine);
        await load;
        expect(c.read(meetingSpotProvider), same(mine));
      });

      test(
        'contact states: server wins, local-only entries are kept',
        () async {
          final n = c.read(contactsProvider.notifier);
          n.set('p3', ContactState.requested);
          n.set('local', ContactState.requested);
          find.contacts = () async => [
            contact('p3'), // accepted
            contact('p4'),
          ];
          await c
              .read(meetingSpotProvider.notifier)
              .loadFromContacts('ev', 'p9');
          expect(c.read(contactsProvider), {
            'p3': ContactState.accepted,
            'p4': ContactState.accepted,
            'local': ContactState.requested,
          });
        },
      );

      test(
        'contact states: failure or a state set while loading wins',
        () async {
          c.read(contactsProvider.notifier).set('p3', ContactState.requested);
          find.contacts = () async =>
              throw const FindException(FindErrorKind.offline);
          await c
              .read(meetingSpotProvider.notifier)
              .loadFromContacts('ev', 'p3');
          expect(c.read(contactsProvider), {'p3': ContactState.requested});
          find.contacts = () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return [contact('p3')];
          };
          final load = c
              .read(meetingSpotProvider.notifier)
              .loadFromContacts('ev', 'p3');
          c.read(contactsProvider.notifier).set('p5', ContactState.requested);
          await load;
          expect(c.read(contactsProvider)['p3'], ContactState.requested);
        },
      );

      test('the sync provider feeds both the spot and the states', () async {
        find.contacts = () async => [
          contact('p3', spot: (place: 'Main stage', time: '11:00')),
        ];
        await c.read(contactSpotSyncProvider(('ev', 'p3')).future);
        expect(c.read(contactsProvider)['p3'], ContactState.accepted);
        expect(c.read(meetingSpotProvider)?.place, 'Main stage');
      });

      test('ContactsNotifier.loadFromContacts maps every state', () {
        c.read(contactsProvider.notifier).loadFromContacts([
          for (final s in ContactState.values)
            Contact(
              person: Person(
                id: s.name,
                name: s.name,
                headline: '',
                interests: const [],
                lookingFor: '',
              ),
              state: s,
            ),
        ]);
        expect(c.read(contactsProvider), {
          for (final s in ContactState.values) s.name: s,
        });
      });

      test('the demo repository has no contacts', () async {
        expect(await DemoFindRepository().listContacts('ev'), isEmpty);
      });
    });
  });
}
