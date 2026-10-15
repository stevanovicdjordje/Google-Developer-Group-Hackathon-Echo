import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/location/georef.dart';
import 'package:eho_maps/src/location/tracking.dart';
import 'package:flutter_test/flutter_test.dart';

/// North-up plan, 0.05 m/px (like the seed event), near Belgrade.
List<ControlPoint> northUp(double w, double h) {
  const lat0 = 44.8, lng0 = 20.4, mpp = 0.05;
  ControlPoint cp(double x, double y) => ControlPoint(
    px: PlanPoint(x, y),
    latLng: LatLngDeg(lat0 - y * mpp / 111320.0, lng0 + x * mpp / 79000.0),
  );
  return [cp(0, 0), cp(w, 0), cp(0, h)];
}

final floor = Floor(
  id: 'f1',
  name: 'P',
  order: 0,
  imagePath: 'p.png',
  width: 1200,
  height: 800,
  georef: Georeference(controlPoints: northUp(1200, 800), metersPerPixel: 0.05),
);

GpsFix fixAt(double x, double y, {double accuracy = 5}) =>
    GpsFix(Georef.of(floor)!.toLatLng(PlanPoint(x, y)), accuracy);

/// Along y = 400 from x 100 to 1100 (50 m).
const route = MapRoute(
  publishedVersion: 1,
  legs: [
    RouteLeg(
      floorId: 'f1',
      points: [PlanPoint(100, 400), PlanPoint(1100, 400)],
    ),
  ],
  distanceMeters: 50,
  durationSeconds: 42,
  distanceEstimated: false,
);

void main() {
  test('a fix lands on the right pixel with its accuracy in pixels', () {
    final f = placeFix(fixAt(600, 300, accuracy: 8), floor)!;
    expect(f.at.x, closeTo(600, 1e-6));
    expect(f.at.y, closeTo(300, 1e-6));
    expect(f.accuracyPixels, closeTo(160, 0.5)); // 8 m / 0.05
    expect(f.inside, isTrue);
    expect(f.usable, isTrue);
  });

  test('no georef → no dot; far away or imprecise → not usable', () {
    const plain = Floor(
      id: 'f2',
      name: 'S',
      order: 1,
      imagePath: 's.png',
      width: 10,
      height: 10,
    );
    expect(placeFix(fixAt(1, 1), plain), isNull);
    expect(placeFix(fixAt(-5000, 400), floor)!.inside, isFalse); // 250 m west
    final weak = placeFix(fixAt(600, 300, accuracy: 40), floor)!;
    expect(weak.inside, isTrue);
    expect(weak.usable, isFalse);
  });

  test('distance to a polyline', () {
    const line = [PlanPoint(0, 0), PlanPoint(10, 0), PlanPoint(10, 10)];
    expect(distanceToPolyline(const PlanPoint(5, 3), line), 3);
    expect(distanceToPolyline(const PlanPoint(13, 5), line), 3);
    expect(distanceToPolyline(const PlanPoint(-4, 3), line), 5);
  });

  test('on the route, off the route, arrived', () {
    TrackStep at(double x, double y, {double acc = 5}) =>
        trackRoute(route, placeFix(fixAt(x, y, accuracy: acc), floor)!);
    expect(at(500, 420), TrackStep.onRoute); // 1 m off
    expect(at(500, 650), TrackStep.onRoute); // 12.5 m: within 15 m
    expect(at(500, 800), TrackStep.offRoute); // 20 m off
    expect(at(500, 800, acc: 20), TrackStep.onRoute); // allowed 30 m
    expect(at(1050, 400), TrackStep.arrived); // 2.5 m from the end
    expect(at(950, 400), TrackStep.onRoute); // 7.5 m from the end
  });

  test('a route on another floor is not judged', () {
    const other = MapRoute(
      publishedVersion: 1,
      legs: [
        RouteLeg(floorId: 'f2', points: [PlanPoint(0, 0), PlanPoint(10, 0)]),
      ],
      distanceMeters: 1,
      durationSeconds: 1,
      distanceEstimated: false,
    );
    expect(
      trackRoute(other, placeFix(fixAt(500, 800), floor)!),
      TrackStep.onRoute,
    );
  });
}
