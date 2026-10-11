import 'package:eho/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A new attendee scans a venue QR (`/e/{id}?at={marker}`): the marker must
/// survive join + onboarding. The Map tab itself needs Firebase, so only the
/// router location is asserted.
void main() {
  Future<GoRouter> open(WidgetTester tester, String link) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Eho')));
    router.go(link);
    await tester.pumpAndSettle();
    expect(find.text('DevFest Belgrade 2026'), findsOneWidget);
    return router;
  }

  Future<void> joinWithOnboarding(WidgetTester tester) async {
    await tester.tap(find.text('Join event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ilija');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  String location(GoRouter r) =>
      r.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('QR link keeps ?at= through join and onboarding', (tester) async {
    final router = await open(tester, '/e/devfest?at=m1');
    await joinWithOnboarding(tester);
    expect(location(router), '/e/devfest/map?at=m1');
  });

  testWidgets('link without ?at= still lands on the agenda', (tester) async {
    final router = await open(tester, '/e/devfest');
    await joinWithOnboarding(tester);
    expect(location(router), '/e/devfest/agenda');
  });

  testWidgets('old /e/devsummit link joins the DevFest demo event', (
    tester,
  ) async {
    final router = await open(tester, '/e/devsummit?at=m1');
    await joinWithOnboarding(tester);
    expect(location(router), '/e/devfest/map?at=m1');
  });
}
