/// Map usage stats (`recordStats`, `getStats` in `contracts/maps/openapi.yaml`).
/// Attendee events never carry a position or a user ID.
library;

enum StatsEventType {
  search('search'),
  featureView('feature_view'),
  route('route'),
  qrScan('qr_scan');

  const StatsEventType(this.wire);
  final String wire;
}

/// One attendee interaction to report (`StatsEvent`).
class StatsEvent {
  const StatsEvent.search(String this.query, int this.resultCount)
    : type = StatsEventType.search,
      featureId = null;
  const StatsEvent.featureView(String this.featureId)
    : type = StatsEventType.featureView,
      query = null,
      resultCount = null;
  const StatsEvent.route(String this.featureId)
    : type = StatsEventType.route,
      query = null,
      resultCount = null;
  const StatsEvent.qrScan(String this.featureId)
    : type = StatsEventType.qrScan,
      query = null,
      resultCount = null;

  final StatsEventType type;
  final String? query;
  final int? resultCount;
  final String? featureId;

  Map<String, dynamic> toJson() => {
    'type': type.wire,
    'query': ?query,
    'resultCount': ?resultCount,
    'featureId': ?featureId,
  };

  @override
  String toString() => 'StatsEvent(${toJson()})';
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `StatsCounts`; also one day of `EventStats.days`.
class StatsCounts {
  const StatsCounts({
    this.date = '',
    this.searches = 0,
    this.searchesNoResults = 0,
    this.featureViews = 0,
    this.routes = 0,
    this.qrScans = 0,
  });

  factory StatsCounts.fromJson(Map<String, dynamic> j) => StatsCounts(
    date: j['date'] as String? ?? '',
    searches: _int(j['searches']),
    searchesNoResults: _int(j['searchesNoResults']),
    featureViews: _int(j['featureViews']),
    routes: _int(j['routes']),
    qrScans: _int(j['qrScans']),
  );

  /// YYYY-MM-DD for a day; empty for totals.
  final String date;
  final int searches;
  final int searchesNoResults;
  final int featureViews;
  final int routes;
  final int qrScans;

  /// Everything attendees did that day.
  int get interactions => searches + featureViews + routes + qrScans;
}

class TermCount {
  const TermCount(this.query, this.count);
  final String query;
  final int count;
}

class FeatureCount {
  const FeatureCount({
    required this.featureId,
    required this.name,
    required this.type,
    required this.count,
  });

  final String featureId;

  /// Empty if the feature is no longer on the published map.
  final String name;
  final String type;
  final int count;
}

/// `EventStats`: what attendees did on the map over a date range.
class EventStats {
  const EventStats({
    required this.from,
    required this.to,
    required this.totals,
    required this.days,
    this.topSearches = const [],
    this.topNoResults = const [],
    this.topFeatures = const [],
    this.topRouteTargets = const [],
    this.qrScans = const [],
  });

  factory EventStats.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) => [
      for (final e in (j[k] as List?) ?? const [])
        Map<String, dynamic>.from(e as Map),
    ];
    List<TermCount> terms(String k) => [
      for (final e in list(k))
        TermCount(e['query'] as String? ?? '', _int(e['count'])),
    ];
    List<FeatureCount> features(String k) => [
      for (final e in list(k))
        FeatureCount(
          featureId: e['featureId'] as String? ?? '',
          name: e['name'] as String? ?? '',
          type: e['type'] as String? ?? '',
          count: _int(e['count']),
        ),
    ];
    return EventStats(
      from: j['from'] as String,
      to: j['to'] as String,
      totals: StatsCounts.fromJson(
        Map<String, dynamic>.from(j['totals'] as Map),
      ),
      days: [for (final d in list('days')) StatsCounts.fromJson(d)],
      topSearches: terms('topSearches'),
      topNoResults: terms('topNoResults'),
      topFeatures: features('topFeatures'),
      topRouteTargets: features('topRouteTargets'),
      qrScans: features('qrScans'),
    );
  }

  final String from;
  final String to;
  final StatsCounts totals;
  final List<StatsCounts> days;
  final List<TermCount> topSearches;
  final List<TermCount> topNoResults;
  final List<FeatureCount> topFeatures;
  final List<FeatureCount> topRouteTargets;
  final List<FeatureCount> qrScans;

  bool get isEmpty => totals.interactions == 0;
}
