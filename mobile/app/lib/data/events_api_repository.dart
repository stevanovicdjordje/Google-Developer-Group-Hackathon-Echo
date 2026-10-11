/// Join, agenda, My events and the organizer import backed by the Events
/// service (`contracts/events` 0.1.0, `backend/events`).
///
/// Attendee calls use the (anonymous) Firebase ID token; `/v1/organizer/*`
/// needs an organizer account ([organizerIdToken]). Server and model output
/// is untrusted display text: shapes are checked, lengths capped and IDs
/// restricted (`AGENTS.md` rule 12).
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../core/api/api_client.dart' show TokenProvider;
import '../core/config.dart';
import 'demo_data.dart' as demo;
import 'models.dart';
import 'repositories.dart';

/// Demo organizer on the local emulators (`contracts/events/STATUS.md`), the
/// owner of the demo event. Used only when `USE_EMULATORS` is on.
const _demoOrganizerEmail = 'organizer@eho.test';
const _demoOrganizerPassword = 'eho-demo-123';
const _organizerAppName = 'eho-organizer';

/// ID token for `/v1/organizer/*`: the signed-in organizer when the app's
/// user is not anonymous (e.g. after signing in on the map editor `/o`).
/// Otherwise, on emulator builds only, the demo organizer, signed in on a
/// second Firebase app so the attendee's anonymous user stays as it is.
/// Without either it fails with [EventsErrorKind.organizerRequired].
TokenProvider organizerIdToken(FirebaseAuth auth, AppConfig config) {
  Future<FirebaseAuth>? demoAuth;
  return () async {
    final user = auth.currentUser;
    if (user != null && !user.isAnonymous) return user.getIdToken();
    if (!config.useEmulators) {
      throw const EventsException(
        EventsErrorKind.organizerRequired,
        'sign in as an organizer first',
      );
    }
    final pending = demoAuth ??= _demoOrganizerAuth(config);
    try {
      return await (await pending).currentUser?.getIdToken();
    } catch (_) {
      if (identical(demoAuth, pending)) demoAuth = null;
      rethrow;
    }
  };
}

Future<FirebaseAuth> _demoOrganizerAuth(AppConfig config) async {
  final app =
      Firebase.apps.where((a) => a.name == _organizerAppName).firstOrNull ??
      await Firebase.initializeApp(
        name: _organizerAppName,
        options: Firebase.app().options,
      );
  final auth = FirebaseAuth.instanceFor(app: app);
  try {
    // Port must match backend/firebase/firebase.json (as in firebase_init).
    await auth.useAuthEmulator(config.emulatorHost, 9099);
  } catch (_) {
    // Already pointed at the emulator (hot restart).
  }
  final user = auth.currentUser;
  if (user == null || user.isAnonymous) {
    await auth.signInWithEmailAndPassword(
      email: _demoOrganizerEmail,
      password: _demoOrganizerPassword,
    );
  }
  return auth;
}

class EventsApiRepository implements EventRepository, OrganizerRepository {
  EventsApiRepository({
    required this.baseUrl,
    required this.tokenProvider,
    required this.organizerTokenProvider,
    required this.publishEventId,
    required this.linkBase,
    this.pinnedLive = const {},
    DateTime Function()? clock,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.extractTimeout = const Duration(seconds: 75),
  }) : _clock = clock ?? DateTime.now,
       _http = httpClient ?? http.Client();

  final String baseUrl;

  /// Attendee token (anonymous is fine).
  final TokenProvider tokenProvider;

  /// Organizer token for `/v1/organizer/*`.
  final TokenProvider organizerTokenProvider;

  /// Event the organizer publishes into (the venue-map event, `devfest`).
  final String publishEventId;

  /// Origin put in front of `joinPath`.
  final String linkBase;

  /// Per event id, the sessions shown as live regardless of the clock (the
  /// scripted demo). Other events are live by their day and times.
  final Map<String, Set<String>> pinnedLive;

  final Duration timeout;

  /// `createDraft` runs the model synchronously (cut at 60 s on the server).
  final Duration extractTimeout;

  final DateTime Function() _clock;
  final http.Client _http;

