import 'dart:async';
import 'dart:convert';

import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_providers.dart';
import 'package:eho_maps/src/editor/maps_api.dart';
import 'package:eho_maps/src/location/georef.dart';
import 'package:eho_maps/src/location/location_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

/// North-up, 0.05 m/px, like the seed event.
List<ControlPoint> northUp(double w, double h) {
  const lat0 = 44.8, lng0 = 20.4, mpp = 0.05;
  ControlPoint cp(double x, double y) => ControlPoint(
    px: PlanPoint(x, y),
    latLng: LatLngDeg(lat0 - y * mpp / 111320.0, lng0 + x * mpp / 79000.0),
  );
  return [cp(0, 0), cp(w, 0), cp(0, h)];
}

final georefMap = VenueMap(
  version: 1,
  floors: [
    for (final f in demoMap.floors)
      Floor(
        id: f.id,
        name: f.name,
        order: f.order,
        imagePath: f.imagePath,
        width: f.width,
        height: f.height,
        georef: f.id == 'f1'
            ? Georeference(
                controlPoints: northUp(1200, 800),
                metersPerPixel: 0.05,
              )
            : null,
      ),
  ],
  features: demoMap.features,
  graphs: const [],
);

final georef = Georef.of(georefMap.floors.first)!;

GpsFix fixAt(double x, double y, {double accuracy = 5}) =>
    GpsFix(georef.toLatLng(PlanPoint(x, y)), accuracy);

class FakeLocation implements LocationSource {
  final controller = StreamController<GpsFix>.broadcast();
  int watching = 0;

  @override
  Stream<GpsFix> watch() {
    watching++;
    return controller.stream;
  }
}

/// (300, 600) → up to the hall at (300, 200): 20 m.
const upRoute = {
  'publishedVersion': 1,
  'legs': [
    {
      'floorId': 'f1',
      'points': [
        {'x': 300, 'y': 600},
        {'x': 300, 'y': 200},
      ],
    },
  ],
  'distanceMeters': 20,
  'durationSeconds': 17,
  'distanceEstimated': false,
};

class Harness {
  final repo = FakeRepository();
  final location = FakeLocation();
  final requests = <Map<String, dynamic>>[];

