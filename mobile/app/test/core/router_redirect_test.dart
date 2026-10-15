import 'package:eho/app.dart';
import 'package:eho/core/router.dart';
import 'package:eho_maps/eho_maps.dart' show MapViewerScreen;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const real = 'ik6vmvjr7wlektj6';
  String? redirect(String uri, [String target = real]) =>
      demoEventRedirect(Uri.parse(uri), target);

  test('devfest and legacy devsummit map to the real event id', () {
    expect(redirect('/e/devfest/agenda'), '/e/$real/agenda');
    expect(redirect('/e/devsummit/agenda'), '/e/$real/agenda');
    expect(redirect('/e/devfest'), '/e/$real');
    expect(redirect('/e/devfest/session/s1/echo'), '/e/$real/session/s1/echo');
  });

  test('query string and nested path survive', () {
    expect(redirect('/e/devfest/map?at=abc'), '/e/$real/map?at=abc');
    expect(
      redirect('/e/devfest/map/stand/x1?at=a%20b'),
      '/e/$real/map/stand/x1?at=a%20b',
    );
  });

  test('no redirect for other events, other routes, or the default id', () {
    expect(redirect('/e/$real/agenda'), isNull);
    expect(redirect('/e/other/agenda'), isNull);
    expect(redirect('/events'), isNull);
    expect(redirect('/o/e/devfest'), isNull);
    expect(redirect('/e/devfest/agenda', 'devfest'), isNull);
    expect(redirect('/e/devsummit/agenda', 'devfest'), isNull);
  });

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('default build keeps /e/devfest/agenda', (tester) async {
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Eho')));
    router.go('/e/devfest/agenda');
    await tester.pumpAndSettle();
    expect(location(router), '/e/devfest/agenda');
  });

  testWidgets('router built for a real id redirects devfest links', (
    tester,
  ) async {
    final router = buildRouter(demoId: real);
    await tester.pumpWidget(ProviderScope(child: EhoApp(router: router)));
    await tester.pumpAndSettle();
    router.go('/e/devfest/agenda?at=m1');
    await tester.pumpAndSettle();
    expect(location(router), '/e/$real/agenda?at=m1');
  });

  testWidgets('stand link keeps ?at= as the you-are-here marker', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Eho')));
    for (final link in [
      '/e/devfest/stand/x1?at=m1',
      '/e/devfest/map/stand/x1?at=m1',
    ]) {
      router.go(link);
      await tester.pumpAndSettle();
      expect(location(router), '/e/devfest/map/stand/x1?at=m1');
      final map = tester.widget<MapViewerScreen>(find.byType(MapViewerScreen));
      expect(map.initialFeatureId, 'x1');
      expect(map.markerId, 'm1');
      router.go('/e/devfest/agenda');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('stand link without ?at= has no marker', (tester) async {
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Eho')));
    router.go('/e/devfest/stand/x1');
    await tester.pumpAndSettle();
    expect(location(router), '/e/devfest/map/stand/x1');
    expect(
      tester.widget<MapViewerScreen>(find.byType(MapViewerScreen)).markerId,
      isNull,
    );
  });
}
