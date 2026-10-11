import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/features/map/map_feature_sheet.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _room = Feature(
  id: 'f1',
  type: FeatureType.room,
  floorId: 'fl1',
  name: 'Glavna sala',
  description: 'Keynotes and panels',
  capacity: 400,
  geometry: Geometry(GeometryKind.rect, [PlanPoint(0, 0), PlanPoint(10, 10)]),
);

const _route = MapRoute(
  publishedVersion: 1,
  legs: [
    RouteLeg(floorId: 'fl1', points: [PlanPoint(0, 0), PlanPoint(5, 5)]),
  ],
  distanceMeters: 118.4,
  durationSeconds: 95,
  distanceEstimated: true,
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('sessionForStage', () {
    test('live session wins, even before "now"', () {
      final s = sessionForStage(demo.sessions, 'Glavna sala', '23:00');
      expect(s?.id, demo.keynoteId);
    });

    test('else the next one after now, skipping breaks', () {
      // Sala A: 11:00 (not live) and 13:30; none is live.
      expect(sessionForStage(demo.sessions, 'Sala A', '11:30')?.id, 's5');
      expect(sessionForStage(demo.sessions, 'Sala A', '08:00')?.id, 's2');
    });

    test('null when nothing is left', () {
      expect(sessionForStage(demo.sessions, 'Sala A', '23:00'), isNull);
      expect(sessionForStage(demo.sessions, 'Nowhere', '08:00'), isNull);
    });
  });

  group('MapStageSheet', () {
    testWidgets('live session: capacity, walk, NOW row, both actions', (
      tester,
    ) async {
      final calls = <String>[];
      final live = demo.sessions.firstWhere((s) => s.isLive);
      await tester.pumpWidget(
        _app(
          MapStageSheet(
            feature: _room,
            floorName: 'Ground floor',
            route: _route,
            session: live,
            onStartRoute: () => calls.add('route'),
            onOpenSession: () => calls.add('session'),
            onOpenEcho: () => calls.add('echo'),
          ),
        ),
      );
      expect(find.text('Glavna sala'), findsOneWidget);
      expect(
        find.text('Keynotes and panels · up to 400 seats · Ground floor'),
        findsOneWidget,
      );
      expect(find.text('2 min'), findsOneWidget);
      expect(find.text('~118 m walk'), findsOneWidget);
      expect(find.text('NOW · 10:00–10:45'), findsOneWidget);
      expect(find.text(live.title), findsOneWidget);

      await tester.tap(find.text(live.title));
      await tester.tap(find.text('Start route'));
      await tester.tap(find.text('Open Echo'));
      expect(calls, ['session', 'route', 'echo']);
    });

    testWidgets('next session: no Echo button, "Next" label', (tester) async {
      final next = demo.sessions.firstWhere((s) => s.id == 's5');
      await tester.pumpWidget(
        _app(
          MapStageSheet(
            feature: _room,
            session: next,
            onStartRoute: () {},
            onOpenSession: () {},
          ),
        ),
      );
      expect(find.text('NEXT · ${next.start}'), findsOneWidget);
      expect(find.text('Open Echo'), findsNothing);
      expect(find.text('Start route'), findsOneWidget);
    });

    testWidgets('loading route shows a spinner, no start yet shows no walk', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          MapStageSheet(
            feature: _room,
            routeLoading: true,
            onStartRoute: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(
        _app(MapStageSheet(feature: _room, onStartRoute: () {})),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('walk'), findsNothing);
    });

    testWidgets('no capacity on the feature: the row is omitted', (
      tester,
    ) async {
      const noCap = Feature(
        id: 'f2',
        type: FeatureType.room,
        floorId: 'fl1',
        name: 'Sala A',
        geometry: Geometry(GeometryKind.point, [PlanPoint(1, 1)]),
      );
      await tester.pumpWidget(_app(const MapStageSheet(feature: noCap)));
      expect(find.textContaining('seats'), findsNothing);
    });
  });

  group('buildStageSheet', () {
    testWidgets('null for features that are not a stage of the event', (
      tester,
    ) async {
      const other = Feature(
        id: 'p1',
        type: FeatureType.poi,
        floorId: 'fl1',
        name: 'Info pult',
        geometry: Geometry(GeometryKind.point, [PlanPoint(1, 1)]),
      );
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              expect(
                buildStageSheet(
                  context,
                  eventId: 'devfest',
                  sessions: demo.sessions,
                  data: MapFeatureSheetData(feature: other),
                ),
                isNull,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('a stage gets the designed sheet', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheet) =>
                        buildStageSheet(
                          sheet,
                          eventId: 'devfest',
                          sessions: demo.sessions,
                          data: const MapFeatureSheetData(feature: _room),
                        ) ??
                        const SizedBox(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/e/:eventId/session/:sessionId',
            builder: (_, s) => Text('session ${s.pathParameters['sessionId']}'),
            routes: [
              GoRoute(
                path: 'echo',
                builder: (_, s) =>
                    Text('echo ${s.pathParameters['sessionId']}'),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(MapStageSheet), findsOneWidget);
      // The demo keynote is live in Glavna sala: its session and Echo are offered.
      expect(find.text('Open Echo'), findsOneWidget);
      await tester.tap(find.text('Open Echo'));
      await tester.pumpAndSettle();
      expect(find.text('echo s1'), findsOneWidget);
      expect(find.byType(MapStageSheet), findsNothing);
    });
  });
}
