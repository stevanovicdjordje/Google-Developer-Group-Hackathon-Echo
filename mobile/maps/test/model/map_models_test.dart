import 'dart:convert';
import 'dart:io';

import 'package:eho_maps/eho_maps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the contract example of a stand', () {
    // Same file the contract validates against its schema.
    final json = jsonDecode(
      File('../../contracts/maps/examples/create-stand.request.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final f = Feature.fromJson(json, id: 's1');
    expect(f.type, FeatureType.stand);
    expect(f.sponsorTier, SponsorTier.gold);
    expect(f.geometry.kind, GeometryKind.rect);
    expect(f.geometry.center, const PlanPoint(410, 145));
    expect(f.routable, isTrue);
  });

  test('parses a draft map response and sorts floors', () {
    final map = VenueMap.fromJson({
      'floors': [
        {
          'id': 'f2',
          'name': 'Sprat 1',
          'order': 1,
          'imagePath': 'p2',
          'width': 800,
          'height': 600,
          'georef': null,
        },
        {
          'id': 'f1',
          'name': 'Prizemlje',
          'order': 0,
          'imagePath': 'p1',
          'width': 1000,
          'height': 600,
          'georef': {
            'metersPerPixel': 0.05,
            'controlPoints': [
              for (var i = 0; i < 3; i++)
                {
                  'px': {'x': i * 10, 'y': 0},
                  'latLng': {'lat': 44.8, 'lng': 20.4 + i / 1000},
                },
            ],
          },
        },
      ],
      'features': [
        {
          'id': 'p',
          'type': 'poi',
          'floorId': 'f1',
          'name': 'WC',
          'poiKind': 'toilet',
          'geometry': {
            'kind': 'point',
            'coords': [
              {'x': 1, 'y': 2},
            ],
          },
        },
      ],
      'graphs': [
        {
          'floorId': 'f1',
          'nodes': [
            {
              'id': 'a',
              'x': 1,
              'y': 1,
              'connector': 'L',
              'connectorKind': 'lift',
            },
          ],
          'edges': [],
        },
      ],
    });
    expect(map.floors.map((f) => f.id), ['f1', 'f2']);
    expect(map.floors.first.georef!.controlPoints, hasLength(3));
    expect(map.features.single.sponsorTier, SponsorTier.none);
    expect(map.features.single.routable, isFalse);
    expect(map.graphs.single.nodes.single.connector, 'L');
    expect(map.featuresOn('f2'), isEmpty);
  });
}
