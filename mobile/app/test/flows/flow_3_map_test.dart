import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/models.dart';
import 'package:eho/features/map/map_feature_sheet.dart';
import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flow_helpers.dart';

/// Flow 3: the Map tab. The live venue map (`eho_maps`) needs Firebase and
/// network, so it is NOT loaded here: nothing taps a pin or checks the route
/// line / "you are here" marker. What is covered: the stage sheet inside the
/// real router (Open Echo, Start route) and Messages "Show on map" landing on
/// the Map tab with the meeting-spot banner.
void main() {
  const room = Feature(
    id: 'f1',
    type: FeatureType.room,
    floorId: 'fl1',
    name: 'Glavna sala',
    description: 'Keynotes and panels',
    capacity: 400,
    geometry: Geometry(GeometryKind.rect, [PlanPoint(0, 0), PlanPoint(10, 10)]),
  );

  testWidgets('stage sheet (as the map opens it) → Open Echo → Echo screen', (
    tester,
  ) async {
    await startApp(tester);
    await openLink(tester, '/e/devfest');
    await joinAndOnboard(tester);
    await tapTab(tester, 'Agenda');

    // What the map does when a stage is selected: show the app's own sheet.
    final context = tester.element(find.byType(Scaffold).first);
    var routeStarted = false;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => MapStageSheet(
        feature: room,
        floorName: 'Ground floor',
        session: demo.sessions.firstWhere((s) => s.isLive),
        onStartRoute: () => routeStarted = true,
        onOpenEcho: () {
          Navigator.pop(sheet);
          routerOf(tester).push('/e/devfest/session/s1/echo');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Glavna sala'), findsWidgets);
    expect(
      find.text('Keynotes and panels · up to 400 seats · Ground floor'),
      findsOneWidget,
    );
    expect(find.text('NOW · 10:00–10:45'), findsOneWidget);
    expect(
      find.text('On-device AI: when the model lives in your pocket'),
      findsWidgets,
    );

    await tester.tap(find.text('Start route'));
    expect(routeStarted, isTrue);

    await tester.tap(find.text('Open Echo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(locationOf(tester), '/e/devfest/session/s1/echo');
    expect(find.text('Ask AI'), findsOneWidget);
    await drainEcho(tester);
  });

  testWidgets('Messages "Show on map" → /map?spot=1 → Map tab', (tester) async {
    final container = await startApp(tester);
    await openLink(tester, '/e/devfest');
    await joinAndOnboard(tester);

    // A meeting spot agreed with Ana (see the Find flow for how).
    container
        .read(meetingSpotProvider.notifier)
        .agree(
          'devfest',
          const MeetingSpot(
            personName: 'Ana Petrović',
            place: 'Glavna sala',
            time: '15:20',
            floor: 'Ground floor',
            personId: 'p1',
          ),
        );
    await openLink(tester, '/e/devfest/messages/p1');
    expect(find.text('Meet at Glavna sala'), findsOneWidget);
    expect(find.text('15:20 · Ground floor'), findsOneWidget);

    await tester.tap(find.text('Show on map'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/e/devfest/map?spot=1');
    // The Map tab is the selected destination of the bottom navigation.
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.selectedIndex, 1);
    // The meeting-spot banner under the map.
    expect(find.text('Meeting Ana Petrović'), findsOneWidget);
    expect(find.text('at Glavna sala'), findsOneWidget);
  });
}