  /// IDs go into app routes, so only plain IDs are accepted.
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _hhmm = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Contract upload limits.
  static const maxFiles = 10;
  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxTotalBytes = 20 * 1024 * 1024;

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

  /// [isReachable], checked once and shared by the fallback wrappers.
  late final Future<bool> reachable = isReachable();

  // ------------------------------------------------------------ attendee

  @override
  List<String> get interestOptions => demo.interestOptions;

  @override
  Future<EventSummary> getEvent(String eventId) async {
    final json = await _send('GET', '${_event(eventId)}/public');
    return parseEvent(json) ?? (throw _badResponse);
  }

  @override
  Future<void> join(String eventId) => _send('POST', '${_event(eventId)}/join');

  @override
  Future<void> leave(String eventId) =>
      _send('DELETE', '${_event(eventId)}/join');

  @override
  Future<bool> get isLive => reachable;

  @override
  Future<List<EventSummary>> myEvents() async =>
      parseMyEvents(await _send('GET', '/v1/me/events'));

  @override
  Future<List<Session>> agenda(String eventId) async {
    final json = await _send('GET', '${_event(eventId)}/agenda');
    return parseAgenda(json, pinned: pinnedLive[eventId], now: _clock());
  }

  // ------------------------------------------------------------ organizer

  /// The draft as the server last stored it; [publish] saves first when the
  /// organizer edited it since.
  EventDraft? _saved;

