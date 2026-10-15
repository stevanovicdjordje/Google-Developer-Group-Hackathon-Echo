import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../location/georef.dart';
import '../model/map_models.dart';
import '../model/route_models.dart';
import '../model/stats_models.dart';

/// Error in the API's uniform `{code, message, details}` format, or a
/// client-side failure (`network`, `timeout`, `bad_response`).
class MapsApiException implements Exception {
  const MapsApiException(
    this.statusCode,
    this.code,
    this.message, [
    this.details,
  ]);

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isNetwork => code == 'network' || code == 'timeout';

  /// `validation_failed` details as "field: message" lines.
  List<String> get fieldErrors => [
    if (details is List)
      for (final d in details as List)
        if (d is Map) '${d['field']}: ${d['message']}',
  ];

  @override
  String toString() => 'MapsApiException($statusCode, $code): $message';
}

/// An event as the organizer sees it (`Event` schema).
class OrganizerEvent {
  const OrganizerEvent({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.address,
    required this.publishedVersion,
  });

  factory OrganizerEvent.fromJson(Map<String, dynamic> j) => OrganizerEvent(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    startDate: j['startDate'] as String? ?? '',
    endDate: j['endDate'] as String? ?? '',
    address: j['address'] as String? ?? '',
    publishedVersion: (j['publishedVersion'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String address;

  /// 0 = never published.
  final int publishedVersion;
}

/// A publish check result (`Issue` schema).
class PublishIssue {
  const PublishIssue(this.code, this.message, {this.floorId, this.featureId});

  factory PublishIssue.fromJson(Map<String, dynamic> j) => PublishIssue(
    j['code'] as String? ?? '',
    j['message'] as String? ?? '',
    floorId: j['floorId'] as String?,
    featureId: j['featureId'] as String?,
  );

  final String code;
  final String message;
  final String? floorId;
  final String? featureId;
}

class PublishResult {
  const PublishResult({
    required this.ok,
    this.version = 0,
    this.errors = const [],
    this.warnings = const [],
  });

  final bool ok;
  final int version;
  final List<PublishIssue> errors;
  final List<PublishIssue> warnings;
}

/// Returns the current Firebase ID token, or null when signed out.
typedef MapsTokenProvider = Future<String?> Function();

/// HTTP client for the organizer operations of `contracts/maps/openapi.yaml`.
class MapsApi {
  MapsApi({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final MapsTokenProvider tokenProvider;
  final Duration timeout;
  final http.Client _http;

  Future<List<OrganizerEvent>> listMyEvents() async {
    final j = await _send('GET', '/v1/events') as Map<String, dynamic>;
    return [
      for (final e in j['events'] as List)
        OrganizerEvent.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<OrganizerEvent> getEvent(String eventId) async =>
      OrganizerEvent.fromJson(await _obj('GET', '/v1/events/$eventId'));

  Future<OrganizerEvent> createEvent({
    required String name,
    required String startDate,
    required String endDate,
    String address = '',
  }) async => OrganizerEvent.fromJson(
    await _obj('POST', '/v1/events', {
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      if (address.isNotEmpty) 'address': address,
    }),
  );

  Future<VenueMap> getDraft(String eventId) async =>
      VenueMap.fromJson(await _obj('GET', '/v1/events/$eventId/draft'));

  /// Publishes the draft. A blocked publish (422 `publish_blocked`) is
  /// returned as a result with `ok = false`, not thrown.
  Future<PublishResult> publish(String eventId) async {
    try {
      final j = await _obj('POST', '/v1/events/$eventId/publish');
      return PublishResult(
        ok: true,
        version: (j['publishedVersion'] as num).toInt(),
        warnings: _issues(j['warnings']),
      );
    } on MapsApiException catch (e) {
      if (e.code != 'publish_blocked' || e.details is! Map) rethrow;
      final d = e.details as Map;
      return PublishResult(
        ok: false,
        errors: _issues(d['errors']),
        warnings: _issues(d['warnings']),
      );
    }
  }

  Future<Floor> createFloor(
    String eventId, {
    required String name,
    required String imagePath,
    int order = 0,
  }) async => Floor.fromJson(
    await _obj('POST', '/v1/events/$eventId/floors', {
      'name': name,
      'order': order,
      'imagePath': imagePath,
    }),
  );

  Future<Floor> updateFloor(
    String eventId,
    String floorId,
    Map<String, dynamic> patch,
  ) async => Floor.fromJson(
    await _obj('PATCH', '/v1/events/$eventId/floors/$floorId', patch),
  );

  /// Georeferences the floor with exactly 3 control points.
  Future<(Floor, GeorefQuality)> putGeoref(
    String eventId,
    String floorId,
    List<ControlPoint> controlPoints,
  ) async {
    final j = await _obj('PUT', '/v1/events/$eventId/floors/$floorId/georef', {
      'controlPoints': [for (final c in controlPoints) c.toJson()],
    });
    return (
      Floor.fromJson(Map<String, dynamic>.from(j['floor'] as Map)),
      GeorefQuality.fromJson(Map<String, dynamic>.from(j['quality'] as Map)),
    );
  }

  Future<void> deleteGeoref(String eventId, String floorId) =>
      _send('DELETE', '/v1/events/$eventId/floors/$floorId/georef');

  Future<void> deleteFloor(String eventId, String floorId) =>
      _send('DELETE', '/v1/events/$eventId/floors/$floorId');

  Future<FloorGraph> putGraph(String eventId, FloorGraph graph) async =>
      FloorGraph.fromJson(
        await _obj('PUT', '/v1/events/$eventId/floors/${graph.floorId}/graph', {
          'nodes': [for (final n in graph.nodes) n.toJson()],
          'edges': [for (final e in graph.edges) e.toJson()],
        }),
      );

  /// [fields] follows `FeatureInput` (see `featureFields`).
  Future<Feature> createFeature(
    String eventId,
    Map<String, dynamic> fields,
  ) async => Feature.fromJson(
    await _obj('POST', '/v1/events/$eventId/features', fields),
  );

  Future<Feature> updateFeature(
    String eventId,
    String featureId,
    Map<String, dynamic> patch,
  ) async => Feature.fromJson(
    await _obj('PATCH', '/v1/events/$eventId/features/$featureId', patch),
  );

  Future<void> deleteFeature(String eventId, String featureId) =>
      _send('DELETE', '/v1/events/$eventId/features/$featureId');

  /// Fastest walking route on the published map. `no_route` (422) means the
  /// two places aren't connected.
  Future<MapRoute> getRoute(
    String eventId, {
    required RouteEndpoint from,
    required RouteEndpoint to,
    bool accessible = false,
  }) async {
    final j = await _obj('POST', '/v1/events/$eventId/route', {
      'from': from.toJson(),
      'to': to.toJson(),
      'accessible': accessible,
    });
    try {
      return MapRoute.fromJson(j);
    } on Object {
      throw const MapsApiException(0, 'bad_response', 'invalid route');
    }
  }

  /// Reports attendee events (at most 50). `rate_limited` (429) means the
  /// batch was not counted.
  Future<void> recordStats(String eventId, List<StatsEvent> events) =>
      _send('POST', '/v1/events/$eventId/stats/events', {
        'events': [for (final e in events) e.toJson()],
      });

  /// Owner-only usage stats; [from] and [to] are YYYY-MM-DD (server default:
  /// the last 30 days).
  Future<EventStats> getStats(
    String eventId, {
    String? from,
    String? to,
  }) async {
    final query = [
      if (from != null) 'from=$from',
      if (to != null) 'to=$to',
    ].join('&');
    final j = await _obj(
      'GET',
      '/v1/events/$eventId/stats${query.isEmpty ? '' : '?$query'}',
    );
    try {
      return EventStats.fromJson(j);
    } on Object {
      throw const MapsApiException(0, 'bad_response', 'invalid stats');
    }
  }

  static List<PublishIssue> _issues(Object? v) => [
    for (final i in (v as List?) ?? const [])
      PublishIssue.fromJson(Map<String, dynamic>.from(i as Map)),
  ];

  Future<Map<String, dynamic>> _obj(
    String method,
    String path, [
    Object? body,
  ]) async {
    final v = await _send(method, path, body);
    if (v is! Map) {
      throw MapsApiException(0, 'bad_response', 'expected a JSON object');
    }
    return Map<String, dynamic>.from(v);
  }

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    final token = await tokenProvider();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const MapsApiException(0, 'timeout', 'request timed out');
    } on http.ClientException catch (e) {
      throw MapsApiException(0, 'network', e.message);
    }

    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw MapsApiException(
          response.statusCode,
          'bad_response',
          'invalid JSON',
        );
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map) {
      throw MapsApiException(
        response.statusCode,
        decoded['code'] as String? ?? 'unknown',
        decoded['message'] as String? ?? 'request failed',
        decoded['details'],
      );
    }
    throw MapsApiException(response.statusCode, 'unknown', 'request failed');
  }
}
