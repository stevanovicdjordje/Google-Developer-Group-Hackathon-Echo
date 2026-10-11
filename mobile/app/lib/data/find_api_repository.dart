/// Find backed by the Find service (`contracts/find` 0.2.0, `backend/find`).
///
/// Call order from the contract: the profile is saved (`putMyProfile`), the
/// attendee is marked present at the event (`joinFind`), then
/// recommendations, search, person, contacts and the meeting spot work. This
/// class does the first two on demand, once per app run (and again when the
/// server says they're missing), so screens just call the operation they need.
///
/// Privacy (`docs/DATA_PRIVACY.md`): the profile is sent only after
/// onboarding, with the consent switches exactly as the attendee set them,
/// and is never logged. Server and model output is untrusted display text:
/// shapes are checked, lengths capped and IDs restricted (`AGENTS.md` rule 12).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api/api_client.dart' show TokenProvider;
import 'models.dart';
import 'repositories.dart';

class FindApiRepository implements FindRepository {
  FindApiRepository({
    required this.baseUrl,
    required this.tokenProvider,
    required this.profile,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.aiTimeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenProvider tokenProvider;

  /// The attendee's current profile, saved first when the server needs it.
  final Profile Function() profile;
  final Duration timeout;

  /// Recommendations and search are ranked by the model.
  final Duration aiTimeout;

  final http.Client _http;

  /// `Person.id` goes into app routes, so only plain IDs are accepted.
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

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

  // ------------------------------------------------------------ profile

  /// Completes when the server has the latest saved profile.
  Future<void>? _profileSaved;
  Profile? _pendingProfile;
  Future<void>? _savingProfile;

  /// Edits arriving while a save is in flight are coalesced: only the latest
  /// one is sent after it.
  @override
  Future<void> saveProfile(Profile profile) {
    if (!profile.onboarded) return Future.value();
    _pendingProfile = profile;
    return _profileSaved = _savingProfile ??= _drainProfile();
  }

  Future<void> _drainProfile() async {
    try {
      for (var p = _pendingProfile; p != null; p = _pendingProfile) {
        _pendingProfile = null;
        await _send('PUT', '/v1/me/profile', body: profileInput(p));
      }
    } finally {
      _savingProfile = null;
    }
  }

  /// `ProfileInput`: the profile and its consent switches, nothing else.
  static Map<String, Object?> profileInput(Profile p) => {
    'name': _cut(p.name.trim(), 60),
    'headline': _cut(p.headline.trim(), 100),
    'interests': [
      for (final i in p.interests.map((i) => i.trim()))
        if (i.isNotEmpty) _cut(i, 30),
    ].take(10).toList(),
    'lookingFor': _cut(p.lookingFor.trim(), 200),
    'visibleInFind': p.visibleInFind,
    'allowContact': p.allowContact,
    'shareMeetingSpot': p.shareMeetingSpot,
  };

  /// Waits for the last save; if it failed (or none ran yet), saves the
  /// current profile now.
  Future<void> _ensureProfile() async {
    final last = _profileSaved;
    if (last != null) {
      try {
        return await last;
      } catch (_) {
        if (identical(_profileSaved, last)) _profileSaved = null;
      }
    }
    final saved = _profileSaved ?? saveProfile(profile());
    try {
      await saved;
    } catch (_) {
      if (identical(_profileSaved, saved)) _profileSaved = null;
      rethrow;
    }
  }

  @override
  Future<void> deleteProfile() async {
    await _send('DELETE', '/v1/me/profile');
    _profileSaved = null;
    _present.clear();
  }

  // ------------------------------------------------------------ presence

  final _present = <String, Future<void>>{};

  /// `joinFind` once per event, after the profile is saved.
  Future<void> _ensurePresent(String eventId) async {
    await _ensureProfile();
    final join = _present[eventId] ??= _send(
      'PUT',
      '${_event(eventId)}/people/me',
    );
    try {
      await join;
    } catch (_) {
      if (identical(_present[eventId], join)) _present.remove(eventId);
      rethrow;
    }
  }

  /// Runs [call] while present at the event; joins again once if the server
  /// forgot (`not_present`) or the profile is gone (`profile_required`).
  Future<T> _inEvent<T>(String eventId, Future<T> Function() call) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await _ensurePresent(eventId);
        return await call();
      } on _Stale catch (e) {
        _present.remove(eventId);
        _profileSaved = null;
        if (attempt > 0) throw e.error;
      }
    }
  }

  // ------------------------------------------------------------ people

  @override
  Future<List<PersonMatch>> recommendations(String eventId, Profile me) =>
      _inEvent(eventId, () async {
        final json = await _send(
          'GET',
          '${_event(eventId)}/people/recommendations',
          timeout: aiTimeout,
        );
        return parseMatches(json);
      });

  @override
  Future<List<PersonMatch>> search(String eventId, String prompt) {
    final p = prompt.trim();
    if (p.length < 2) return Future.value(const []);
    return _inEvent(eventId, () async {
      final json = await _send(
        'POST',
        '${_event(eventId)}/people/search',
        body: {'prompt': _cut(p, 300)},
        timeout: aiTimeout,
      );
      return parseMatches(json);
    });
  }

  @override
  Future<PersonDetail?> person(String eventId, String personId) async {
    if (!_id.hasMatch(personId)) return null;
    try {
      return await _inEvent(eventId, () async {
        final json = await _send(
          'GET',
          '${_event(eventId)}/people/${Uri.encodeComponent(personId)}',
        );
        final person = parsePerson(json) ?? (throw _badResponse);
        final m = json as Map;
        return PersonDetail(
          person: person,
          allowContact: m['allowContact'] == true,
          contactState: parseContactState(m['contactState']),
        );
      });
    } on FindException catch (e) {
      if (e.kind == FindErrorKind.notFound) return null;
      rethrow;
    }
  }

  // ------------------------------------------------------------ contacts

  /// One state: the server answers `requested`, or `accepted` at once for
  /// seeded demo attendees and when the person had already asked the caller.
  @override
  Stream<ContactState> requestContact(String eventId, String personId) async* {
    final json = await _inEvent(
      eventId,
      () => _send(
        'POST',
        '${_event(eventId)}/contacts',
        body: {'personId': personId},
      ),
    );
    yield _contactState(json);
  }

  /// The stored place (the map's spelling) and time, which fall back to what
  /// was sent when the answer lacks them.
  @override
  Future<({String place, String? time})> setMeetingSpot(
    String eventId,
    String personId,
    String place, {
    String? time,
  }) async {
    final json = await _inEvent(
      eventId,
      () => _send(
        'PUT',
        '${_event(eventId)}/contacts/${Uri.encodeComponent(personId)}'
            '/meeting-spot',
        body: meetingSpotRequest(place, time),
      ),
    );
    final stored = parseMeetingSpot(json);
    return (
      place: stored?.place ?? place,
      time: stored?.time ?? _meetingTime(time),
    );
  }

  /// Contacts newest first, each with the spot stored for it.
  @override
  Future<List<Contact>> listContacts(String eventId) =>
      _inEvent(eventId, () async {
        final json = await _send('GET', '${_event(eventId)}/contacts');
        return parseContacts(json);
      });

  // ------------------------------------------------------------ mapping

  /// `{contacts: Contact[]}` -> valid contacts in server order; entries
  /// without a valid person or state are skipped. A missing or invalid
  /// `meetingSpot` just means none.
  static List<Contact> parseContacts(Object? json) {
    final list = json is Map ? json['contacts'] : null;
    if (list is! List) throw _badResponse;
    final contacts = <Contact>[];
    for (final c in list) {
      if (c is! Map || c['state'] is! String) continue;
      final person = parsePerson(c['person']);
      if (person == null) continue;
      contacts.add(
        Contact(
          person: person,
          state: parseContactState(c['state']),
          meetingSpot: parseMeetingSpot(c),
        ),
      );
    }
    return contacts;
  }

  /// `MeetingSpotRequest`: the place, and the time only when it is a valid
  /// "HH:mm" (zero-padded; the key is omitted otherwise).
  static Map<String, Object?> meetingSpotRequest(String place, String? time) {
    final t = _meetingTime(time);
    return {'place': _cut(place.trim(), 80), 'time': ?t};
  }

  /// `Contact.meetingSpot` -> place and optional time, or null when the
  /// contact has no valid spot. A missing or malformed time is ignored.
  static ({String place, String? time})? parseMeetingSpot(Object? contact) {
    final spot = contact is Map ? contact['meetingSpot'] : null;
    final place = spot is Map ? spot['place'] : null;
    if (spot is! Map || place is! String || place.trim().isEmpty) return null;
    final time = spot['time'];
    return (
      place: _cut(place.trim(), 80),
      time: time is String && _hhmm.hasMatch(time) ? time : null,
    );
  }

  /// The contract's `time` pattern.
  static final _hhmm = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

  /// [time] as "HH:mm", zero-padding "9:05"; null when absent or invalid.
  static String? _meetingTime(String? time) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time?.trim() ?? '');
    if (m == null) return null;
    final t = '${m[1]!.padLeft(2, '0')}:${m[2]}';
    return _hhmm.hasMatch(t) ? t : null;
  }

  /// `Matches` → valid matches in server order; invalid entries are skipped.
  static List<PersonMatch> parseMatches(Object? json) {
    final list = json is Map ? json['matches'] : null;
    if (list is! List) throw _badResponse;
    final seen = <String>{};
    final matches = <PersonMatch>[];
    for (final m in list) {
      if (m is! Map) continue;
      final p = parsePerson(m['person']);
      if (p == null || !seen.add(p.id)) continue;
      final why = m['why'];
      matches.add(
        PersonMatch(person: p, why: why is String ? _cut(why.trim(), 240) : ''),
      );
    }
    return matches;
  }

  /// `Person`, or null when the shape or ID is invalid.
  static Person? parsePerson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    if (id is! String || !_id.hasMatch(id)) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final interests = j['interests'];
    return Person(
      id: id,
      name: _cut(name.trim(), 60),
      headline: j['headline'] is String
          ? _cut((j['headline'] as String).trim(), 100)
          : '',
      interests: [
        if (interests is List)
          for (final i in interests)
            if (i is String && i.trim().isNotEmpty) _cut(i.trim(), 30),
      ].take(10).toList(),
      lookingFor: j['lookingFor'] is String
          ? _cut((j['lookingFor'] as String).trim(), 200)
          : '',
    );
  }

  /// `ContactState` from the caller's side. `incoming` shows as `none`: the
  /// app has no accept button yet, and sending a request to someone who
  /// already asked accepts theirs (`requestContact`).
  static ContactState parseContactState(Object? s) => switch (s) {
    'requested' => ContactState.requested,
    'accepted' => ContactState.accepted,
    _ => ContactState.none,
  };

  static ContactState _contactState(Object? contact) {
    if (contact is! Map || contact['state'] is! String) throw _badResponse;
    return parseContactState(contact['state']);
  }

  // ------------------------------------------------------------ HTTP

  static const _badResponse = FindException(
    FindErrorKind.failed,
    'unexpected response',
  );

  static String _cut(String s, int max) =>
      s.length > max ? s.substring(0, max) : s;

  static String _event(String eventId) =>
      '/v1/events/${Uri.encodeComponent(eventId)}';

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    final wait = timeout ?? this.timeout;
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    try {
      final token = await tokenProvider().timeout(this.timeout);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    } catch (e) {
      throw FindException(FindErrorKind.offline, 'sign-in failed: $e');
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
      throw FindException(
        wait == aiTimeout ? FindErrorKind.aiBusy : FindErrorKind.offline,
        'request timed out',
      );
    } on http.ClientException catch (e) {
      throw FindException(FindErrorKind.offline, e.message);
    }

    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;

    final code = json is Map && json['code'] is String
        ? json['code'] as String
        : '';
    final message = json is Map && json['message'] is String
        ? json['message'] as String
        : 'HTTP $status';
    if (status == 429 || code == 'rate_limited') {
      final retry = int.tryParse(response.headers['retry-after'] ?? '');
      throw FindException(
        FindErrorKind.rateLimited,
        message,
        retry == null ? null : Duration(seconds: retry),
      );
    }
    if (code == 'not_present' || code == 'profile_required') {
      // Presence or profile is gone on the server: `_inEvent` redoes them.
      final kind = code == 'profile_required'
          ? FindErrorKind.profileRequired
          : FindErrorKind.failed;
      throw _Stale(FindException(kind, message));
    }
    throw FindException(switch (status) {
      401 => FindErrorKind.offline,
      403 => FindErrorKind.notAllowed,
      404 => FindErrorKind.notFound,
      502 || 503 || 504 => FindErrorKind.aiBusy,
      _ => FindErrorKind.failed,
    }, '$code $message'.trim());
  }
}

