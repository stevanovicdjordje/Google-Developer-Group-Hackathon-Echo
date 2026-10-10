import 'dart:convert';
import 'dart:io';

import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_providers.dart';
import 'package:eho_maps/src/editor/maps_api.dart';
import 'package:eho_maps/src/model/stats_models.dart';
import 'package:eho_maps/src/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String example(String name) =>
    File('../../contracts/maps/examples/$name').readAsStringSync();

/// A JSON response as the server sends it (UTF-8).
http.Response json(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const event = {
  'id': 'e1',
  'name': 'Eho Demo Expo',
  'startDate': '2026-10-10',
  'endDate': '2026-10-12',
  'address': '',
  'ownerUid': 'o',
  'publishedVersion': 2,
  'createdAt': '2026-10-01T10:00:00Z',
  'updatedAt': '2026-10-01T10:00:00Z',
};

final empty = {
  'from': '2026-10-11',
  'to': '2026-10-11',
  'totals': {
    'searches': 0,
    'searchesNoResults': 0,
    'featureViews': 0,
    'routes': 0,
    'qrScans': 0,
  },
  'days': [
    {
      'date': '2026-10-11',
      'searches': 0,
      'searchesNoResults': 0,
      'featureViews': 0,
      'routes': 0,
      'qrScans': 0,
    },
  ],
  'topSearches': <Object>[],
  'topNoResults': <Object>[],
  'topFeatures': <Object>[],
  'topRouteTargets': <Object>[],
  'qrScans': <Object>[],
};

void main() {
  test('API: records a batch and parses the stats fixture', () async {
    final seen = <http.Request>[];
    final api = MapsApi(
      baseUrl: 'http://api',
      tokenProvider: () async => 'tok',
      httpClient: MockClient((req) async {
        seen.add(req);
        return req.method == 'POST'
            ? http.Response('{"accepted":2,"dropped":0}', 202)
            : json(example('stats.response.json'));
      }),
    );
    await api.recordStats('e1', const [
      StatsEvent.search('kafa', 0),
      StatsEvent.qrScan('qr'),
    ]);
    expect(seen.first.url.path, '/v1/events/e1/stats/events');
    // Same shape as the contract's request fixture.
    final fixture = jsonDecode(example('stats-events.request.json')) as Map;
    expect(
      (jsonDecode(seen.first.body)['events'] as List).first.keys,
      (fixture['events'] as List)[1].keys,
    );

    final s = await api.getStats('e1', from: '2026-10-10', to: '2026-10-12');
    expect(seen.last.url.query, 'from=2026-10-10&to=2026-10-12');
    expect(s.totals.searches, 41);
    expect(s.days, hasLength(3));
    expect(s.days[1].interactions, 29 + 43 + 19 + 12);
    expect(s.topNoResults.first.query, 'kafa');
    expect(s.topFeatures.last.name, isEmpty);
    expect(s.qrScans.single.count, 18);
  });

  test('ranges are UTC days; event dates come from the event', () {
    final e = OrganizerEvent.fromJson(event);
    final now = DateTime.utc(2026, 10, 11, 23, 30);
    expect(statsDates(StatsRange.today, e, now), ('2026-10-11', '2026-10-11'));
    expect(statsDates(StatsRange.days7, e, now), ('2026-10-05', '2026-10-11'));
    expect(statsDates(StatsRange.days30, e, now), ('2026-09-12', '2026-10-11'));
    expect(statsDates(StatsRange.event, e, now), ('2026-10-10', '2026-10-12'));
  });

  testWidgets('organizer screen: totals, not found, lists, range switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final queries = <String>[];
    final api = MapsApi(
      baseUrl: 'http://api',
      tokenProvider: () async => 'tok',
      httpClient: MockClient((req) async {
        if (req.url.path == '/v1/events/e1') {
          return json(jsonEncode(event));
        }
        queries.add(req.url.query);
        return req.url.query.contains('from=2026-10-10')
            ? json(example('stats.response.json'))
            : json(jsonEncode(empty));
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapsApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: const Locale('sr'),
          supportedLocales: MapsLocalizations.supportedLocales,
          localizationsDelegates: const [
            MapsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MapStatsScreen(
            eventId: 'e1',
            now: () => DateTime.utc(2026, 10, 11, 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default: the event's dates.
    expect(queries.single, 'from=2026-10-10&to=2026-10-12');
    expect(find.text('Statistika mape · Eho Demo Expo'), findsOneWidget);
    expect(find.text('41'), findsOneWidget); // searches
    expect(find.text('Traže, a ne nalaze'), findsOneWidget);
    expect(find.text('punjač'), findsOneWidget);
    expect(find.text('Aktivnost po danu'), findsOneWidget);
    expect(find.byType(DailyBars), findsOneWidget);
    expect(find.text('(uklonjeno sa plana)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ulaz (QR)'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Ulaz (QR)'), findsOneWidget);

    await tester.tap(find.text('Danas'));
    await tester.pumpAndSettle();
    expect(queries.last, 'from=2026-10-11&to=2026-10-11');
    expect(find.textContaining('Još nema podataka'), findsOneWidget);
    expect(find.byType(DailyBars), findsNothing);
    expect(find.textContaining('Bez lokacija'), findsOneWidget);
  });
}
