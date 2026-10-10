import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('areaFrom', () {
    test('2 points make a normalized rect', () {
      final g = areaFrom(const [PlanPoint(50, 40), PlanPoint(10, 90)])!;
      expect(g.kind, GeometryKind.rect);
      expect(g.coords, const [PlanPoint(10, 40), PlanPoint(50, 90)]);
    });

    test('3+ points make a polygon', () {
      final g = areaFrom(const [
        PlanPoint(0, 0),
        PlanPoint(10, 0),
        PlanPoint(5, 8),
      ])!;
      expect(g.kind, GeometryKind.polygon);
      expect(g.coords.length, 3);
    });

    test('too few points or a flat rect give null', () {
      expect(areaFrom(const [PlanPoint(1, 1)]), isNull);
      expect(areaFrom(const [PlanPoint(1, 1), PlanPoint(1, 50)]), isNull);
    });
  });

  test('moveCenterTo and clampTo keep the shape on the plan', () {
    const g = Geometry(GeometryKind.rect, [PlanPoint(0, 0), PlanPoint(20, 10)]);
    final moved = moveCenterTo(g, const PlanPoint(100, 100));
    expect(moved.coords, const [PlanPoint(90, 95), PlanPoint(110, 105)]);
    final clamped = clampTo(moved, 100, 100);
    expect(clamped.coords, const [PlanPoint(90, 95), PlanPoint(100, 100)]);
  });

  group('graph', () {
    var g = emptyGraph('f1');
    g = addNode(g, const GraphNode(id: 'a', x: 0, y: 0));
    g = addNode(g, const GraphNode(id: 'b', x: 100, y: 0));
    g = addNode(g, const GraphNode(id: 'c', x: 100, y: 100));

    test('connect is undirected and skips duplicates and loops', () {
      var h = connect(g, 'a', 'b');
      h = connect(h, 'b', 'a');
      h = connect(h, 'c', 'c');
      expect(h.edges.length, 1);
      expect(hasEdge(h, 'b', 'a'), isTrue);
    });

    test('removeNode drops its edges', () {
      final h = removeNode(connect(connect(g, 'a', 'b'), 'b', 'c'), 'b');
      expect(h.nodes.map((n) => n.id), ['a', 'c']);
      expect(h.edges, isEmpty);
    });

    test('nearestNode respects maxDistance', () {
      expect(nearestNode(g, const PlanPoint(90, 5))?.id, 'b');
      expect(nearestNode(g, const PlanPoint(50, 50), maxDistance: 10), isNull);
    });

    test('newNodeId is unique on the floor', () {
      final ids = {for (var i = 0; i < 50; i++) newNodeId(g)};
      expect(ids.length, 50);
      expect(ids.every((id) => !['a', 'b', 'c'].contains(id)), isTrue);
    });
  });

  group('FeatureDraft.toJson', () {
    test('create: only the fields of the type, no empty text', () {
      final d = FeatureDraft(
        type: FeatureType.stand,
        floorId: 'f1',
        geometry: const Geometry(GeometryKind.point, [PlanPoint(1, 2)]),
        name: ' Čačak Dev ',
        company: 'Čačak Dev d.o.o.',
        capacity: 30, // ignored for stands
        entranceNodeId: 'n1',
      );
      expect(d.toJson(), {
        'type': 'stand',
        'floorId': 'f1',
        'name': 'Čačak Dev',
        'geometry': {
          'kind': 'point',
          'coords': [
            {'x': 1.0, 'y': 2.0},
          ],
        },
        'entranceNodeId': 'n1',
        'company': 'Čačak Dev d.o.o.',
        'sponsorTier': 'none',
      });
    });

    test('patch: no type/floor, clears text and entrance with ""', () {
      final d = FeatureDraft(
        type: FeatureType.poi,
        floorId: 'f1',
        geometry: const Geometry(GeometryKind.point, [PlanPoint(1, 2)]),
        name: 'Toalet',
        poiKind: 'toilet',
      );
      final j = d.toJson(patch: true);
      expect(j.containsKey('type'), isFalse);
      expect(j.containsKey('floorId'), isFalse);
      expect(j['description'], '');
      expect(j['link'], '');
      expect(j['entranceNodeId'], '');
      expect(j['poiKind'], 'toilet');
    });
  });
}
