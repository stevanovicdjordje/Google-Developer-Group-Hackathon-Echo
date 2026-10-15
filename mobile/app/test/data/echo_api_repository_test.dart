import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eho/data/echo_api_repository.dart';
import 'package:eho/data/echo_models.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Firestore stand-in: tests push raw documents into the controllers.
class _FakeSource implements EchoTranscriptSource {
  final sessionDoc = StreamController<Map<String, Object?>?>();
  final lineDocs = StreamController<List<Map<String, Object?>>>();

  @override
  Stream<Map<String, Object?>?> session(String eventId, String sessionId) =>
      sessionDoc.stream;

  @override
  Stream<List<Map<String, Object?>>> lines(String eventId, String sessionId) =>
      lineDocs.stream;
}

/// A fixture from `contracts/echo/examples/` (tests run in `mobile/app`).
Object? _fixture(String name) =>
    jsonDecode(File('../../contracts/echo/examples/$name').readAsStringSync());

Map<String, Object?> _line(int i, [String? text]) => {
  'index': i,
  'atSeconds': i * 4,
  'text': text ?? 'Line $i',
};

void main() {
  late _FakeSource source;
  late List<http.Request> requests;

  EchoApiRepository repo(MockClientHandler handler) {
    requests = [];
    return EchoApiRepository(
      baseUrl: 'http://echo.test',
      tokenProvider: () async => 'tok',
      transcriptSource: source,
      httpClient: MockClient((req) {
        requests.add(req);
        return handler(req);
      }),
    );
  }

  http.Response json(Object body, [int status = 200, Map<String, String>? h]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8', ...?h},
      );

  setUp(() => source = _FakeSource());

  group('transcript', () {
    test('maps Firestore lines and ends when the replay has ended', () async {
      final r = repo((_) async => json({}));
      final events = <List<TranscriptLine>>[];
      final done = Completer<void>();
      r.transcript('ev', 's1').listen(events.add, onDone: done.complete);

      source.sessionDoc.add({'status': 'live', 'lineCount': 1});
      source.lineDocs.add([_line(0)]);
      await pumpEventQueue();
      expect(events.single.single.text, 'Line 0');
      expect(events.single.single.atSeconds, 0);
      expect(events.single.single.translated, '');

      source.lineDocs.add([_line(0), _line(1)]);
      source.sessionDoc.add({'status': 'ended', 'lineCount': 2});
      await done.future.timeout(const Duration(seconds: 1));
      expect(events.last.map((l) => l.text), ['Line 0', 'Line 1']);
    });

    test('waits for every line before ending', () async {
      final r = repo((_) async => json({}));
      var ended = false;
      r.transcript('ev', 's1').listen((_) {}, onDone: () => ended = true);
      source.sessionDoc.add({'status': 'ended', 'lineCount': 3});
      source.lineDocs.add([_line(0), _line(1)]);
      await pumpEventQueue();
      expect(ended, isFalse);
      source.lineDocs.add([_line(0), _line(1), _line(2)]);
      await pumpEventQueue();
      expect(ended, isTrue);
    });

    test('stops at the first invalid line or gap', () {
      final lines = EchoApiRepository.parseTranscriptLines([
        _line(0),
        _line(1),
        {'index': 2, 'atSeconds': 'soon', 'text': 'bad'},
        _line(3),
      ]);
      expect(lines.map((l) => l.text), ['Line 0', 'Line 1']);
      expect(
        EchoApiRepository.parseTranscriptLines([_line(0), _line(2)]).length,
        1,
      );
    });

    test('Firestore errors reach the listener', () async {
      final r = repo((_) async => json({}));
      final errors = <Object>[];
      r.transcript('ev', 's1').listen((_) {}, onError: errors.add);
      source.lineDocs.addError(StateError('permission-denied'));
      await pumpEventQueue();
      expect(errors, hasLength(1));
    });
  });

  group('AI', () {
    test('ask posts the question with the token and returns text', () async {
      final r = repo(
        (req) async => json({
          'text': '  About 12%.  ',
          'model': 'offline',
          'basedOnLines': 11,
        }),
      );
      expect(await r.ask('ev', 's1', 'Battery?'), 'About 12%.');
      final req = requests.single;
      expect(req.method, 'POST');
      expect(
        req.url.toString(),
        'http://echo.test/v1/events/ev/sessions/s1/ask',
      );
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(req.body), {'question': 'Battery?', 'language': 'en'});
    });

    test('catch-up and summary use GET with the language', () async {
      final r = repo(
        (req) async => json({'text': 'ok', 'model': 'm', 'basedOnLines': 1}),
      );
      await r.catchUp('ev', 's1');
      await r.fullSummary('ev', 's1');
      expect(requests.map((r) => r.url.toString()), [
        'http://echo.test/v1/events/ev/sessions/s1/catch-up?language=en',
        'http://echo.test/v1/events/ev/sessions/s1/summary?language=en',
      ]);
    });

    test('language=sr reaches catch-up, ask and summary', () async {
      final r = repo(
        (req) async => json({'text': 'ok', 'model': 'm', 'basedOnLines': 1}),
      );
      await r.catchUp('ev', 's1', language: 'sr');
      await r.ask('ev', 's1', 'Baterija?', language: 'sr');
      await r.fullSummary('ev', 's1', language: 'sr');
      expect(requests[0].url.queryParameters['language'], 'sr');
      expect(jsonDecode(requests[1].body)['language'], 'sr');
      expect(requests[2].url.queryParameters['language'], 'sr');
    });

    test('summary: structured fields from the 0.3.0 fixture', () async {
      final r = repo((req) async => json(_fixture('summary.response.json')!));
      final s = await r.fullSummary('ev', 's1');
      expect(s.text, startsWith('• Cost:'));
      final t = s.summary!;
      expect(
        t.takeaway,
        'Start hybrid, measure, and move work down to the device over time.',
      );
      expect(t.keyPoints, hasLength(2));
      expect(t.tradeoffs.map((x) => x.topic), [
        'Battery',
        'Model size',
        'Hard questions',
      ]);
      expect(t.tradeoffs.map((x) => x.atSeconds), [44, 60, 71]);
      expect(
        t.tradeoffs.first.fix,
        'Batch audio in 2-second chunks (down to 4%)',
      );
    });

    test('summary without `summary` (older server) has text only', () async {
      final r = repo((req) async => json(_fixture('catch-up.response.json')!));
      final s = await r.fullSummary('ev', 's1');
      expect(s.text, isNotEmpty);
      expect(s.summary, isNull);
    });

    test('model text is capped and must be a string', () async {
      var text = 'x' * 5000 as Object;
      final r = repo(
        (req) async => json({'text': text, 'model': 'm', 'basedOnLines': 1}),
      );
      expect((await r.catchUp('ev', 's1')).length, lessThan(4010));
      text = 42;
      await expectLater(
        r.catchUp('ev', 's1'),
        throwsA(
          isA<EchoException>().having(
            (e) => e.kind,
            'kind',
            EchoErrorKind.failed,
          ),
        ),
      );
    });

    test('502 → aiBusy, 429 → rateLimited with Retry-After', () async {
      var status = 502;
      final r = repo(
        (req) async => json(
          {
            'code': status == 502 ? 'ai_unavailable' : 'rate_limited',
            'message': 'nope',
          },
          status,
          {'retry-after': '17'},
        ),
      );
      await expectLater(
        r.ask('ev', 's1', 'q'),
        throwsA(
          isA<EchoException>().having(
            (e) => e.kind,
            'kind',
            EchoErrorKind.aiBusy,
          ),
        ),
      );
      status = 429;
      await expectLater(
        r.ask('ev', 's1', 'q'),
        throwsA(
          isA<EchoException>()
              .having((e) => e.kind, 'kind', EchoErrorKind.rateLimited)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 17),
              ),
        ),
      );
    });

    test('no_transcript and network failures are typed', () async {
      var offline = false;
      final r = repo((req) async {
        if (offline) throw http.ClientException('down');
        return json({'code': 'no_transcript', 'message': 'none'}, 404);
      });
      await expectLater(
        r.catchUp('ev', 's2'),
        throwsA(
          isA<EchoException>().having(
            (e) => e.kind,
            'kind',
            EchoErrorKind.noTranscript,
          ),
        ),
      );
      offline = true;
      await expectLater(
        r.catchUp('ev', 's2'),
        throwsA(
          isA<EchoException>().having(
            (e) => e.kind,
            'kind',
            EchoErrorKind.offline,
          ),
        ),
      );
    });

    test('translate maps lines by index and never goes backwards', () async {
      final r = repo(
        (req) async => json({
          'language': 'sr',
          'lines': [
            {'index': 2, 'text': 'Dva'},
            {'index': 3, 'text': 'Tri'},
            {'index': 'x', 'text': 'bad'},
            'junk',
          ],
          'nextIndex': 4,
          'model': 'm',
        }),
      );
      final t = await r.translate('ev', 's1', language: 'sr', fromIndex: 2);
      expect(t.lines, {2: 'Dva', 3: 'Tri'});
      expect(t.nextIndex, 4);
      expect(jsonDecode(requests.single.body), {
        'language': 'sr',
        'fromIndex': 2,
      });

      final stale = repo(
        (req) async => json({
          'language': 'sr',
          'lines': <Object>[],
          'nextIndex': 0,
          'model': 'm',
        }),
      );
      final s = await stale.translate('ev', 's1', language: 'sr', fromIndex: 5);
      expect(s.nextIndex, 5);
    });
  });

  group('questions', () {
    final q1 = {
      'id': 'q_1',
      'text': 'Which quantization?',
      'votes': 7,
      'mine': false,
      'voted': true,
      'createdAt': '2026-10-11T10:21:04Z',
    };

    test('list skips malformed entries', () async {
      final r = repo(
        (req) async => json({
          'questions': [
            q1,
            {'id': 'q_2'},
            'junk',
          ],
        }),
      );
      final qs = await r.questions('ev', 's1');
      expect(qs, hasLength(1));
      expect(qs.single.id, 'q_1');
      expect(qs.single.votes, 7);
      expect(qs.single.voted, isTrue);
      expect(qs.single.mine, isFalse);
    });

    test('submit posts text and returns the created question', () async {
      final r = repo(
        (req) async => json({...q1, 'mine': true, 'votes': 1}, 201),
      );
      final sent = await r.submitQuestion('ev', 's1', ' Does it run on iOS? ');
      expect(sent.question.mine, isTrue);
      expect(sent.merged, isFalse);
      expect(jsonDecode(requests.single.body), {'text': 'Does it run on iOS?'});
    });

    test('mergedCount from the 0.3.0 list fixture', () async {
      final r = repo((req) async => json(_fixture('questions.response.json')!));
      final qs = await r.questions('ev', 's1');
      expect(qs.map((q) => q.mergedCount), [3, 0]);
    });

    test('200 with merged: true is a merged submission', () async {
      final r = repo(
        (req) async => json(_fixture('submit-question-merged.response.json')!),
      );
      final sent = await r.submitQuestion('ev', 's1', 'What router model?');
      expect(sent.merged, isTrue);
      expect(sent.question.id, 'q_3fZx81');
      expect(sent.question.votes, 15);
      expect(sent.question.mergedCount, 4);
      expect(sent.question.mine, isTrue);
      expect(sent.question.voted, isTrue);
    });

    test('vote uses PUT, unvote DELETE', () async {
      final r = repo((req) async => json({...q1, 'votes': 8}));
      final q = SpeakerQuestion(id: 'q_1', text: 't', votes: 7);
      expect((await r.vote('ev', 's1', q, up: true)).votes, 8);
      await r.vote('ev', 's1', q, up: false);
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'PUT /v1/events/ev/sessions/s1/questions/q_1/vote',
        'DELETE /v1/events/ev/sessions/s1/questions/q_1/vote',
      ]);
    });
  });

  group('TalkSummary.tryParse (untrusted model output)', () {
    test('drops wrong types, caps lengths and list sizes', () {
      final t = TalkSummary.tryParse({
        'takeaway': '  ${'x' * 400}  ',
        'keyPoints': ['One', '', 7, null, for (var i = 0; i < 9; i++) 'P$i'],
        'tradeoffs': [
          {'topic': 'Battery', 'issue': 'a', 'fix': 'b', 'atSeconds': 44},
          {'topic': 'No time', 'issue': 'a', 'fix': 'b', 'atSeconds': 'soon'},
          {'topic': 'Negative', 'issue': 'a', 'fix': 'b', 'atSeconds': -3},
          {'topic': '', 'issue': 'a', 'fix': 'b', 'atSeconds': 1},
          {'topic': 'Empty', 'issue': '', 'fix': ' '},
          'junk',
          for (var i = 0; i < 9; i++)
            {'topic': 'T$i', 'issue': 'a', 'fix': 'b', 'atSeconds': i},
        ],
      })!;
      expect(t.takeaway.length, 301); // 300 + ellipsis
      expect(t.keyPoints, hasLength(5));
      expect(t.keyPoints.first, 'One');
      expect(t.tradeoffs, hasLength(5));
      expect(t.tradeoffs[0].atSeconds, 44);
      expect(t.tradeoffs[1].atSeconds, isNull);
      expect(t.tradeoffs[2].atSeconds, isNull);
      expect(t.tradeoffs.map((x) => x.topic), isNot(contains('Empty')));
    });

    test('null when nothing usable (falls back to text)', () {
      expect(TalkSummary.tryParse(null), isNull);
      expect(TalkSummary.tryParse('text'), isNull);
      expect(
        TalkSummary.tryParse({
          'takeaway': ' ',
          'keyPoints': [],
          'tradeoffs': [],
        }),
        isNull,
      );
      // No takeaway: the first key point stands in.
      expect(
        TalkSummary.tryParse({
          'keyPoints': ['A', 'B'],
        })!.takeaway,
        'A',
      );
    });
  });

  group('FallbackEchoRepository', () {
    test('uses the API when /healthz answers', () async {
      final api = repo((req) async {
        if (req.url.path == '/healthz') {
          return json({'status': 'ok', 'model': 'offline'});
        }
        return json({'text': 'from api', 'model': 'm', 'basedOnLines': 1});
      });
      final r = FallbackEchoRepository(
        primary: api,
        fallback: DemoEchoRepository(),
      );
      expect(await r.ask('ev', 's1', 'q'), 'from api');
    });

    test('falls back to demo data when the service is down', () async {
      final api = repo((req) async => throw http.ClientException('down'));
      final r = FallbackEchoRepository(
        primary: api,
        fallback: DemoEchoRepository(),
      );
      final qs = await r.questions('ev', 's1');
      expect(qs, isNotEmpty);
      expect(requests.map((r) => r.url.path), ['/healthz']);
    });
  });
}