  Widget app({String? featureId}) => ProviderScope(
    overrides: [
      mapsSignedInProvider.overrideWith((ref) async => 'test-uid'),
      publishedMapRepositoryProvider.overrideWithValue(repo),
      locationSourceProvider.overrideWithValue(location),
      mapsApiProvider.overrideWithValue(
        MapsApi(
          baseUrl: 'http://api',
          tokenProvider: () async => 'tok',
          httpClient: MockClient((req) async {
            requests.add(jsonDecode(req.body) as Map<String, dynamic>);
            return http.Response(jsonEncode(upRoute), 200);
          }),
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('sr'),
      supportedLocales: MapsLocalizations.supportedLocales,
      localizationsDelegates: const [
        MapsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MapViewerScreen(eventId: 'e', initialFeatureId: featureId),
    ),
  );

  Future<void> start(WidgetTester tester, {String? featureId}) async {
    await tester.pumpWidget(app(featureId: featureId));
    await tester.pump();
    repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: georefMap));
    await tester.pumpAndSettle();
  }

  Future<void> gps(WidgetTester tester, GpsFix fix) async {
    location.controller.add(fix);
    await tester.pumpAndSettle();
  }
}

Finder get accuracyCircle => find.byWidgetPredicate(
  (w) =>
      w is CircleLayer &&
      w.circles.any((c) => c.key == const ValueKey('gps-accuracy')),
);

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      2280,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets('no georeferenced floor → no "Moja lokacija" button', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapsSignedInProvider.overrideWith((ref) async => 'test-uid'),
          publishedMapRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('sr'),
          supportedLocales: MapsLocalizations.supportedLocales,
          localizationsDelegates: const [
            MapsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MapViewerScreen(eventId: 'e'),
        ),
      ),
    );
    await tester.pump();
    repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: demoMap));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Moja lokacija'), findsNothing);
  });

  testWidgets('a good fix is "Vi ste ovde" and the route start; '
      'leaving the route re-routes; arriving says so', (tester) async {
    final h = Harness();
    await h.start(tester);

    await tester.tap(find.byTooltip('Moja lokacija'));
    await tester.pumpAndSettle();
    expect(h.location.watching, 1);
    expect(find.text('Tražim GPS signal…'), findsOneWidget);

    await h.gps(tester, fixAt(300, 600));
    expect(find.text('Tražim GPS signal…'), findsNothing);
    expect(find.text('Vi ste ovde'), findsOneWidget);
    expect(accuracyCircle, findsOneWidget);

    // Route to the hall starts at the GPS position, no picker.
    await tester.enterText(find.byType(TextField), 'glavna');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Glavna sala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    expect(find.text('Odakle krećete?'), findsNothing);
    final from = h.requests.single['from'] as Map<String, dynamic>;
    expect(from['floorId'], 'f1');
    final p = from['point'] as Map<String, dynamic>;
    expect((p['x'] as num).toDouble(), closeTo(300, 1e-3));
    expect((p['y'] as num).toDouble(), closeTo(600, 1e-3));
    expect(find.text('Do: Glavna sala'), findsOneWidget);

    // Still on the way: nothing new.
    await h.gps(tester, fixAt(310, 400));
    expect(h.requests, hasLength(1));

    // 30 m off the route: a new route from here.
    await h.gps(tester, fixAt(900, 600));
    expect(h.requests, hasLength(2));
    final p2 = (h.requests.last['from'] as Map)['point'] as Map;
    expect((p2['x'] as num).toDouble(), closeTo(900, 1e-3));

    // At the end of the (fake) route.
    await h.gps(tester, fixAt(300, 210));
    expect(find.text('Stigli ste: Glavna sala'), findsOneWidget);
    expect(find.text('Do: Glavna sala'), findsNothing);
  });

  testWidgets('a weak fix is only a hint; the route asks where you are', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester, featureId: 'hall');
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Moja lokacija'));
    await tester.pumpAndSettle();
    await h.gps(tester, fixAt(300, 600, accuracy: 40));
    expect(
      find.text(
        'GPS je neprecizan (±40 m). Skenirajte QR kod ili izaberite mesto na mapi.',
      ),
      findsOneWidget,
    );
    expect(find.text('Vi ste ovde'), findsNothing);
    expect(accuracyCircle, findsOneWidget);

    await tester.enterText(find.byType(TextField), 'glavna');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Glavna sala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    expect(find.text('Odakle krećete?'), findsOneWidget);
    expect(h.requests, isEmpty);
  });

  testWidgets('a floor without georef says so', (tester) async {
    final h = Harness();
    await h.start(tester);
    await tester.tap(find.byTooltip('Moja lokacija'));
    await tester.pumpAndSettle();
    await h.gps(tester, fixAt(300, 600));
    await tester.tap(find.text('Sprat 1'));
    await tester.pumpAndSettle();
    expect(find.text('Za ovaj sprat GPS nije podešen.'), findsOneWidget);
    expect(find.text('Vi ste ovde'), findsNothing);
  });

  testWidgets('a lost signal shows "searching" and the dot comes back', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester);
    await tester.tap(find.byTooltip('Moja lokacija'));
    await tester.pumpAndSettle();
    await h.gps(tester, fixAt(300, 600));
    expect(find.text('Vi ste ovde'), findsOneWidget);

    h.location.controller.addError(
      const LocationUnavailable(LocationProblem.failed),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tražim GPS signal…'), findsOneWidget);
    expect(find.text('Vi ste ovde'), findsNothing);

    await h.gps(tester, fixAt(320, 600));
    expect(find.text('Vi ste ovde'), findsOneWidget);
    expect(h.location.watching, 1); // still the same subscription
  });

  testWidgets('denied permission explains the fallback', (tester) async {
    final h = Harness();
    await h.start(tester);
    await tester.tap(find.byTooltip('Moja lokacija'));
    await tester.pumpAndSettle();
    h.location.controller.addError(
      const LocationUnavailable(LocationProblem.denied),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Lokacija nije dozvoljena. Skenirajte QR kod ili izaberite mesto na mapi.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tražim GPS signal…'), findsNothing);
  });
}
