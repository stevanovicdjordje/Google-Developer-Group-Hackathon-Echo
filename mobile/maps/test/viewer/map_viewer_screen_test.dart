import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Widget app(FakeRepository repo, {String? featureId}) => ProviderScope(
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
    home: MapViewerScreen(eventId: 'e', initialFeatureId: featureId),
  ),
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

  testWidgets('shows loading, then the published map; search opens details', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    await tester.pump();
    expect(find.text('Učitavam plan…'), findsOneWidget);

    repo.controller.add(
      PublishedEvent(id: 'e', name: 'Eho Demo Expo', map: demoMap),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eho Demo Expo'), findsOneWidget);
    expect(find.text('Glavna sala'), findsOneWidget); // room label
    expect(find.text('Sprat 1'), findsOneWidget); // floor switcher

    await tester.enterText(find.byType(TextField), 'cacak');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Čačak Dev'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Neuro Lab'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Čačak Dev'));
    await tester.pumpAndSettle();
    expect(
      find.text('Kompanija: '),
      findsNothing,
    ); // label and value are one rich text
    expect(find.textContaining('Primer Čačak'), findsWidgets);
    expect(find.text('Štand'), findsWidgets);
  });

  testWidgets('search on another floor switches floor; no results message', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: demoMap));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nepostojece');
    await tester.pumpAndSettle();
    expect(find.text('Nema rezultata za „nepostojece“'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kvant');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Kvant'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sprat: Sprat 1'),
      findsOneWidget,
    ); // floor chip in the sheet
  });

  testWidgets('deep link to a stand opens its details', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo, featureId: 's2'));
    repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: demoMap));
    await tester.pumpAndSettle();
    expect(find.text('Zlatni sponzor'), findsOneWidget);
    expect(find.textContaining('Primer AI d.o.o.'), findsWidgets);
  });

  testWidgets('realtime update replaces the map without reload', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: demoMap));
    await tester.pumpAndSettle();
    expect(find.text('Glavna sala'), findsOneWidget);

    final renamed = VenueMap(
      floors: demoMap.floors,
      graphs: const [],
      features: [
        for (final f in demoMap.features)
          f.id == 'hall'
              ? Feature(
                  id: f.id,
                  type: f.type,
                  floorId: f.floorId,
                  name: 'Velika sala',
                  geometry: f.geometry,
                )
              : f,
      ],
    );
    repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: renamed));
    await tester.pumpAndSettle();
    expect(find.text('Velika sala'), findsOneWidget);
    expect(find.text('Glavna sala'), findsNothing);
  });

  testWidgets('errors show a message; offline offers retry', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    repo.controller.addError(const MapUnavailable());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Server trenutno nije dostupan'),
      findsOneWidget,
    );
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });

  testWidgets('quick chips: floors and Sponsors under the search bar', (
    tester,
  ) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    await tester.pump();
    repo.controller.add(
      PublishedEvent(id: 'e', name: 'Eho Demo Expo', map: demoMap),
    );
    await tester.pumpAndSettle();

    // No food POI in the fixture, so no Food chip.
    expect(find.widgetWithText(ChoiceChip, 'Prizemlje'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Sponzori'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Hrana'), findsNothing);

    // The test font makes chips wide; tap the chip's visible left part.
    final sponsors = find.widgetWithText(ChoiceChip, 'Sponzori');
    await tester.tapAt(tester.getTopLeft(sponsors) + const Offset(16, 16));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Neuro Lab'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Čačak Dev'), findsNothing);

    // Closing goes back to the plain map with the chips.
    await tester.tap(find.byTooltip('Obriši pretragu'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Sponzori'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sprat 1'));
    await tester.pumpAndSettle();
    expect(find.text('Glavna sala'), findsNothing); // ground-floor room
  });

  testWidgets('a missing event explains what to do', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    repo.controller.addError(const EventNotFound());
    await tester.pumpAndSettle();
    expect(
      find.text('Događaj nije pronađen ili još nije objavljen.'),
      findsOneWidget,
    );
    expect(find.textContaining('Proverite link ili QR kod'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });
}
