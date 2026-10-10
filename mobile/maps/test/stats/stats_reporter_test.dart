import 'package:eho_maps/src/model/stats_models.dart';
import 'package:eho_maps/src/stats/stats_reporter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('batches every interval, at the threshold and on dispose', () {
    fakeAsync((async) {
      final sent = <List<StatsEvent>>[];
      final r = StatsReporter((b) async => sent.add(b), flushAt: 3);

      r.featureView('s1');
      r.route('s1');
      async.elapse(const Duration(seconds: 9));
      expect(sent, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(sent.single.map((e) => e.toJson()), [
        {'type': 'feature_view', 'featureId': 's1'},
        {'type': 'route', 'featureId': 's1'},
      ]);

      r.featureView('a');
      r.featureView('b');
      r.featureView('c'); // threshold
      async.flushMicrotasks();
      expect(sent, hasLength(2));
      expect(sent.last, hasLength(3));

      r.qrScan('qr');
      r.dispose();
      async.flushMicrotasks();
      expect(sent.last.single.toJson(), {'type': 'qr_scan', 'featureId': 'qr'});
      r.featureView('late'); // after dispose: ignored
      async.elapse(const Duration(minutes: 1));
      expect(sent, hasLength(3));
    });
  });

  test('dedups searches and QR scans, skips short queries', () {
    final r = StatsReporter((_) async {});
    r.search('Kafa', 0);
    r.search(' kafa ', 0); // same normalized query
    r.search('k', 0);
    r.search('Čačak', 1);
    r.search('kafa', 0); // not in a row any more
    r.qrScan('qr');
    r.qrScan('qr');
    expect(r.pending.map((e) => e.toJson()), [
      {'type': 'search', 'query': 'Kafa', 'resultCount': 0},
      {'type': 'search', 'query': 'Čačak', 'resultCount': 1},
      {'type': 'search', 'query': 'kafa', 'resultCount': 0},
      {'type': 'qr_scan', 'featureId': 'qr'},
    ]);
    r.dispose();
  });

  test('splits into batches of 50 and drops failed ones', () {
    fakeAsync((async) {
      final sizes = <int>[];
      var calls = 0;
      final r = StatsReporter((b) async {
        calls++;
        if (calls == 1) throw Exception('rate_limited');
        sizes.add(b.length);
      }, flushAt: 1000);
      for (var i = 0; i < 120; i++) {
        r.featureView('s$i');
      }
      r.flush();
      async.flushMicrotasks();
      expect(calls, 3);
      expect(sizes, [50, 20]); // the first 50 were dropped
      expect(r.pending, isEmpty);
    });
  });
}
