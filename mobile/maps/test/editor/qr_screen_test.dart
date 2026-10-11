import 'dart:convert';

import 'package:eho_maps/eho_maps.dart';
import 'package:eho_maps/src/editor/editor_providers.dart';
import 'package:eho_maps/src/editor/maps_api.dart';
import 'package:eho_maps/src/editor/qr_print.dart';
import 'package:eho_maps/src/editor/qr_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _Organizer extends Fake implements User {
  @override
  bool get isAnonymous => false;
}

Map<String, Object?> _marker(String id, String floor, String name) => {
  'id': id,
  'type': 'marker',
  'floorId': floor,
  'name': name,
  'geometry': {
    'kind': 'point',
    'coords': [
      {'x': 10, 'y': 10},
    ],
  },
};

Map<String, Object?> _floor(String id, String name, int order) => {
  'id': id,
  'name': name,
  'order': order,
  'imagePath': 'events/e/floors/$id.png',
  'width': 100,
  'height': 100,
};

Widget _app({required int published, required List<Object?> features}) {
  final api = MapsApi(
    baseUrl: 'http://api',
    tokenProvider: () async => 'tok',
    httpClient: MockClient((r) async {
      final body = r.url.path == '/v1/events/e'
          ? {
              'id': 'e',
              'name': 'Test <Expo>',
              'startDate': '2026-10-10',
              'endDate': '2026-10-11',
              'address': '',
              'ownerUid': 'u',
              'publishedVersion': published,
              'createdAt': '2026-10-10T00:00:00Z',
              'updatedAt': '2026-10-10T00:00:00Z',
            }
          : {
              'floors': [
                _floor('f2', 'Sprat 1', 1),
                _floor('f1', 'Prizemlje', 0),
              ],
              'features': features,
              'graphs': <Object>[],
            };
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  return ProviderScope(
    overrides: [
      mapsApiProvider.overrideWithValue(api),
      organizerUserProvider.overrideWith((ref) => Stream.value(_Organizer())),
      mapsLinkBaseProvider.overrideWithValue('https://eho.example'),
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
      home: _Holder(),
    ),
  );
}

String? printed;

class _Holder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MapQrScreen(
    eventId: 'e',
    openPage: (html) {
      printed = html;
      return true;
    },
  );
}

void main() {
  test('marker links follow the join-link format', () {
    expect(
      markerLink('https://eho.example/', 'k3d', 'zv e'),
      'https://eho.example/e/k3d?at=zv%20e',
    );
  });

  test('SVG QR has a quiet zone and is square', () {
    final svg = qrSvg('https://eho.example/e/k3d?at=zv');
    final box = RegExp(r'viewBox="0 0 (\d+) (\d+)"').firstMatch(svg)!;
    expect(box[1], box[2]);
    // A valid QR size (21 + 4k modules) + 2 × 4 quiet zone.
    expect((int.parse(box[1]!) - 8 - 21) % 4, 0);
    // Top-left finder pattern starts right after the quiet zone.
    expect(svg, contains('M4 4h1v1h-1z'));
    expect(svg, isNot(contains('M3 3h1')));
  });

  test('print sheet escapes names and has one card per sign', () {
    final html = qrPrintHtml(
      eventName: 'A & <B>',
      cards: [
        (title: '<script>', subtitle: '', link: 'https://x/e/1?at=a'),
        (title: 'Ulaz', subtitle: 'Prizemlje', link: 'https://x/e/1?at=b'),
      ],
      texts: (
        lang: 'sr',
        pageTitle: 'QR',
        youAreHere: 'Vi ste ovde',
        instructions: 'Skenirajte',
        printButton: 'Štampaj',
      ),
    );
    expect(RegExp('<section class="card">').allMatches(html), hasLength(2));
    expect(html, contains('&lt;script&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('A &amp; &lt;B&gt;'));
    expect(html, contains('<p class="sub">Prizemlje</p>'));
    expect(RegExp('<svg').allMatches(html), hasLength(2));
  });

  testWidgets('lists markers by floor and prints them', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    printed = null;
    await tester.pumpWidget(
      _app(
        published: 3,
        features: [
          _marker('m2', 'f2', 'Lift (QR)'),
          _marker('m1', 'f1', 'Ulaz (QR)'),
          {..._marker('s1', 'f1', 'Štand'), 'type': 'stand'},
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QR oznake · Test <Expo>'), findsOneWidget);
    expect(find.byType(QrImageView), findsNWidgets(2));
    expect(find.text('Štand'), findsNothing);
    // Ground floor first.
    expect(
      tester.getTopLeft(find.text('Ulaz (QR)')).dx,
      lessThan(tester.getTopLeft(find.text('Lift (QR)')).dx),
    );
    expect(find.text('https://eho.example/e/e?at=m1'), findsOneWidget);
    expect(find.text('Sprat 1'), findsOneWidget);
    expect(find.textContaining('nije objavljen'), findsNothing);

    await tester.tap(find.text('Štampaj'));
    await tester.pump();
    expect(printed, contains('https://eho.example/e/e?at=m2'));
    expect(printed, contains('Test &lt;Expo&gt;'));
    expect(printed!.indexOf('Ulaz (QR)'), lessThan(printed!.indexOf('Lift')));
  });

  testWidgets('unpublished event without markers explains what to do', (
    tester,
  ) async {
    await tester.pumpWidget(_app(published: 0, features: []));
    await tester.pumpAndSettle();
    expect(find.textContaining('nije objavljen'), findsOneWidget);
    expect(find.textContaining('Još nema QR oznaka'), findsOneWidget);
    expect(find.text('Štampaj'), findsNothing);
  });
}
