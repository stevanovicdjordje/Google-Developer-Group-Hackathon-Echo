import 'dart:convert';
import 'dart:io';

import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/location/georef.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same vectors `backend/maps/internal/geo/vectors_test.go` checks.
final vectors = jsonDecode(
  File('../../contracts/maps/testdata/georef.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  final tol = vectors['tolerance'] as Map<String, dynamic>;
  final tolPx = (tol['pixels'] as num).toDouble();
  final tolDeg = (tol['degrees'] as num).toDouble();
  final cases = (vectors['cases'] as List).cast<Map<String, dynamic>>();

  test('the file has the expected cases', () {
    expect(cases.length, greaterThanOrEqualTo(6));
    expect(cases.where((c) => c['degenerate'] == true), isNotEmpty);
  });

  for (final c in cases) {
    test(c['name'], () {
      final cps = [
        for (final p in c['controlPoints'] as List)
          ControlPoint.fromJson(Map<String, dynamic>.from(p as Map)),
      ];
      if (c['degenerate'] == true) {
        expect(() => Georef.fit(cps), throwsA(isA<DegenerateGeoref>()));
        return;
      }
      final g = Georef.fit(cps);
      final mpp = (c['metersPerPixel'] as num).toDouble();
      expect(g.metersPerPixel, closeTo(mpp, mpp * 1e-9));

      final want = GeorefQuality.fromJson(
        Map<String, dynamic>.from(c['quality'] as Map),
      );
      final q = g.quality(c['width'] as int, c['height'] as int);
      double tolOf(double v) => 1e-6 * (v.abs() > 1 ? v.abs() : 1);
      expect(
        q.estimatedErrorMeters,
        closeTo(want.estimatedErrorMeters, tolOf(want.estimatedErrorMeters)),
      );
      expect(q.skewDegrees, closeTo(want.skewDegrees, tolOf(want.skewDegrees)));
      expect(
        q.scaleMismatchPercent,
        closeTo(want.scaleMismatchPercent, tolOf(want.scaleMismatchPercent)),
      );

      for (final p in (c['probes'] as List).cast<Map<String, dynamic>>()) {
        final px = PlanPoint.fromJson(Map<String, dynamic>.from(p['px']));
        final ll = LatLngDeg.fromJson(Map<String, dynamic>.from(p['latLng']));
        final got = g.toLatLng(px);
        expect(got.lat, closeTo(ll.lat, tolDeg), reason: 'lat of $px');
        expect(got.lng, closeTo(ll.lng, tolDeg), reason: 'lng of $px');
        final back = g.toPixel(ll);
        expect(back.x, closeTo(px.x, tolPx), reason: 'x of $px');
        expect(back.y, closeTo(px.y, tolPx), reason: 'y of $px');
      }
    });
  }

  test('a floor without georef has no transform', () {
    const floor = Floor(
      id: 'f',
      name: 'P',
      order: 0,
      imagePath: 'p.png',
      width: 100,
      height: 100,
    );
    expect(Georef.of(floor), isNull);
  });
}
