import 'package:eho/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Event tabs keep their state when switching (StatefulShellRoute), and the
/// event deep links still open the right screens. The Map tab is not opened
/// because it needs the emulators.
void main() {
  Future<void> start(WidgetTester tester, {double height = 2400}) async {
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
  }

  void go(WidgetTester tester, String location) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollableState agendaList(WidgetTester tester) => tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.position.axis == Axis.vertical);

  testWidgets('switching tabs keeps agenda scroll, Find query and pages', (
    tester,
  ) async {
    // Short screen so the agenda scrolls.
    await start(tester, height: 1200);
    go(tester, '/e/devfest/agenda');
    await tester.pumpAndSettle();
    expect(find.text('All stages'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    final offset = agendaList(tester).position.pixels;
    expect(offset, greaterThan(0));

    // Find: run a search.
    await tapTab(tester, 'Find');
    expect(find.text('Recommended for you'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'android');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('people here fit'), findsOneWidget);

    // Back to Agenda: same scroll position.
    await tapTab(tester, 'Agenda');
    expect(agendaList(tester).position.pixels, offset);

    // Back to Find: same query and results.
    await tapTab(tester, 'Find');
    expect(find.textContaining('people here fit'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'android'), findsOneWidget);

    // Open a person: full screen (no bottom navigation, like the design).
    await tester.tap(find.text('Ana Petrović').first);
    await tester.pumpAndSettle();
    expect(find.text('Android dev at Fintio'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);

    // Back: the results are still there, with the navigation.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('people here fit'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tapping the active tab goes to its root, results still there.
    await tapTab(tester, 'Find');
    expect(find.textContaining('people here fit'), findsOneWidget);
  });

  testWidgets('event deep links open the right screens', (tester) async {
    await start(tester);

    go(tester, '/e/devfest/agenda');
    await tester.pumpAndSettle();
    expect(find.text('All stages'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    go(tester, '/e/devfest/find');
    await tester.pumpAndSettle();
    expect(find.text('Find people'), findsOneWidget);

    go(tester, '/e/devfest/find/person/p2');
    await tester.pumpAndSettle();
    expect(find.text('Founder, ParkIt'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);

    go(tester, '/e/devfest/profile');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    go(tester, '/e/devfest/session/s1');
    await tester.pumpAndSettle();
    expect(find.text('Open Echo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Not joined yet: `/e/{id}` shows the join screen.
    go(tester, '/e/devfest');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Join event'), findsOneWidget);

    go(tester, '/e/devfest/session/s1/echo');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ask AI'), findsOneWidget);
    // Let the demo transcript replay finish (no pending timers).
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
  });

  testWidgets('Android back on Find / Profile goes to Agenda, then exits', (
    tester,
  ) async {
    await start(tester);
    go(tester, '/e/devfest/find');
    await tester.pumpAndSettle();
    expect(find.text('Find people'), findsOneWidget);

    // Cold stack: back goes to the Agenda tab of the same event.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('All stages'), findsOneWidget);
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.selectedIndex, 0);

    go(tester, '/e/devfest/profile');
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('All stages'), findsOneWidget);

    // On the Agenda root back is not handled: the app would close.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('organizer sheet covers the bottom navigation', (tester) async {
    await start(tester);
    go(tester, '/e/devfest/profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('For organizers'));
    await tester.pumpAndSettle();
    expect(find.text('Create event'), findsOneWidget);

    // The sheet lives in the root overlay above the shell: the nav sits
    // under it and under the scrim, so no nav item can be tapped.
    final nav = find.byType(NavigationBar);
    expect(nav.hitTestable(), findsNothing);
    expect(find.text('Find').hitTestable(), findsNothing);

    // Tapping the scrim closes the sheet; the tab stays on Profile.
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(find.text('Create event'), findsNothing);
    expect(tester.widget<NavigationBar>(nav).selectedIndex, 3);
  });
}
