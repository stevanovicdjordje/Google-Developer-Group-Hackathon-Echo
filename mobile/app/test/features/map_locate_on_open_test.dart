import 'dart:async';

import 'package:eho/features/map/map_tab.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// North-up plan, 0.05 m/px, origin at (44.8, 20.4): 1200 x 800 px.
ControlPoint _cp(double x, double y) => ControlPoint(
  px: PlanPoint(x, y),
  latLng: LatLngDeg(44.8 - y * 0.05 / 111320.0, 20.4 + x * 0.05 / 79000.0),
);

final _map = VenueMap(
  version: 1,
  floors: [
    Floor(
      id: 'f1',
      name: 'Ground',
      order: 0,
      imagePath: 'events/e/floors/p.png',
      width: 1200,
      height: 800,
      georef: Georeference(
        controlPoints: [_cp(0, 0), _cp(1200, 0), _cp(0, 800)],
        metersPerPixel: 0.05,
      ),
    ),
  ],
  features: const [],
  graphs: const [],
);

class _Repo implements PublishedMapRepository {
  final controller = StreamController<PublishedEvent>.broadcast();

  @override
  Stream<PublishedEvent> watch(String eventId) => controller.stream;

  @override
  Future<String> imageUrl(String path) =>
      Future.error(StateError('no images in tests'));
}

/// Quiet source; [allowed] false = it would need a permission prompt.
class _Quiet implements QuietLocationSource {
  _Quiet({this.allowed = true});

  final bool allowed;
  int watching = 0;

  @override
  Future<bool> allowedWithoutPrompt() async => allowed;

  @override
  Stream<GpsFix> watch() {
    watching++;
    return Stream.value(GpsFix(const LatLngDeg(44.79982, 20.400025), 5));
  }
}

/// Can't say whether it would prompt, so the map must leave it alone.
class _Plain implements LocationSource {
  int watching = 0;

  @override
  Stream<GpsFix> watch() {
    watching++;
    return const Stream.empty();
  }
}

Future<void> _open(WidgetTester tester, LocationSource source) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  addTearDown(repo.controller.close);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: MapTab(eventId: 'e')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapsSignedInProvider.overrideWith((ref) async => 'test-uid'),
        publishedMapRepositoryProvider.overrideWithValue(repo),
        locationSourceProvider.overrideWithValue(source),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          MapsLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pump();
  repo.controller.add(PublishedEvent(id: 'e', name: 'Expo', map: _map));
  await tester.pumpAndSettle();
}

void main() {
  final hereMarker = find.byKey(const ValueKey('you-are-here'));

  testWidgets('Map tab shows you-are-here on open, without a tap', (
    tester,
  ) async {
    final source = _Quiet();
    await _open(tester, source);
    expect(source.watching, 1);
    expect(hereMarker, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a quiet source that would need a prompt stays idle', (
    tester,
  ) async {
    final source = _Quiet(allowed: false);
    await _open(tester, source);
    expect(source.watching, 0);
    expect(hereMarker, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a non-quiet source is never started', (tester) async {
    final source = _Plain();
    await _open(tester, source);
    expect(source.watching, 0);
    expect(hereMarker, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('DemoLocationSource at the venue shows the dot on open', (
    tester,
  ) async {
    await _open(tester, DemoLocationSource.parse('44.799820,20.400025')!);
    expect(hereMarker, findsOneWidget);
  });
}
