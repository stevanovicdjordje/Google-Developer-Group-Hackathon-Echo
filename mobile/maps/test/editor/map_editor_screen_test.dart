import 'dart:convert';

import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_providers.dart';
import 'package:eho_maps/src/editor/map_editor_screen.dart';
import 'package:eho_maps/src/editor/maps_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../viewer/fixtures.dart';

class _Organizer extends Fake implements User {
  @override
  bool get isAnonymous => false;
}

/// In-memory stand-in for the map API: records requests, answers like the server.
class FakeMapsServer {
  final requests = <http.Request>[];
  bool blockPublish = false;

  final draft = {
    'floors': [
      {
        'id': 'f1',
        'name': 'Prizemlje',
        'order': 0,
        'imagePath': 'events/e/floors/p.png',
        'width': 1000,
        'height': 600,
        'georef': null,
      },
    ],
    'features': [
      {
        'id': 's1',
        'type': 'stand',
        'floorId': 'f1',
        'name': 'Čačak Dev',
        'geometry': {
          'kind': 'rect',
          'coords': [
            {'x': 100, 'y': 100},
            {'x': 200, 'y': 160},
          ],
        },
      },
    ],
    'graphs': [
      {
        'floorId': 'f1',
        'nodes': [
          {'id': 'a', 'x': 480, 'y': 300},
          {'id': 'b', 'x': 900, 'y': 300},
        ],
        'edges': [
          {'from': 'a', 'to': 'b'},
        ],
      },
    ],
  };

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path;
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (r.method == 'GET' && path == '/v1/events/e') {
      return json({
        'id': 'e',
        'name': 'Test Expo',
        'startDate': '2026-10-10',
        'endDate': '2026-10-11',
        'address': '',
        'ownerUid': 'u',
        'publishedVersion': 0,
        'createdAt': '2026-10-10T00:00:00Z',
        'updatedAt': '2026-10-10T00:00:00Z',
      });
    }
    if (r.method == 'GET' && path == '/v1/events/e/draft') return json(draft);
    if (r.method == 'POST' && path == '/v1/events/e/features') {
      return json({...jsonDecode(r.body) as Map, 'id': 'new1'}, 201);
    }
    if (r.method == 'PUT' && path.endsWith('/graph')) {
      return json({...jsonDecode(r.body) as Map, 'floorId': 'f1'});
    }
    if (r.method == 'POST' && path == '/v1/events/e/publish') {
      if (blockPublish) {
        return json({
          'code': 'publish_blocked',
          'message': 'blocked',
          'details': {
            'errors': [
              {
                'code': 'unknown_entrance',
                'message': 'x',
                'featureId': 's1',
                'floorId': 'f1',
              },
            ],
            'warnings': <Object>[],
          },
        }, 422);
      }
      return json({'publishedVersion': 1, 'warnings': <Object>[]});
    }
    if (r.method == 'PUT' && path == '/v1/events/e/floors/f1/georef') {
      final floor = Map<String, dynamic>.from(
        (draft['floors'] as List).first as Map,
      );
      final cps = (jsonDecode(r.body) as Map)['controlPoints'];
      return json({
        'floor': {
          ...floor,
          'georef': {'controlPoints': cps, 'metersPerPixel': 0.05},
        },
        'quality': {
          'metersPerPixel': 0.05,
          'scaleMismatchPercent': 0.1,
          'skewDegrees': 0.1,
          'estimatedErrorMeters': 0.2,
        },
      });
    }
    return json({'code': 'not_found', 'message': 'no route'}, 404);
  }
}

Widget app(FakeMapsServer server) => ProviderScope(
  overrides: [
    organizerUserProvider.overrideWith((ref) => Stream.value(_Organizer())),
    mapsApiProvider.overrideWithValue(
      MapsApi(
        baseUrl: 'http://api',
        tokenProvider: () async => 'tok',
        httpClient: MockClient(server.handle),
      ),
    ),
    publishedMapRepositoryProvider.overrideWithValue(FakeRepository()),
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
    home: const MapEditorScreen(eventId: 'e'),
  ),
);

