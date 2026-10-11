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
  final spots = <(String, String, String)>[];

  @override
  Future<void> saveProfile(Profile profile) async => saved.add(profile);

  @override
  Future<String> setMeetingSpot(
    String eventId,
    String personId,
    String place,
  ) async {
    spots.add((eventId, personId, place));
    return 'Info pult';
  }
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

  test('meeting spot sends the place and returns the stored one', () async {
    final r = repo();
    final place = await r.setMeetingSpot('ev', 'k7Qm2xLp', 'info pult');
    expect(calls().last, 'PUT /v1/events/ev/contacts/k7Qm2xLp/meeting-spot');
    expect(jsonDecode(requests.last.body), {'place': 'info pult'});
    expect(place, 'Info pult'); // the map's spelling, from the fixture
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
        expect(find.spots, [('ev', 'p3', 'info pult')]);
        final spot = c.read(meetingSpotProvider)!;
        expect(spot.place, 'Info pult');
        expect(spot.time, '15:20');
        expect(spot.floor, 'Ground floor');
        expect(spot.personId, 'p3');
      },
    );
  });
}
