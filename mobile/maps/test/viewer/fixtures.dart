import 'dart:async';

import 'package:eho_maps/eho_maps.dart';

Feature stand(
  String id,
  String name,
  double x, {
  String company = '',
  String category = '',
  SponsorTier tier = SponsorTier.none,
  String floorId = 'f1',
}) => Feature(
  id: id,
  type: FeatureType.stand,
  floorId: floorId,
  name: name,
  company: company,
  category: category,
  sponsorTier: tier,
  geometry: Geometry(GeometryKind.rect, [
    PlanPoint(x - 30, 330),
    PlanPoint(x + 30, 380),
  ]),
  entranceNodeId: 'n',
);

final demoMap = VenueMap(
  version: 1,
  floors: const [
    Floor(
      id: 'f1',
      name: 'Prizemlje',
      order: 0,
      imagePath: 'events/e/floors/p.png',
      width: 1200,
      height: 800,
    ),
    Floor(
      id: 'f2',
      name: 'Sprat 1',
      order: 1,
      imagePath: 'events/e/floors/s1.png',
      width: 1200,
      height: 800,
    ),
  ],
  features: [
    const Feature(
      id: 'hall',
      type: FeatureType.room,
      floorId: 'f1',
      name: 'Glavna sala',
      capacity: 400,
      geometry: Geometry(GeometryKind.rect, [
        PlanPoint(0, 0),
        PlanPoint(600, 400),
      ]),
    ),
    stand('s1', 'Čačak Dev', 390, company: 'Primer Čačak', category: 'Mobile'),
    stand(
      's2',
      'Neuro Lab',
      470,
      company: 'Primer AI d.o.o.',
      category: 'AI',
      tier: SponsorTier.gold,
    ),
    stand(
      's3',
      'Kvant',
      550,
      company: 'Primer Quantum',
      category: 'Istraživanje',
      floorId: 'f2',
    ),
    const Feature(
      id: 'wc',
      type: FeatureType.poi,
      floorId: 'f1',
      name: 'Toalet',
      poiKind: 'toilet',
      geometry: Geometry(GeometryKind.point, [PlanPoint(1100, 440)]),
    ),
    const Feature(
      id: 'qr',
      type: FeatureType.marker,
      floorId: 'f1',
      name: 'Ulaz (QR)',
      geometry: Geometry(GeometryKind.point, [PlanPoint(70, 380)]),
    ),
  ],
  graphs: const [],
);

class FakeRepository implements PublishedMapRepository {
  final controller = StreamController<PublishedEvent>.broadcast();

  @override
  Stream<PublishedEvent> watch(String eventId) => controller.stream;

  @override
  Future<String> imageUrl(String path) =>
      Future.error(StateError('no images in tests'));
}
