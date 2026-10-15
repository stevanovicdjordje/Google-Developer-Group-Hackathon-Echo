import 'package:eho_maps/eho_maps.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses one point or a path; rejects junk', () {
    expect(DemoLocationSource.parse(''), isNull);
    expect(DemoLocationSource.parse('44.8'), isNull);
    expect(DemoLocationSource.parse('44.8,abc'), isNull);
    expect(DemoLocationSource.parse('95,20'), isNull);
    final one = DemoLocationSource.parse(' 44.8 , 20.4 ')!;
    expect(one.path.single.lat, 44.8);
    expect(one.path.single.lng, 20.4);
    expect(
      DemoLocationSource.parse('44.8,20.4;44.801,20.4')!.path,
      hasLength(2),
    );
  });

  test('walks along the path at walking speed and stays at the end', () {
    // ~111 m north.
    final s = DemoLocationSource.parse('44.8,20.4;44.801,20.4')!;
    expect(s.positionAt(0).lat, 44.8);
    final half = s.positionAt(111.2 / 2 / 1.2);
    expect(half.lat, closeTo(44.8005, 0.00002));
    expect(s.positionAt(1000).lat, 44.801);
    expect(s.positionAt(1000).lng, 20.4);
  });

  test('a still point emits once; a path keeps emitting', () {
    fakeAsync((async) {
      final fixes = <GpsFix>[];
      DemoLocationSource.parse('44.8,20.4')!.watch().listen(fixes.add);
      async.elapse(const Duration(seconds: 5));
      expect(fixes, hasLength(1));
      expect(fixes.single.accuracyMeters, 5);

      final walk = <GpsFix>[];
      DemoLocationSource.parse('44.8,20.4;44.801,20.4')!
          .watch()
          .listen(walk.add);
      async.elapse(const Duration(seconds: 3));
      expect(walk.length, greaterThanOrEqualTo(3));
    });
  });
}
