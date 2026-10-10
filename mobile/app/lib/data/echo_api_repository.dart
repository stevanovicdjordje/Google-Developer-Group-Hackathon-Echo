/// Echo backed by the Echo service (`contracts/echo` 0.1.0, `backend/echo`).
///
/// The transcript comes from a Firestore listener (`contracts/echo/realtime.md`),
/// everything else from the HTTP API. All server and model output is treated
/// as untrusted display text: shapes are checked, lengths capped, and nothing
/// is ever interpreted (`AGENTS.md` rule 12).
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/api/api_client.dart' show TokenProvider;
import 'models.dart';
import 'repositories.dart';

/// Raw transcript documents, behind an interface so tests can fake Firestore.
abstract interface class EchoTranscriptSource {
  /// `events/{e}/published/echo/sessions/{s}`; null while it doesn't exist.
  Stream<Map<String, Object?>?> session(String eventId, String sessionId);

  /// Its `lines` subcollection ordered by `index`.
  Stream<List<Map<String, Object?>>> lines(String eventId, String sessionId);
}

class FirestoreEchoTranscriptSource implements EchoTranscriptSource {
  FirestoreEchoTranscriptSource(this._db, this._signIn);

  final FirebaseFirestore _db;

  /// Reading `published/` needs a signed-in user (anonymous is fine).
  final Future<void> Function() _signIn;

  DocumentReference<Map<String, dynamic>> _doc(String e, String s) => _db
      .collection('events')
      .doc(e)
      .collection('published')
      .doc('echo')
      .collection('sessions')
      .doc(s);

  @override
  Stream<Map<String, Object?>?> session(
    String eventId,
    String sessionId,
  ) async* {
    await _signIn();
    yield* _doc(eventId, sessionId).snapshots().map((d) => d.data());
  }

  @override
  Stream<List<Map<String, Object?>>> lines(
    String eventId,
    String sessionId,
  ) async* {
    await _signIn();
    yield* _doc(eventId, sessionId)
        .collection('lines')
        .orderBy('index')
        .snapshots()
        .map((q) => [for (final d in q.docs) d.data()]);
  }
}

/// ID token of the current user, signing in anonymously on first use (once,
/// even when several calls race).
TokenProvider anonymousIdToken(FirebaseAuth auth) {
  Future<User?>? signingIn;
  return () async {
    var user = auth.currentUser;
    if (user == null) {
      signingIn ??= auth.signInAnonymously().then((c) => c.user).catchError((
        Object e,
      ) {
        signingIn = null;
        throw e;
      });
      user = await signingIn;
    }
    return user?.getIdToken();
  };
}