  @override
  Future<EventDraft> extract(List<UploadedFile> files) async {
    checkUpload(files);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/v1/organizer/drafts'),
    );
    for (final f in files) {
      request.files.add(
        http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name),
      );
    }
    final json = await _sendRequest(
      request,
      organizer: true,
      timeout: extractTimeout,
    );
    return _saved = parseDraft(json) ?? (throw _badResponse);
  }

  @override
  Future<EventDraft> save(EventDraft draft) async {
    final id = draft.id;
    if (id == null || !_id.hasMatch(id)) throw _badResponse;
    final json = await _send(
      'PUT',
      '/v1/organizer/drafts/$id',
      body: draftInput(draft),
      organizer: true,
    );
    return _saved = parseDraft(json) ?? (throw _badResponse);
  }

  @override
  Future<PublishedLink> publish(EventDraft draft) async {
    if (!identical(draft, _saved)) draft = await save(draft);
    final json = await _send(
      'POST',
      '/v1/organizer/drafts/${draft.id}/publish',
      body: {'eventId': publishEventId},
      organizer: true,
    );
    return parsePublish(json, linkBase) ?? (throw _badResponse);
  }

  /// Contract limits, checked before uploading; every file needs its bytes.
  static void checkUpload(List<UploadedFile> files) {
    if (files.isEmpty) {
      throw const EventsException(EventsErrorKind.invalid, 'no files');
    }
    if (files.any((f) => f.bytes == null)) {
      throw const EventsException(EventsErrorKind.failed, 'file not read');
    }
    final sizes = [for (final f in files) f.bytes!.length];
    if (files.length > maxFiles ||
        sizes.any((s) => s > maxFileBytes) ||
        sizes.fold(0, (a, b) => a + b) > maxTotalBytes) {
      throw const EventsException(EventsErrorKind.tooLarge, 'too many bytes');
    }
  }

  // ------------------------------------------------------------ mapping

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Oct 11–12, 2026", "Oct 11, 2026", "Sep 30 – Oct 2, 2026"; '' when
  /// [start] isn't a date.
  static String formatDates(String start, String end) {
    final a = DateTime.tryParse(start);
    if (a == null || !_date.hasMatch(start)) return '';
    final b = _date.hasMatch(end) ? DateTime.tryParse(end) ?? a : a;
    String md(DateTime d) => '${_months[d.month - 1]} ${d.day}';
    if (b == a || b.isBefore(a)) return '${md(a)}, ${a.year}';
    if (a.year != b.year) return '${md(a)}, ${a.year} – ${md(b)}, ${b.year}';
    if (a.month != b.month) return '${md(a)} – ${md(b)}, ${a.year}';
    return '${md(a)}–${b.day}, ${a.year}';
  }

  /// `PublicEvent` / `MyEvent` → [EventSummary], or null when invalid.
  static EventSummary? parseEvent(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (name is! String || name.trim().isEmpty) return null;
    return EventSummary(
      id: id,
      name: _cut(name.trim(), 120),
      dates: formatDates(_str(j['startDate']), _str(j['endDate'])),
      venue: _cut(_str(j['address']).trim(), 200),
      isPast: j['isPast'] == true,
    );
  }

  /// `{events: MyEvent[]}` → valid events in server order.
  static List<EventSummary> parseMyEvents(Object? json) {
    final list = json is Map ? json['events'] : null;
    if (list is! List) throw _badResponse;
    final seen = <String>{};
    return [
      for (final e in list.map(parseEvent))
        if (e != null && seen.add(e.id)) e,
    ];
  }

  /// `Speaker`, or null when invalid.
  static Speaker? parseSpeaker(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (name is! String || name.trim().isEmpty) return null;
    return Speaker(
      id: id,
      name: _cut(name.trim(), 80),
      title: _cut(_str(j['title']).trim(), 120),
    );
  }

  /// `Session`, or null when invalid. [isLive] is decided by the caller.
  static Session? parseSession(Object? j, {bool isLive = false}) {
    if (j is! Map) return null;
    final id = j['id'], title = j['title'];
    final start = j['start'], end = j['end'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (title is! String || title.trim().isEmpty) return null;
    if (start is! String || !_hhmm.hasMatch(start)) return null;
    if (end is! String || !_hhmm.hasMatch(end)) return null;
    final speakers = j['speakers'];
    final day = _str(j['day']);
    return Session(
      id: id,
      title: _cut(title.trim(), 160),
      stage: _cut(_str(j['stage']).trim(), 80),
      day: _date.hasMatch(day) ? day : '',
      start: start,
      end: end,
      track: _cut(_str(j['track']).trim(), 40),
      description: _cut(_str(j['description']).trim(), 600),
      isBreak: j['isBreak'] == true,
      isLive: isLive,
      speakers: [
        if (speakers is List)
          for (final s in speakers.map(parseSpeaker)) ?s,
      ].take(6).toList(),
    );
  }

  /// `Agenda` → sessions in server order. With [pinned], exactly those
  /// sessions are live; otherwise a session is live when [now] (event local
  /// time) falls within its day and times.
  static List<Session> parseAgenda(
    Object? json, {
    Set<String>? pinned,
    required DateTime now,
  }) {
    final list = json is Map ? json['sessions'] : null;
    if (list is! List) throw _badResponse;
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final hhmm =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final seen = <String>{};
    final sessions = <Session>[];
    for (final j in list) {
      final s = parseSession(j);
      if (s == null || !seen.add(s.id)) continue;
      final live = pinned != null
          ? pinned.contains(s.id)
          : !s.isBreak &&
                s.day == today &&
                s.start.compareTo(hhmm) <= 0 &&
                hhmm.compareTo(s.end) < 0;
      sessions.add(live ? parseSession(j, isLive: true)! : s);
    }
    return sessions;
  }

  /// `Draft` → [EventDraft], or null when invalid.
  static EventDraft? parseDraft(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (name is! String) return null;
    final start = _str(j['startDate']), end = _str(j['endDate']);
    final stages = j['stages'], speakers = j['speakers'];
    final sessions = j['sessions'], issues = j['issues'];
    final seen = <String>{};
    return EventDraft(
      id: id,
      name: _cut(name.trim(), 120),
      dates: formatDates(start, end),
      startDate: _date.hasMatch(start) ? start : null,
      endDate: _date.hasMatch(end) ? end : null,
      venue: _cut(_str(j['address']).trim(), 200),
      stages: [
        if (stages is List)
          for (final s in stages)
            if (s is String && s.trim().isNotEmpty) _cut(s.trim(), 80),
      ].take(30).toList(),
      speakers: [
        if (speakers is List)
          for (final s in speakers.map(parseSpeaker)) ?s,
      ].take(200).toList(),
      sessions: [
        if (sessions is List)
          for (final s in sessions.map(parseSession))
            if (s != null && seen.add(s.id)) s,
      ].take(300).toList(),
      issues: [
        if (issues is List)
          for (final i in issues.map(parseIssue)) ?i,
      ].take(100).toList(),
    );
  }

  /// `Issue`, or null when it has no message.
  static DraftIssue? parseIssue(Object? j) {
    if (j is! Map) return null;
    final message = _str(j['message']).trim();
    if (message.isEmpty) return null;
    final sessionId = j['sessionId'];
    return DraftIssue(
      sessionId: sessionId is String && _id.hasMatch(sessionId)
          ? sessionId
          : null,
      field: _cut(_str(j['field']).trim(), 100),
      message: _cut(message, 200),
    );
  }

  /// `DraftInput`: the reviewed draft, nothing else. Sessions without a day
  /// get the event's start date.
  static Map<String, Object?> draftInput(EventDraft d) {
    final start = d.startDate ?? '';
    Map<String, Object?> speaker(Speaker s) => {
      'id': s.id,
      'name': _cut(s.name, 80),
      'title': _cut(s.title, 120),
    };
    return {
      'name': _cut(d.name.trim(), 120),
      'startDate': start,
      'endDate': d.endDate ?? start,
      'address': _cut(d.venue.trim(), 200),
      'stages': [for (final s in d.stages.take(30)) _cut(s, 80)],
      'speakers': [for (final s in d.speakers.take(200)) speaker(s)],
      'sessions': [
        for (final s in d.sessions.take(300))
          {
            'id': s.id,
            'title': _cut(s.title.trim(), 160),
            'stage': _cut(s.stage.trim(), 80),
            'day': s.day.isEmpty ? start : s.day,
            'start': s.start,
            'end': s.end,
            'track': _cut(s.track, 40),
            'description': _cut(s.description, 600),
            'isBreak': s.isBreak,
            'speakers': [for (final p in s.speakers.take(6)) speaker(p)],
          },
      ],
    };
  }

  /// `PublishResult` → the join link on [linkBase], or null when invalid.
  static PublishedLink? parsePublish(Object? j, String linkBase) {
    if (j is! Map) return null;
    final id = j['eventId'];
    if (id is! String || !_id.hasMatch(id)) return null;
    final warnings = j['warnings'];
    return PublishedLink(
      eventId: id,
      url: '$linkBase/e/$id',
      warnings: [
        if (warnings is List)
          for (final w in warnings)
            if (w is String && w.trim().isNotEmpty) _cut(w.trim(), 200),
      ].take(20).toList(),
    );
  }

  // ------------------------------------------------------------ HTTP

  static const _badResponse = EventsException(
    EventsErrorKind.failed,
    'unexpected response',
  );

  static String _str(Object? v) => v is String ? v : '';

  static String _cut(String s, int max) =>
      s.length > max ? s.substring(0, max) : s;

  static String _event(String eventId) =>
      '/v1/events/${Uri.encodeComponent(eventId)}';

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    bool organizer = false,
  }) {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _sendRequest(request, organizer: organizer);
  }

  Future<Object?> _sendRequest(
    http.BaseRequest request, {
    bool organizer = false,
    Duration? timeout,
  }) async {
    final wait = timeout ?? this.timeout;
    try {
      final token = await (organizer ? organizerTokenProvider : tokenProvider)()
          .timeout(this.timeout);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    } on EventsException {
      rethrow;
    } catch (e) {
      throw EventsException(
        organizer ? EventsErrorKind.organizerRequired : EventsErrorKind.offline,
        'sign-in failed: $e',
      );
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(wait),
      ).timeout(wait);
    } on TimeoutException {
      throw EventsException(
        timeout != null ? EventsErrorKind.aiBusy : EventsErrorKind.offline,
        'request timed out',
      );
    } on http.ClientException catch (e) {
      throw EventsException(EventsErrorKind.offline, e.message);
    }

    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;
    throw errorFor(status, json, response.headers['retry-after']);
  }

  /// The contract's `{code, message, details}` error → [EventsException].
  /// For `unsupported_file` the message is the file name.
  static EventsException errorFor(
    int status,
    Object? json, [
    String? retryAfter,
  ]) {
    final code = json is Map && json['code'] is String
        ? json['code'] as String
        : '';
    final message = json is Map && json['message'] is String
        ? json['message'] as String
        : 'HTTP $status';
    final details = json is Map ? json['details'] : null;
    final first = details is List && details.isNotEmpty && details.first is Map
        ? details.first as Map
        : const {};
    if (status == 429 || code == 'rate_limited') {
      final retry = int.tryParse(retryAfter ?? '');
      return EventsException(
        EventsErrorKind.rateLimited,
        message,
        retry == null ? null : Duration(seconds: retry),
      );
    }
    final kind = switch ((status, code)) {
      (_, 'organizer_account_required') => EventsErrorKind.organizerRequired,
      (_, 'unsupported_file') || (415, _) => EventsErrorKind.unsupportedFile,
      (_, 'too_large') || (413, _) => EventsErrorKind.tooLarge,
      (_, 'nothing_extracted') => EventsErrorKind.nothingExtracted,
      (_, 'ai_unavailable') => EventsErrorKind.aiBusy,
      (401, _) => EventsErrorKind.offline,
      (403, _) => EventsErrorKind.forbidden,
      (404, _) => EventsErrorKind.notFound,
      (400 || 422, _) => EventsErrorKind.invalid,
      (502 || 503 || 504, _) => EventsErrorKind.aiBusy,
      _ => EventsErrorKind.failed,
    };
    if (kind == EventsErrorKind.unsupportedFile && first['field'] is String) {
      return EventsException(kind, _cut(first['field'] as String, 120));
    }
    final detail = first['message'] is String
        ? ': ${first['field'] ?? ''} ${first['message']}'
        : '';
    return EventsException(kind, '$code $message$detail'.trim());
  }
}

