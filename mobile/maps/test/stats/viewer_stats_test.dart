import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_providers.dart';
import 'package:eho_maps/src/stats/stats_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../viewer/fixtures.dart';
import '../viewer/route_test.dart' show FakeRouteServer, oneFloor, publish;

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      2280,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets('the viewer reports QR, searches, opened details and routes', (
    tester,
  ) async {
    final repo = FakeRepository();
    final server = FakeRouteServer(oneFloor);
    final sent = <Map<String, dynamic>>[];
    late StatsReporter reporter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapsSignedInProvider.overrideWith((ref) async => 'test-uid'),
          publishedMapRepositoryProvider.overrideWithValue(repo),
          mapsApiProvider.overrideWithValue(server.api),
          mapsStatsReporterProvider.overrideWith((ref, eventId) {
            expect(eventId, 'e');
            reporter = StatsReporter(
              (b) async => sent.addAll([for (final e in b) e.toJson()]),
              interval: const Duration(hours: 1),
            );
            ref.onDispose(reporter.dispose);
            return reporter;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('sr'),
          supportedLocales: MapsLocalizations.supportedLocales,
          localizationsDelegates: [
            MapsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MapViewerScreen(eventId: 'e', markerId: 'qr'),
        ),
      ),
    );
    await publish(tester, repo);
    List<Map<String, dynamic>> pending() => [
      for (final e in reporter.pending) e.toJson(),
    ];
    expect(pending(), [
      {'type': 'qr_scan', 'featureId': 'qr'},
    ]);

    // A search counts after a pause in typing, with its result count.
    await tester.enterText(find.byType(TextField), 'kaf');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'kafa');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(pending(), hasLength(1)); // still typing
    await tester.pump(const Duration(milliseconds: 600));
    expect(pending().last, {
      'type': 'search',
      'query': 'kafa',
      'resultCount': 0,
    });

    // Opening a result counts the search right away, then the details.
    await tester.enterText(find.byType(TextField), 'neuro');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Neuro Lab'));
    await tester.pumpAndSettle();
    expect(pending().sublist(2), [
      {'type': 'search', 'query': 'neuro', 'resultCount': 1},
      {'type': 'feature_view', 'featureId': 's2'},
    ]);

    // A route from the scanned QR marker counts its target.
    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    expect(pending().last, {'type': 'route', 'featureId': 's2'});
    expect(server.requests, hasLength(1)); // only the route itself
    expect(pending().any((e) => e.containsKey('point')), isFalse);

    // Closing the map sends what is queued.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(sent, hasLength(5));
  });
}