class EchoApiRepository implements EchoRepository {
  EchoApiRepository({
    required this.baseUrl,
    required this.tokenProvider,
    required this.transcriptSource,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.aiTimeout = const Duration(seconds: 30),
    this.language = 'en',
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenProvider tokenProvider;
  final EchoTranscriptSource transcriptSource;
  final Duration timeout;

  /// The server gives the model 20 s (+1 retry on 5xx) before `502`.
  final Duration aiTimeout;

  /// Language of catch-up, answers and summary (the app UI is English).
  final String language;
  final http.Client _http;

  static const _maxAiText = 4000;
  static const _maxLine = 2000;
  static const _maxQuestion = 300;

  /// True when `/healthz` answers within [within].
  Future<bool> isReachable({
    Duration within = const Duration(seconds: 2),
  }) async {
    try {
      final r = await _http.get(Uri.parse('$baseUrl/healthz')).timeout(within);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ transcript

  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) {
    late final StreamController<List<TranscriptLine>> out;
    StreamSubscription<Object?>? linesSub, sessionSub;
    List<TranscriptLine>? lines;
    Map<String, Object?>? session;

    Future<void> stop() async {
      await linesSub?.cancel();
      await sessionSub?.cancel();
    }

    // Done once the replay has ended and every line has arrived.
    void checkEnded() {
      final l = lines;
      if (l == null || out.isClosed || session?['status'] != 'ended') return;
      final count = session?['lineCount'];
      if (count is num && l.length < count) return;
      stop();
      out.close();
    }

    out = StreamController<List<TranscriptLine>>(
      onListen: () {
        linesSub = transcriptSource.lines(eventId, sessionId).listen((raw) {
          lines = parseTranscriptLines(raw);
          out.add(lines!);
          checkEnded();
        }, onError: out.addError);
        sessionSub = transcriptSource.session(eventId, sessionId).listen((d) {
          session = d;
          checkEnded();
        }, onError: out.addError);
      },
      onCancel: stop,
    );
    return out.stream;
  }

  /// Valid lines in order. Stops at the first invalid line or gap, so a
  /// line's position in the list always equals its `index` (translations
  /// are addressed by index).
  static List<TranscriptLine> parseTranscriptLines(
    List<Map<String, Object?>> raw,
  ) {
    final result = <TranscriptLine>[];
    for (final d in raw) {
      final index = d['index'], at = d['atSeconds'], text = d['text'];
      if (index is! num || index.toInt() != result.length) break;
      if (at is! num || at < 0 || text is! String || text.trim().isEmpty) {
        break;
      }
      result.add(
        TranscriptLine(
          atSeconds: at.toInt(),
          text: _cap(text.trim(), _maxLine),
          translated: '',
        ),
      );
    }
    return List.unmodifiable(result);
  }

  // ------------------------------------------------------------ AI

  @override
  Future<String> catchUp(String eventId, String sessionId) async => _aiText(
    await _send(
      'GET',
      _path(eventId, sessionId, 'catch-up'),
      query: {'language': language},
      timeout: aiTimeout,
    ),
  );

  @override
  Future<String> ask(String eventId, String sessionId, String question) async {
    final q = question.trim();
    return _aiText(
      await _send(
        'POST',
        _path(eventId, sessionId, 'ask'),
        body: {
          'question': q.length > 500 ? q.substring(0, 500) : q,
          'language': language,
        },
        timeout: aiTimeout,
      ),
    );
  }

  @override
  Future<String> fullSummary(String eventId, String sessionId) async => _aiText(
    await _send(
      'GET',
      _path(eventId, sessionId, 'summary'),
      query: {'language': language},
      timeout: aiTimeout,
    ),
  );

  @override
  Future<TranscriptTranslation> translate(
    String eventId,
    String sessionId, {
    required String language,
    int fromIndex = 0,
  }) async {
    final json = await _send(
      'POST',
      _path(eventId, sessionId, 'translate'),
      body: {'language': language, 'fromIndex': fromIndex},
      timeout: aiTimeout,
    );
    if (json is! Map<String, Object?>) throw _badResponse;
    final rawLines = json['lines'], next = json['nextIndex'];
    if (rawLines is! List || next is! num) throw _badResponse;
    final lines = <int, String>{};
    for (final l in rawLines) {
      if (l is! Map) continue;
      final i = l['index'], t = l['text'];
      if (i is num && i >= fromIndex && t is String) {
        lines[i.toInt()] = _cap(t.trim(), _maxLine);
      }
    }
    // Never go backwards, or the caller would loop.
    final nextIndex = next.toInt() < fromIndex ? fromIndex : next.toInt();
    return (lines: lines, nextIndex: nextIndex);
  }

  // ------------------------------------------------------------ questions

  @override
  Future<List<SpeakerQuestion>> questions(
    String eventId,
    String sessionId,
  ) async {
    final json = await _send('GET', _path(eventId, sessionId, 'questions'));
    final list = json is Map<String, Object?> ? json['questions'] : null;
    if (list is! List) throw _badResponse;
    return [
      for (final q in list)
        if (_question(q) case final SpeakerQuestion parsed) parsed,
    ];
  }

  @override
  Future<SpeakerQuestion> submitQuestion(
    String eventId,
    String sessionId,
    String text,
  ) async {
    final t = text.trim();
    final json = await _send(
      'POST',
      _path(eventId, sessionId, 'questions'),
      body: {
        'text': t.length > _maxQuestion ? t.substring(0, _maxQuestion) : t,
      },
    );
    return _question(json) ?? (throw _badResponse);
  }

  @override
  Future<SpeakerQuestion> vote(
    String eventId,
    String sessionId,
    SpeakerQuestion question, {
    required bool up,
  }) async {
    final id = Uri.encodeComponent(question.id);
    final json = await _send(
      up ? 'PUT' : 'DELETE',
      _path(eventId, sessionId, 'questions/$id/vote'),
    );
    return _question(json) ?? (throw _badResponse);
  }

  static SpeakerQuestion? _question(Object? q) {
    if (q is! Map) return null;
    final id = q['id'], text = q['text'], votes = q['votes'];
    if (id is! String || id.isEmpty || text is! String || votes is! num) {
      return null;
    }
    return SpeakerQuestion(
      id: id,
      text: _cap(text.trim(), _maxQuestion),
      votes: votes < 0 ? 0 : votes.toInt(),
      mine: q['mine'] == true,
      voted: q['voted'] == true,
    );
  }

  // ------------------------------------------------------------ HTTP

  static const _badResponse = EchoException(
    EchoErrorKind.failed,
    'unexpected response',
  );

  static String _cap(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;

  static String _aiText(Object? json) {
    final text = json is Map<String, Object?> ? json['text'] : null;
    if (text is! String || text.trim().isEmpty) throw _badResponse;
    return _cap(text.trim(), _maxAiText);
  }

  String _path(String eventId, String sessionId, String rest) =>
      '/v1/events/${Uri.encodeComponent(eventId)}'
      '/sessions/${Uri.encodeComponent(sessionId)}/$rest';

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
  }) async {
    final wait = timeout ?? this.timeout;
    final request = http.Request(
      method,
      Uri.parse('$baseUrl$path').replace(queryParameters: query),
    );
    try {
      final token = await tokenProvider().timeout(this.timeout);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    } catch (e) {
      throw EchoException(EchoErrorKind.offline, 'sign-in failed: $e');
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(wait),
      ).timeout(wait);
    } on TimeoutException {
      throw const EchoException(EchoErrorKind.aiBusy, 'request timed out');
    } on http.ClientException catch (e) {
      throw EchoException(EchoErrorKind.offline, e.message);
    }

    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;

    final code = json is Map<String, Object?> && json['code'] is String
        ? json['code'] as String
        : '';
    final message = json is Map<String, Object?> && json['message'] is String
        ? json['message'] as String
        : 'HTTP $status';
    if (status == 429 || code == 'rate_limited') {
      final retry = int.tryParse(response.headers['retry-after'] ?? '');
      throw EchoException(
        EchoErrorKind.rateLimited,
        message,
        retry == null ? null : Duration(seconds: retry),
      );
    }
    if (status == 502 || status == 503 || code == 'ai_unavailable') {
      throw EchoException(EchoErrorKind.aiBusy, message);
    }
    if (code == 'no_transcript') {
      throw EchoException(EchoErrorKind.noTranscript, message);
    }
    throw EchoException(EchoErrorKind.failed, '$code $message'.trim());
  }
}

/// Uses [primary] when its service answers `/healthz` on first use,
/// otherwise [fallback] (demo data) for the rest of the app's life.
class FallbackEchoRepository implements EchoRepository {
  FallbackEchoRepository({required this.primary, required this.fallback});

