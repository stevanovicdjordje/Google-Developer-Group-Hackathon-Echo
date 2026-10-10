import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/viewer/hit_test.dart';
import 'package:eho_maps/src/viewer/plan_projection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('normalizeSearch', () {
    test('folds case and Serbian diacritics', () {
      expect(normalizeSearch('Čačak'), 'cacak');
      expect(normalizeSearch('ŠTAND  žuti'), 'stand zuti');
      expect(normalizeSearch('Đorđe'), 'djordje');
    });
  });

  group('FeatureSearch', () {
    final search = FeatureSearch(
      demoMap.features,
      labelOf: (f) => f.type == FeatureType.stand ? 'štand' : '',
    );

    test('is tolerant to case and diacritics', () {
      expect(search.search('cacak').map((f) => f.id), ['s1']);
      expect(search.search('CAČAK').map((f) => f.id), ['s1']);
    });

    test('matches company, category and type words', () {
      expect(search.search('primer ai').map((f) => f.id), ['s2']);
      expect(search.search('istrazivanje').map((f) => f.id), ['s3']);
      expect(search.search('stand').length, 3);
    });

    test('never returns QR markers and filters by kind and category', () {
      expect(
        search.search('').any((f) => f.type == FeatureType.marker),
        isFalse,
      );
      expect(search.search('', filter: SearchFilter.rooms).map((f) => f.id), [
        'hall',
      ]);
      expect(search.search('', filter: SearchFilter.pois).map((f) => f.id), [
        'wc',
      ]);
      expect(search.search('', category: 'AI').map((f) => f.id), ['s2']);
      expect(search.categories, ['AI', 'Istraživanje', 'Mobile']);
    });

    test('ranks name prefix matches first', () {
      final s = FeatureSearch([
        stand('a', 'Zeleni kod', 0, company: 'Kvant partner'),
        stand('b', 'Kvant', 0),
      ], labelOf: (_) => '');
      expect(s.search('kvant').map((f) => f.id), ['b', 'a']);
    });
  });

  group('featureAt', () {
    test('prefers the smallest area, so a stand inside a hall wins', () {
      expect(
        featureAt(
          demoMap.features,
          const PlanPoint(390, 350),
          tolerance: 10,
        )?.id,
        's1',
      );
      expect(
        featureAt(
          demoMap.features,
          const PlanPoint(100, 100),
          tolerance: 10,
        )?.id,
        'hall',
      );
    });

    test('hits points within tolerance and ignores markers', () {
      expect(
        featureAt(
          demoMap.features,
          const PlanPoint(1105, 445),
          tolerance: 10,
        )?.id,
        'wc',
      );
      expect(
        featureAt(demoMap.features, const PlanPoint(1130, 445), tolerance: 10),
        isNull,
      );
      expect(
        featureAt(
          demoMap.features,
          const PlanPoint(70, 380),
          tolerance: 10,
        )?.id,
        'hall',
      );
    });

    test('pointInPolygon handles concave shapes', () {
      const l = [
        PlanPoint(0, 0),
        PlanPoint(10, 0),
        PlanPoint(10, 5),
        PlanPoint(5, 5),
        PlanPoint(5, 10),
        PlanPoint(0, 10),
      ];
      expect(pointInPolygon(const PlanPoint(2, 8), l), isTrue);
      expect(pointInPolygon(const PlanPoint(8, 8), l), isFalse);
    });
  });

  group('PlanProjection', () {
    test('round-trips and stays inside flutter_map lat/lng limits', () {
      for (final (w, h) in [(1200, 800), (800, 3000), (5000, 400)]) {
        final proj = PlanProjection(w, h);
        final corner = proj.toLatLng(PlanPoint(w.toDouble(), h.toDouble()));
        expect(corner.latitude, inInclusiveRange(-90, 0));
        expect(corner.longitude, inInclusiveRange(0, 180));
        final back = proj.toPlan(proj.toLatLng(const PlanPoint(123, 45)));
        expect(back.x, closeTo(123, 1e-9));
        expect(back.y, closeTo(45, 1e-9));
      }
    });
  });
}
