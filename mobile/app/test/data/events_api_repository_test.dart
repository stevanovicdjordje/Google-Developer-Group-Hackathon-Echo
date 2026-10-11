import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/events_api_repository.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fixture from `contracts/events/examples/`, unchanged (tests run in
/// `mobile/app`).
Object? _fixture(String name) => jsonDecode(
  File('../../contracts/events/examples/$name').readAsStringSync(),
);

http.Response _json(Object? body, [int status = 200, Map<String, String>? h]) =>
    http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...?h},
    );

UploadedFile _file(String name, int size) =>
    UploadedFile(name: name, sizeBytes: size, bytes: Uint8List(size));

/// Records the server-side calls the notifiers make.
class _RecordingEvents extends DemoEventRepository {
  _RecordingEvents(this.server);

  final List<EventSummary> server;
  final left = <String>[];

  @override
  Future<List<EventSummary>> myEvents() async => server;

  @override
  Future<void> leave(String eventId) async => left.add(eventId);
}

void main() {
  late List<http.BaseRequest> requests;
  late List<String> bodies;
  late List<String> tokens;

  /// An Events service that answers with the contract fixtures.
  Future<http.Response> service(http.Request r) async {
    final path = r.url.path;
    return switch ((r.method, path)) {
      ('GET', '/healthz') => _json({'status': 'ok', 'model': 'offline'}),
      ('GET', '/v1/events/devfest/public') => _json(
        _fixture('public-event.response.json'),
      ),
      ('POST' || 'DELETE', '/v1/events/devfest/join') => _json(null, 204),
      ('GET', '/v1/me/events') => _json(_fixture('my-events.response.json')),
      ('GET', '/v1/events/devfest/agenda') => _json(
        _fixture('agenda.response.json'),
      ),
      ('POST', '/v1/organizer/drafts') => _json(
        _fixture('draft.response.json'),
        201,
      ),
      ('PUT', '/v1/organizer/drafts/k2v9q3m1x8a7b6c5') => _json(
        _fixture('draft.response.json'),
      ),
      ('POST', '/v1/organizer/drafts/k2v9q3m1x8a7b6c5/publish') => _json(
        _fixture('publish.response.json'),
      ),
      _ => _json({'code': 'not_found', 'message': 'not found'}, 404),
    };
  }

  EventsApiRepository repo({
    MockClientHandler? handler,
    Map<String, Set<String>> pinnedLive = const {},
    DateTime? now,
  }) => EventsApiRepository(
    baseUrl: 'http://events.test',
    tokenProvider: () async => 'attendee-token',
    organizerTokenProvider: () async => 'organizer-token',
    publishEventId: 'devfest',
    linkBase: 'https://eho.app',
    pinnedLive: pinnedLive,
    clock: () => now ?? DateTime(2026, 10, 11, 10, 15),
    httpClient: MockClient((r) async {
      requests.add(r);
      bodies.add(utf8.decode(r.bodyBytes, allowMalformed: true));
      tokens.add(r.headers['Authorization'] ?? '');
      return (handler ?? service)(r);
    }),
  );

  setUp(() {
    requests = [];
    bodies = [];
    tokens = [];
  });

  group('attendee mapping on the contract fixtures', () {
    test('getPublicEvent → EventSummary', () async {
      final e = await repo().getEvent('devfest');
      expect(e.id, 'devfest');
      expect(e.name, 'DevFest Belgrade 2026');
      expect(e.dates, demo.demoEventDates);
      expect(e.venue, 'Sava Centar, Belgrade');
      expect(e.isPast, isFalse);
      expect(tokens.single, 'Bearer attendee-token');
    });

    test('join and leave hit joinEvent / leaveEvent', () async {
      final r = repo();
      await r.join('devfest');
      await r.leave('devfest');
      expect(
        [for (final q in requests) '${q.method} ${q.url.path}'],
        ['POST /v1/events/devfest/join', 'DELETE /v1/events/devfest/join'],
      );
    });

    test('listMyEvents → events with isPast, server order', () async {
      final events = await repo().myEvents();
      expect(events.map((e) => e.id), ['devfest', 'ai-meetup-ns-2026']);
      expect(events.map((e) => e.isPast), [false, true]);
      expect(events.last.dates, 'Sep 18, 2026');
      expect(events.last.venue, 'Startit Centar, Novi Sad');
    });

    test('getAgenda → sessions, speakers, day, breaks', () async {
      final sessions = await repo().agenda('devfest');
      expect(sessions.map((s) => s.id), [
        's0',
        's1',
        's2',
        's3',
        's4',
        's5',
        's6',
      ]);
      final keynote = sessions[1];
      expect(
        keynote.title,
        'On-device AI: when the model lives in your pocket',
      );
      expect(keynote.stage, 'Glavna sala');
      expect(keynote.day, '2026-10-11');
      expect((keynote.start, keynote.end), ('10:00', '10:45'));
      expect(keynote.track, 'AI');
      expect(keynote.speakers.single.name, 'Mara Ilić');
      expect(sessions.first.isBreak, isTrue);
      expect(sessions.last.speakers.map((s) => s.id), ['sp5', 'sp2']);
      // Same ids and stages as the app's demo agenda (seeded into devfest).
      expect(
        sessions.map((s) => (s.id, s.stage)),
        demo.sessions.map((s) => (s.id, s.stage)),
      );
    });

    test('live by the clock, or pinned for the scripted demo', () async {
      // 10:15 on the event day: the keynote runs.
      var sessions = await repo().agenda('devfest');
      expect(sessions.where((s) => s.isLive).map((s) => s.id), ['s1']);
      // Another day: nothing is live.
      sessions = await repo(now: DateTime(2026, 10, 12, 10, 15))
          .agenda('devfest');
      expect(sessions.where((s) => s.isLive), isEmpty);
      // Pinned: exactly those, whatever the time.
      sessions = await repo(
        now: DateTime(2026, 10, 12, 18),
        pinnedLive: {
          'devfest': {'s1'},
        },
      ).agenda('devfest');
      expect(sessions.where((s) => s.isLive).map((s) => s.id), ['s1']);
    });

    test('invalid entries are skipped, unsafe ids rejected', () {
      final sessions = EventsApiRepository.parseAgenda({
        'sessions': [
          {'id': '../x', 'title': 'Bad id', 'start': '10:00', 'end': '11:00'},
          {'id': 'a', 'title': 'Bad time', 'start': '25:00', 'end': '11:00'},
          {'id': 'b', 'title': ' Ok ', 'start': '10:00', 'end': '11:00'},
          'junk',
        ],
      }, now: DateTime(2026));
      expect(sessions.single.id, 'b');
      expect(sessions.single.title, 'Ok');
      expect(
        () => EventsApiRepository.parseAgenda({}, now: DateTime(2026)),
        throwsA(isA<EventsException>()),
      );
    });

    test('date ranges', () {
      String f(String a, String b) => EventsApiRepository.formatDates(a, b);
      expect(f('2026-10-11', '2026-10-12'), 'Oct 11–12, 2026');
      expect(f('2026-10-11', '2026-10-11'), 'Oct 11, 2026');
      expect(f('2026-09-30', '2026-10-02'), 'Sep 30 – Oct 2, 2026');
      expect(f('2026-12-31', '2027-01-01'), 'Dec 31, 2026 – Jan 1, 2027');
      expect(f('soon', ''), '');
    });
  });

  group('organizer', () {
    test('createDraft: multipart files with the organizer token', () async {
      final draft = await repo().extract([
        _file('devfest-agenda-final-v3.pdf', 300),
        _file('speakers.xlsx', 100),
      ]);
      final upload = requests.single as http.Request;
      expect(upload.url.path, '/v1/organizer/drafts');
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(upload.bodyBytes);
      expect('name="files"'.allMatches(body), hasLength(2));
      expect(body, contains('filename="devfest-agenda-final-v3.pdf"'));
      expect(body, contains('filename="speakers.xlsx"'));
      expect(tokens.single, 'Bearer organizer-token');

      expect(draft.id, 'k2v9q3m1x8a7b6c5');
      expect(draft.name, 'DevFest Belgrade 2026');
      expect(draft.dates, demo.demoEventDates);
      expect((draft.startDate, draft.endDate), ('2026-10-11', '2026-10-12'));
      expect(draft.venue, 'Sava Centar, Belgrade');
      expect(draft.stages, ['Glavna sala', 'Sala A', 'Sala B']);
      expect(draft.speakers, hasLength(6));
      expect(draft.sessions, hasLength(5));
      // The session the AI couldn't place is flagged in the review.
      expect(draft.sessions[1].stage, isEmpty);
      // ... and the server says so in `issues`.
      expect(draft.issues, hasLength(1));
      expect(draft.issues.single.sessionId, 'd2');
      expect(draft.issues.single.field, 'sessions[1].stage');
      expect(draft.issues.single.message, 'No stage found for this session.');
    });

    test('issues and warnings: parsed, bad entries skipped', () {
      final json = Map<String, Object?>.of(
        _fixture('draft.response.json') as Map<String, Object?>,
      );
      json['issues'] = [
        {'severity': 'warning', 'field': 'name', 'message': 'No event name.'},
        {'sessionId': 'd3', 'field': 'sessions[2].end', 'message': '  '},
        {'sessionId': 'd3', 'field': 'sessions[2].end'},
        {'sessionId': 'bad id!', 'message': 'Odd id.'},
        'nope',
        null,
        {'sessionId': 'd3', 'field': 'sessions[2].end', 'message': 'Overlaps.'},
      ];
      final draft = EventsApiRepository.parseDraft(json)!;
      expect(
        [for (final i in draft.issues) (i.sessionId, i.field, i.message)],
        [
          (null, 'name', 'No event name.'),
          (null, '', 'Odd id.'),
          ('d3', 'sessions[2].end', 'Overlaps.'),
        ],
      );
      // Missing or malformed `issues` doesn't fail the draft.
      json['issues'] = 'x';
      expect(EventsApiRepository.parseDraft(json)!.issues, isEmpty);
      json.remove('issues');
      expect(EventsApiRepository.parseDraft(json)!.sessions, hasLength(5));

      final link = EventsApiRepository.parsePublish({
        'eventId': 'devfest',
        'warnings': [
          "Stage 'Sala C' isn't a room on the venue map.",
          '',
          42,
          null,
        ],
      }, 'https://eho.app')!;
      expect(link.warnings, ["Stage 'Sala C' isn't a room on the venue map."]);
      expect(
        EventsApiRepository.parsePublish(
          _fixture('publish.response.json'),
          'https://eho.app',
        )!.warnings,
        isEmpty,
      );
      expect(
        EventsApiRepository.parsePublish({
          'eventId': 'devfest',
        }, 'https://eho.app')!.warnings,
        isEmpty,
      );
    });

    test('issues are never sent back', () async {
      final draft = EventsApiRepository.parseDraft(
        _fixture('draft.response.json'),
      )!;
      expect(draft.issues, isNotEmpty);
      expect(EventsApiRepository.draftInput(draft), isNot(contains('issues')));
      // Sessions edited locally keep their issues until the next save.
      expect(draft.withSessions(draft.sessions).issues, draft.issues);
    });

    test('upload limits are checked before sending', () async {
      Future<EventsErrorKind?> kind(List<UploadedFile> files) => repo()
          .extract(files)
          .then<EventsErrorKind?>(
            (_) => null,
            onError: (Object e) => (e as EventsException).kind,
          );
      expect(
        await kind([for (var i = 0; i < 11; i++) _file('$i.csv', 1)]),
        EventsErrorKind.tooLarge,
      );
      expect(
        await kind([_file('big.pdf', 10 * 1024 * 1024 + 1)]),
        EventsErrorKind.tooLarge,
      );
      expect(
        await kind([
          _file('a.pdf', 8 << 20),
          _file('b.pdf', 8 << 20),
          _file('c.pdf', 8 << 20),
        ]),
        EventsErrorKind.tooLarge,
      );
      // Placeholder files without bytes can't be uploaded.
      expect(
        await kind([const UploadedFile(name: 'x.pdf', sizeBytes: 1)]),
        EventsErrorKind.failed,
      );
      expect(requests, isEmpty);
    });

    test(
      'publish: saves unsaved edits, then publishes into the event',
      () async {
        final r = repo();
        final draft = await r.extract([_file('agenda.csv', 10)]);
        // Publishing the draft as extracted: no save needed.
        var link = await r.publish(draft);
        expect(link.eventId, 'devfest');
        expect(link.url, 'https://eho.app/e/devfest');
        expect(jsonDecode(bodies.last), _fixture('publish.request.json'));

        // An edit: the stage gets filled in; publish saves it first.
        final edited = draft.withSessions([
          for (final s in draft.sessions)
            s.stage.isEmpty
                ? Session(
                    id: s.id,
                    title: s.title,
                    stage: 'Sala A',
                    start: s.start,
                    end: s.end,
                    speakers: s.speakers,
                  )
                : s,
        ]);
        requests.clear();
        bodies.clear();
        link = await r.publish(edited);
        expect(
          [for (final q in requests) '${q.method} ${q.url.path}'],
          [
            'PUT /v1/organizer/drafts/k2v9q3m1x8a7b6c5',
            'POST /v1/organizer/drafts/k2v9q3m1x8a7b6c5/publish',
          ],
        );
        final input = jsonDecode(bodies.first) as Map<String, dynamic>;
        expect(input.keys.toSet(), {
          'name',
          'startDate',
          'endDate',
          'address',
          'stages',
          'speakers',
          'sessions',
        });
        final sent = (input['sessions'] as List).cast<Map<String, dynamic>>();
        expect(sent[1]['stage'], 'Sala A');
        // A session without a day gets the event's start date.
        expect(sent[1]['day'], '2026-10-11');
        expect(sent[0]['speakers'], [
          {
            'id': 'sp1',
            'name': 'Mara Ilić',
            'title': 'ML Engineer, Lumen Labs',
          },
        ]);
      },
    );

    test('save returns the stored draft', () async {
      final r = repo();
      final draft = await r.extract([_file('agenda.csv', 10)]);
      final saved = await r.save(
        draft.withSessions(draft.sessions.take(2).toList()),
      );
      expect(saved.sessions, hasLength(5));
      expect(requests.last.method, 'PUT');
    });
  });

  group('errors', () {
    EventsException err(int status, Object? body, [String? retry]) =>
        EventsApiRepository.errorFor(status, body, retry);

    test('contract error codes map to kinds', () {
      expect(
        err(422, _fixture('validation-error.response.json')).kind,
        EventsErrorKind.invalid,
      );
      expect(
        err(422, _fixture('validation-error.response.json')).message,
        contains('sessions[0].start'),
      );
      expect(
        err(403, {'code': 'organizer_account_required', 'message': 'm'}).kind,
        EventsErrorKind.organizerRequired,
      );
      expect(
        err(403, {'code': 'forbidden', 'message': 'm'}).kind,
        EventsErrorKind.forbidden,
      );
      expect(
        err(404, {'code': 'not_found', 'message': 'm'}).kind,
        EventsErrorKind.notFound,
      );
      expect(
        err(413, {'code': 'too_large', 'message': 'm'}).kind,
        EventsErrorKind.tooLarge,
      );
      final unsupported = err(415, {
        'code': 'unsupported_file',
        'message': 'm',
        'details': [
          {'field': 'slides.key', 'message': 'not supported'},
        ],
      });
      expect(unsupported.kind, EventsErrorKind.unsupportedFile);
      expect(unsupported.message, 'slides.key');
      expect(
        err(422, {'code': 'nothing_extracted', 'message': 'm'}).kind,
        EventsErrorKind.nothingExtracted,
      );
      expect(
        err(503, {'code': 'ai_unavailable', 'message': 'm'}).kind,
        EventsErrorKind.aiBusy,
      );
      final limited = err(429, {'code': 'rate_limited', 'message': 'm'}, '7');
      expect(limited.kind, EventsErrorKind.rateLimited);
      expect(limited.retryAfter, const Duration(seconds: 7));
      expect(err(500, null).kind, EventsErrorKind.failed);
    });

    test('a failing HTTP call surfaces as EventsException', () async {
      final r = repo(
        handler: (_) async => throw http.ClientException('connection refused'),
      );
      await expectLater(
        r.getEvent('devfest'),
        throwsA(
          isA<EventsException>().having(
            (e) => e.kind,
            'kind',
            EventsErrorKind.offline,
          ),
        ),
      );
    });
  });

  group('fallback to demo data', () {
    test('service down → demo event, agenda and organizer', () async {
      final down = repo(handler: (_) async => http.Response('', 503));
      final events = FallbackEventRepository(
        primary: down,
        fallback: DemoEventRepository(),
      );
      expect((await events.getEvent('devfest')).name, demo.demoEventName);
      expect(await events.agenda('devfest'), demo.sessions);
      expect(await events.myEvents(), isEmpty);
      final organizer = FallbackOrganizerRepository(
        primary: down,
        fallback: DemoOrganizerRepository('devfest', 'https://eho.app'),
      );
      final link = await organizer.publish(
        await organizer.extract(const [
          UploadedFile(name: 'agenda.pdf', sizeBytes: 1),
        ]),
      );
      expect(link.url, 'https://eho.app/e/devfest');
      // Only the health check went to the service.
      expect(requests.map((r) => r.url.path).toSet(), {'/healthz'});
    });

    test(
      'service up → API; unknown demo event → demo; no agenda → empty',
      () async {
        Future<http.Response> notSeeded(http.Request r) async =>
            r.url.path == '/healthz'
            ? _json({'status': 'ok', 'model': 'offline'})
            : _json({'code': 'not_found', 'message': 'not found'}, 404);
        final events = FallbackEventRepository(
          primary: repo(handler: notSeeded),
          fallback: DemoEventRepository(),
          demoEventIds: {'devfest'},
        );
        expect((await events.getEvent('devfest')).name, demo.demoEventName);
        expect(await events.agenda('devfest'), demo.sessions);
        expect(await events.agenda('other'), isEmpty);
        await expectLater(
          events.getEvent('other'),
          throwsA(isA<EventsException>()),
        );

        final live = FallbackEventRepository(
          primary: repo(),
          fallback: DemoEventRepository(),
        );
        expect((await live.myEvents()).map((e) => e.id), [
          'devfest',
          'ai-meetup-ns-2026',
        ]);
      },
    );
  });

  group('JoinedEventsNotifier', () {
    test(
      'merges My events from the server; leaving calls the server',
      () async {
        const server = EventSummary(
          id: 'devfest',
          name: 'DevFest Belgrade 2026',
          dates: 'Oct 11–12, 2026',
          venue: 'Sava Centar, Belgrade',
        );
        final events = _RecordingEvents([server]);
        final c = ProviderContainer(
          overrides: [eventRepositoryProvider.overrideWithValue(events)],
        );
        addTearDown(c.dispose);
        expect(c.read(joinedEventsProvider), [demo.pastEvent]);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(joinedEventsProvider).map((e) => e.id), [
          'devfest',
          demo.pastEvent.id,
        ]);
        c.read(joinedEventsProvider.notifier).remove('devfest');
        expect(events.left, ['devfest']);
        expect(c.read(joinedEventsProvider), [demo.pastEvent]);
      },
    );
  });
}
