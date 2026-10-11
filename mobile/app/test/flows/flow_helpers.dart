import 'dart:async';

import 'package:eho/app.dart';
import 'package:eho_maps/eho_maps.dart' show mapsSignedInProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Shared setup for the tap-through flow tests: a fresh real app (router,
/// theme, l10n) on demo data, on a phone-sized view.
Future<ProviderContainer> startApp(
  WidgetTester tester, {
  List<Override> overrides = const [],

  /// Keeps the venue map from signing in (it stays "loading" forever), for
  /// flows that never open the Map tab but whose screens peek at the map.
  /// Not for flows that land on the Map tab: its spinner never settles.
  bool mapStaysLoading = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      if (mapStaysLoading)
        mapsSignedInProvider.overrideWith((ref) => Completer<String>().future),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: EhoApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

/// The topmost page's location (includes pushed pages and the query).
String locationOf(WidgetTester tester) {
  final config = routerOf(tester).routerDelegate.currentConfiguration;
  final top = config.last.matchedLocation;
  // `uri` keeps the query but describes the `go` location, not pushed pages.
  return config.uri.path == top ? config.uri.toString() : top;
}

/// Opens [link] like a deep link / scanned QR.
Future<void> openLink(WidgetTester tester, String link) async {
  routerOf(tester).go(link);
  await tester.pumpAndSettle();
}

/// Join screen → onboarding (name, interests, consents) → event.
Future<void> joinAndOnboard(
  WidgetTester tester, {
  String name = 'Ilija',
  List<String> interests = const ['AI / ML', 'Mobile'],
}) async {
  await tester.tap(find.text('Join event'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, name);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  for (final i in interests) {
    await tester.tap(find.text(i));
  }
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

/// Taps a bottom-navigation tab.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Lets Echo's timed transcript stream and the demo replay finish.
Future<void> drainEcho(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 60));
  await tester.pumpAndSettle();
}
