import 'dart:convert';

import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_providers.dart';
import 'package:eho_maps/src/editor/maps_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

/// Ulaz (QR) on the ground floor → Kvant on Sprat 1, by lift.
const twoFloors = {
  'publishedVersion': 1,
  'legs': [
    {
      'floorId': 'f1',
      'points': [
        {'x': 70, 'y': 380},
        {'x': 300, 'y': 380},
        {'x': 300, 'y': 120},
      ],
    },
    {
      'floorId': 'f2',
      'arriveBy': 'lift',
      'points': [
        {'x': 300, 'y': 120},
        {'x': 550, 'y': 355},
      ],
    },
  ],
  'distanceMeters': 52.4,
  'durationSeconds': 43,
  'distanceEstimated': true,
};

const oneFloor = {
  'publishedVersion': 1,
  'legs': [
    {
      'floorId': 'f1',
      'points': [
        {'x': 600, 'y': 400},
        {'x': 300, 'y': 200},
      ],
    },
  ],
  'distanceMeters': 18,
  'durationSeconds': 15,
  'distanceEstimated': false,
};

class FakeRouteServer {
  FakeRouteServer(this.response, {this.status = 200});

  Object response;
  int status;
  final requests = <Map<String, dynamic>>[];

  MapsApi get api => MapsApi(
    baseUrl: 'http://api',
    tokenProvider: () async => 'tok',
    httpClient: MockClient((req) async {
      requests.add(jsonDecode(req.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(response), status);
    }),
  );
}

Widget app(
  FakeRepository repo,
  FakeRouteServer server, {
  String? featureId,
  String? markerId,
}) => ProviderScope(
  overrides: [
    mapsSignedInProvider.overrideWith((ref) async => 'test-uid'),
    publishedMapRepositoryProvider.overrideWithValue(repo),
    mapsApiProvider.overrideWithValue(server.api),
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
    home: MapViewerScreen(
      eventId: 'e',
      initialFeatureId: featureId,
      markerId: markerId,
    ),
  ),
);

Future<void> publish(WidgetTester tester, FakeRepository repo) async {
  await tester.pump();
  repo.controller.add(
    PublishedEvent(id: 'e', name: 'Eho Demo Expo', map: demoMap),
  );
  await tester.pumpAndSettle();
}

/// Taps the map and waits out flutter_map's double-tap detection.
Future<void> tapMap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1080,
      2280,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets('from the scanned QR: route over two floors, lift banner', (
    tester,
  ) async {
    final repo = FakeRepository();
    final server = FakeRouteServer(twoFloors);
    await tester.pumpWidget(app(repo, server, featureId: 's3', markerId: 'qr'));
    await publish(tester, repo);

    // Deep link to Kvant (Sprat 1) opened its details.
    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();

    expect(server.requests.single, {
      'from': {'featureId': 'qr'},
      'to': {'featureId': 's3'},
      'accessible': false,
    });
    expect(find.text('Do: Kvant'), findsOneWidget);
    expect(find.textContaining('52 m · 1 min'), findsOneWidget);
    expect(find.textContaining('procena'), findsOneWidget);
    // The route starts on the ground floor, where the attendee is.
    expect(find.text('Vi ste ovde'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-end')), findsNothing);
    expect(find.text('Idite liftom na sprat Sprat 1'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // search hidden

    await tester.tap(find.text('Prikaži'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-end')), findsOneWidget);
    expect(find.text('Vi ste ovde'), findsNothing); // on the ground floor
    expect(find.textContaining('Idite liftom'), findsNothing);

    // "No stairs" asks again.
    await tester.tap(find.text('Bez stepenica'));
    await tester.pumpAndSettle();
    expect(server.requests.last['accessible'], isTrue);

    await tester.tap(find.byTooltip('Zatvori put'));
    await tester.pumpAndSettle();
    expect(find.text('Do: Kvant'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('without a QR: pick a start, or tap where you are', (
    tester,
  ) async {
    final repo = FakeRepository();
    final server = FakeRouteServer(oneFloor);
    await tester.pumpWidget(app(repo, server, featureId: 'hall'));
    await publish(tester, repo);
    expect(find.text('Vi ste ovde'), findsNothing);

    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    expect(find.text('Odakle krećete?'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Ulaz (QR)'), findsOneWidget);
    expect(server.requests, isEmpty);

    await tester.tap(find.text('Izaberite na mapi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Dodirnite mesto na mapi gde se nalazite'),
      findsOneWidget,
    );

    await tapMap(tester, tester.getCenter(find.byType(FlutterMap)));
    final from = server.requests.single['from'] as Map<String, dynamic>;
    expect(from['floorId'], 'f1');
    expect(from['point'], isA<Map<String, dynamic>>());
    expect(find.text('Do: Glavna sala'), findsOneWidget);
    expect(find.textContaining('18 m · 1 min'), findsOneWidget);
    expect(find.textContaining('procena'), findsNothing);
    expect(find.text('Vi ste ovde'), findsOneWidget);
    expect(find.text('Bez stepenica'), findsOneWidget); // two floors
  });

  testWidgets('a start from the list', (tester) async {
    final repo = FakeRepository();
    final server = FakeRouteServer(oneFloor);
    await tester.pumpWidget(app(repo, server, featureId: 'hall'));
    await publish(tester, repo);

    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ulaz (QR)'));
    await tester.pumpAndSettle();
    expect(server.requests.single['from'], {'featureId': 'qr'});
    expect(find.text('Do: Glavna sala'), findsOneWidget);
  });

  testWidgets('no_route closes the route with a message', (tester) async {
    final repo = FakeRepository();
    final server = FakeRouteServer({
      'code': 'no_route',
      'message': 'not connected',
    }, status: 422);
    await tester.pumpWidget(app(repo, server, featureId: 'wc', markerId: 'qr'));
    await publish(tester, repo);

    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    expect(find.text('Do ovog mesta nema puta na mapi.'), findsOneWidget);
    expect(find.text('Do: Toalet'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a new publish computes the route again', (tester) async {
    final repo = FakeRepository();
    final server = FakeRouteServer(oneFloor);
    await tester.pumpWidget(
      app(repo, server, featureId: 'hall', markerId: 'qr'),
    );
    await publish(tester, repo);
    await tester.tap(find.text('Prikaži put'));
    await tester.pumpAndSettle();
    expect(server.requests, hasLength(1));

    repo.controller.add(
      PublishedEvent(
        id: 'e',
        name: 'Eho Demo Expo',
        map: VenueMap(
          version: 2,
          floors: demoMap.floors,
          features: demoMap.features,
          graphs: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(server.requests, hasLength(2));
    expect(find.text('Do: Glavna sala'), findsOneWidget);
  });
}