/// The server lost the caller's presence or profile; carries the error to
/// throw if joining again doesn't help.
class _Stale implements Exception {
  const _Stale(this.error);

  final FindException error;
}

/// Uses [primary] when its service answers `/healthz` on first use,
/// otherwise [fallback] (demo data) for the rest of the app's life.
class FallbackFindRepository implements FindRepository {
  FallbackFindRepository({required this.primary, required this.fallback});

  final FindApiRepository primary;
  final FindRepository fallback;

  late final Future<FindRepository> _target = primary.isReachable().then(
    (ok) => ok ? primary : fallback,
  );

  @override
  Future<void> saveProfile(Profile profile) async =>
      (await _target).saveProfile(profile);

  @override
  Future<void> deleteProfile() async => (await _target).deleteProfile();

  @override
  Future<List<PersonMatch>> recommendations(String eventId, Profile me) async =>
      (await _target).recommendations(eventId, me);

  @override
  Future<List<PersonMatch>> search(String eventId, String prompt) async =>
      (await _target).search(eventId, prompt);

  @override
  Future<PersonDetail?> person(String eventId, String personId) async =>
      (await _target).person(eventId, personId);

  @override
  Stream<ContactState> requestContact(String eventId, String personId) =>
      Stream.fromFuture(_target)
          .asyncExpand((r) => r.requestContact(eventId, personId));

  @override
  Future<({String place, String? time})> setMeetingSpot(
    String eventId,
    String personId,
    String place, {
    String? time,
  }) async =>
      (await _target).setMeetingSpot(eventId, personId, place, time: time);

  @override
  Future<List<Contact>> listContacts(String eventId) async =>
      (await _target).listContacts(eventId);
}
