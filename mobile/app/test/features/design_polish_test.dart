import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/models.dart';
import 'package:eho_maps/eho_maps.dart' show MapViewerScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _event = EventSummary(
  id: 'devfest',
  name: 'DevFest Belgrade 2026',
  dates: 'Oct 11–12, 2026',
  venue: 'Sava Centar, Belgrade',
);

/// Demo repositories answer after short timers, which `pumpAndSettle` alone
/// does not wait for.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

/// Copy and links the design pass added: live flag, Find chips and captions,
/// contact notes, Messages system pill and "Show on map".
void main() {
  testWidgets('agenda marks the live talk, Find tags the top match', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(joinedEventsProvider.notifier).add(_event);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    router.go('/events');
    await settle(tester);
    expect(find.text('LIVE · DAY 1'), findsOneWidget);
    expect(find.textContaining('Next: On-device AI'), findsOneWidget);

    router.go('/e/devfest/agenda');
    await settle(tester);
    expect(find.text('LIVE NOW · ECHO ON'), findsOneWidget);

    router.go('/e/devfest/find');
    await settle(tester);
    expect(find.text('from your interests'), findsOneWidget);
    expect(find.text('Top match'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'android');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    // No extra heading; the caption counts the results.
    expect(find.textContaining('Results for'), findsNothing);
    expect(
      find.text('3 people here fit · only people who opted in'),
      findsOneWidget,
    );
    // A speaker shows up with their role, and the reason is hand-written.
    expect(find.text('Speaker · ML Engineer, Lumen Labs'), findsOneWidget);
    expect(find.textContaining('looking for:'), findsNothing);
    expect(find.text('Top match'), findsNothing);
  });

  testWidgets('contact notes, Messages pill and Show on map', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(joinedEventsProvider.notifier).add(_event);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    router.go('/e/devfest/find/person/p3');
    await settle(tester);
    // A deep link has no `?why=`; the reason comes from the recommendations.
    expect(find.text('Why you should meet'), findsOneWidget);
    expect(
      find.text('Your details are shared only after Teodora accepts.'),
      findsOneWidget,
    );
    container.read(contactsProvider.notifier).set('p3', ContactState.requested);
    await tester.pumpAndSettle();
    expect(find.text('Request sent · waiting for Teodora'), findsOneWidget);

    container.read(contactsProvider.notifier).set('p3', ContactState.accepted);
    await tester.pumpAndSettle();
    expect(find.text('Teodora accepted · Message'), findsOneWidget);
    // The privacy note stays in every state, like the design.
    expect(
      find.text('Your details are shared only after Teodora accepts.'),
      findsOneWidget,
    );

    container.read(contactsProvider.notifier).set('p3', ContactState.accepted);
    container
        .read(meetingSpotProvider.notifier)
        .set(const MeetingSpot(personName: 'Teodora Nikolić', place: 'Sala A'));
    router.go('/e/devfest/messages/p3');
    await settle(tester);
    expect(find.text('Teodora accepted your contact request'), findsOneWidget);
    expect(find.text('Meet at Sala A'), findsOneWidget);
    // Time from the conversation, floor of the demo place (map not loaded).
    expect(find.text('15:20 · Ground floor'), findsOneWidget);

    await tester.tap(find.text('Show on map'));
    await settle(tester);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/e/devfest/map?spot=1',
    );
    expect(find.byType(MapViewerScreen), findsOneWidget);
  });
}