  final EchoApiRepository primary;
  final EchoRepository fallback;

  late final Future<EchoRepository> _target = primary.isReachable().then(
    (ok) => ok ? primary : fallback,
  );

  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream.fromFuture(_target)
          .asyncExpand((r) => r.transcript(eventId, sessionId));

  @override
  Future<String> catchUp(String eventId, String sessionId) async =>
      (await _target).catchUp(eventId, sessionId);

  @override
  Future<String> ask(String eventId, String sessionId, String question) async =>
      (await _target).ask(eventId, sessionId, question);

  @override
  Future<List<SpeakerQuestion>> questions(
    String eventId,
    String sessionId,
  ) async => (await _target).questions(eventId, sessionId);

  @override
  Future<SpeakerQuestion> submitQuestion(
    String eventId,
    String sessionId,
    String text,
  ) async => (await _target).submitQuestion(eventId, sessionId, text);

  @override
  Future<SpeakerQuestion> vote(
    String eventId,
    String sessionId,
    SpeakerQuestion question, {
    required bool up,
  }) async => (await _target).vote(eventId, sessionId, question, up: up);

  @override
  Future<String> fullSummary(String eventId, String sessionId) async =>
      (await _target).fullSummary(eventId, sessionId);

  @override
  Future<TranscriptTranslation> translate(
    String eventId,
    String sessionId, {
    required String language,
    int fromIndex = 0,
  }) async => (await _target).translate(
    eventId,
    sessionId,
    language: language,
    fromIndex: fromIndex,
  );
}