/// Taps the map and waits out flutter_map's double-tap detection.
Future<void> tapMap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1400, 900);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  testWidgets('adds a POI with the nearest node as its entrance', (
    tester,
  ) async {
    final server = FakeMapsServer();
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    expect(find.text('Test Expo'), findsOneWidget);
    expect(find.text('Čačak Dev'), findsOneWidget);

    await tester.tap(find.text('Mesto'));
    await tester.pumpAndSettle();
    await tapMap(tester, tester.getCenter(find.byType(FlutterMap)));
    expect(find.text('Novo: Mesto'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Info pult');
    await tester.tap(find.text('Napravi'));
    await tester.pumpAndSettle();

    final post = server.requests.lastWhere((r) => r.method == 'POST');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['type'], 'poi');
    expect(body['name'], 'Info pult');
    expect(body['poiKind'], 'info');
    expect(body['entranceNodeId'], 'a'); // the plan's center is next to "a"
    expect(find.text('Novo: Mesto'), findsNothing);
  });

  testWidgets('walkway taps are saved as one graph PUT', (tester) async {
    final server = FakeMapsServer();
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Staza'));
    await tester.pumpAndSettle();
    final c = tester.getCenter(find.byType(FlutterMap));
    await tapMap(tester, c + const Offset(-200, 120));
    await tapMap(tester, c + const Offset(-100, 120));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final puts = server.requests.where((r) => r.method == 'PUT').toList();
    expect(puts, isNotEmpty);
    final g = jsonDecode(puts.last.body) as Map<String, dynamic>;
    expect((g['nodes'] as List).length, 4);
    expect((g['edges'] as List).length, 2);
  });

  testWidgets('georeferencing: 3 taps + pasted coordinates are saved', (
    tester,
  ) async {
    final server = FakeMapsServer();
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sprat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podesi GPS (georeferenciranje)'));
    await tester.pumpAndSettle();
    expect(find.text('GPS za sprat „Prizemlje“'), findsOneWidget);
    expect(find.text('Dodirnite plan'), findsNWidgets(3));

    final c = tester.getCenter(find.byType(FlutterMap));
    await tapMap(tester, c + const Offset(-150, -60));
    await tapMap(tester, c + const Offset(150, -60));
    await tapMap(tester, c + const Offset(0, 80));
    expect(find.text('Dodirnite plan'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('cp-coords-0')),
      '44.80000, 20.40000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cp-coords-1')),
      'nije koordinata',
    );
    await tester.pump();
    expect(find.text('Unesite „širina, dužina“'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('cp-coords-1')),
      '44.80000 20.40100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cp-coords-2')),
      '44.79950°, 20.40050°',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Razmera:'), findsOneWidget);

    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();
    final put = server.requests.lastWhere(
      (r) => r.method == 'PUT' && r.url.path.endsWith('/georef'),
    );
    final cps = (jsonDecode(put.body) as Map)['controlPoints'] as List;
    expect(cps, hasLength(3));
    expect((cps[2] as Map)['latLng'], {'lat': 44.7995, 'lng': 20.4005});
    expect(
      find.text('GPS je podešen. Posetioci ga dobijaju posle objave.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Sprat'));
    await tester.pumpAndSettle();
    expect(find.text('GPS je podešen: izmeni'), findsOneWidget);
  });

  testWidgets('a blocked publish lists the issue in Serbian', (tester) async {
    final server = FakeMapsServer()..blockPublish = true;
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Objavi'));
    await tester.pumpAndSettle();
    expect(find.text('Objavljivanje nije moguće. Ispravite:'), findsOneWidget);
    expect(find.textContaining('„Čačak Dev“ kao ulaz koristi'), findsOneWidget);

    // Tapping the issue selects the feature.
    await tester.tap(find.textContaining('„Čačak Dev“ kao ulaz koristi'));
    await tester.pumpAndSettle();
    expect(find.text('Izmena: Čačak Dev'), findsOneWidget);
  });
}