/// Uses [primary] when its service answers `/healthz` on first use,
/// otherwise [fallback] (demo data) for the rest of the app's life. The demo
/// events ([demoEventIds]) also fall back when the service doesn't know them
/// (not seeded), and an agenda that isn't published yet is empty.
class FallbackEventRepository implements EventRepository {
  FallbackEventRepository({
    required this.primary,
    required this.fallback,
    this.demoEventIds = const {},
  });

  final EventsApiRepository primary;
  final EventRepository fallback;
  final Set<String> demoEventIds;

  late final Future<EventRepository> _target = primary.reachable.then(
    (ok) => ok ? primary : fallback,
  );

  Future<T> _call<T>(
    String eventId,
    Future<T> Function(EventRepository r) call,
  ) async {
    final target = await _target;
    try {
      return await call(target);
    } on EventsException catch (e) {
      if (identical(target, fallback) ||
          e.kind != EventsErrorKind.notFound ||
          !demoEventIds.contains(eventId)) {
        rethrow;
      }
      return call(fallback);
    }
  }

  @override
  List<String> get interestOptions => fallback.interestOptions;

  @override
  Future<EventSummary> getEvent(String eventId) =>
      _call(eventId, (r) => r.getEvent(eventId));

  @override
  Future<void> join(String eventId) => _call(eventId, (r) => r.join(eventId));

