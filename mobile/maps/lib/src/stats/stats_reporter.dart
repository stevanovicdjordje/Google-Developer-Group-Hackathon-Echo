import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_providers.dart';
import '../model/stats_models.dart';
import '../viewer/search.dart';

/// Sends one batch (at most [StatsReporter.maxBatch] events).
typedef StatsSender = Future<void> Function(List<StatsEvent> events);

/// Collects what an attendee does on the map and reports it in batches:
/// every [interval], when [flushAt] events are queued, and on [dispose].
/// Stats are best effort: a failed batch is dropped, never retried, and
/// never shown to the attendee. No positions are ever reported.
class StatsReporter {
  StatsReporter(
    this._send, {
    this.interval = const Duration(seconds: 10),
    this.flushAt = 20,
  });

  static const maxBatch = 50;

  final StatsSender _send;
  final Duration interval;
  final int flushAt;

  final _queue = <StatsEvent>[];
  final _scanned = <String>{};
  String? _lastQuery;
  Timer? _timer;
  bool _disposed = false;

  /// Queued, not yet sent (for tests).
  List<StatsEvent> get pending => List.unmodifiable(_queue);

  /// A finished search. The same query twice in a row counts once, and
  /// queries under 2 characters are not counted.
  void search(String query, int resultCount) {
    final q = normalizeSearch(query);
    if (q.length < 2 || q == _lastQuery) return;
    _lastQuery = q;
    _add(StatsEvent.search(query.trim(), resultCount));
  }

  void featureView(String featureId) => _add(StatsEvent.featureView(featureId));

  void route(String targetId) => _add(StatsEvent.route(targetId));

  /// A QR marker link was opened; counted once per marker while the map is open.
  void qrScan(String markerId) {
    if (_scanned.add(markerId)) _add(StatsEvent.qrScan(markerId));
  }

  void _add(StatsEvent e) {
    if (_disposed) return;
    _queue.add(e);
    if (_queue.length >= flushAt) {
      flush();
    } else {
      _timer ??= Timer(interval, flush);
    }
  }

  /// Sends everything queued now.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    while (_queue.isNotEmpty) {
      final n = _queue.length < maxBatch ? _queue.length : maxBatch;
      final batch = _queue.sublist(0, n);
      _queue.removeRange(0, n);
      try {
        await _send(batch);
      } on Object {
        // Offline, rate limited or signed out: these counts are dropped.
      }
    }
  }

  /// Sends what is left and stops counting.
  void dispose() {
    if (_disposed) return;
    unawaited(flush());
    _disposed = true;
  }
}

/// The reporter of one event's map, alive while a viewer of it is open.
final mapsStatsReporterProvider = Provider.autoDispose
    .family<StatsReporter, String>((ref, eventId) {
      // Captured now: the last flush runs after this provider is disposed.
      // The viewer only exists once the attendee is signed in.
      final api = ref.watch(mapsApiProvider);
      final reporter = StatsReporter(
        (events) => api.recordStats(eventId, events),
      );
      ref.onDispose(reporter.dispose);
      return reporter;
    });