  @override
  Future<void> leave(String eventId) async => (await _target).leave(eventId);

  @override
  Future<bool> get isLive async => identical(await _target, primary);

  @override
  Future<List<EventSummary>> myEvents() async => (await _target).myEvents();

  @override
  Future<List<Session>> agenda(String eventId) async {
    try {
      return await _call(eventId, (r) => r.agenda(eventId));
    } on EventsException catch (e) {
      if (e.kind == EventsErrorKind.notFound) return const [];
      rethrow;
    }
  }
}

/// Organizer side of [FallbackEventRepository]: the Events API when it
/// answers `/healthz` on first use, demo data otherwise.
class FallbackOrganizerRepository implements OrganizerRepository {
  FallbackOrganizerRepository({required this.primary, required this.fallback});

  final EventsApiRepository primary;
  final OrganizerRepository fallback;

  late final Future<OrganizerRepository> _target = primary.reachable.then(
    (ok) => ok ? primary : fallback,
  );

  @override
  Future<EventDraft> extract(List<UploadedFile> files) async =>
      (await _target).extract(files);

  @override
  Future<EventDraft> save(EventDraft draft) async =>
      (await _target).save(draft);

  @override
  Future<PublishedLink> publish(EventDraft draft) async =>
      (await _target).publish(draft);
}
