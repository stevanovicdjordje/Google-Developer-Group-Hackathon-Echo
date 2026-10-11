import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flow_helpers.dart';

/// Flow 1: scanned venue QR → join → onboarding → event → agenda → session.
void main() {
  testWidgets('deep link with ?at= → join → onboarding → agenda → session', (
    tester,
  ) async {
    await startApp(tester);
    expect(find.text('Join with a link or code'), findsOneWidget);

    // Deep link / QR with a venue marker.
    await openLink(tester, '/e/devfest?at=m1');
    expect(find.text('DevFest Belgrade 2026'), findsOneWidget);
    expect(find.text('Join event'), findsOneWidget);
    expect(find.text('Agenda for every stage'), findsOneWidget);

    // Join → step 1 (name).
    await tester.tap(find.text('Join event'));
    await tester.pumpAndSettle();
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Ilija');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2 (interests).
    expect(find.text('What are you into?'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.text('AI / ML'));
    await tester.tap(find.text('Mobile'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3 (consents).
    expect(find.text('You decide what others see'), findsOneWidget);
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('Show me in Find'), findsOneWidget);
    expect(find.text('Allow contact requests'), findsOneWidget);
    expect(find.text('Allow meeting spots'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // The marker survives onboarding: lands on the map with `at`.
    expect(locationOf(tester), '/e/devfest/map?at=m1');

    // Agenda tab lists the sessions.
    await tapTab(tester, 'Agenda');
    expect(locationOf(tester), '/e/devfest/agenda');
    expect(find.text('All stages'), findsOneWidget);
    expect(find.text('DevFest Belgrade 2026 · Day 1'), findsOneWidget);
    expect(
      find.text('On-device AI: when the model lives in your pocket'),
      findsOneWidget,
    );
    expect(
      find.text('Scaling event-driven backends on a startup budget'),
      findsOneWidget,
    );

    // Open session s1.
    await tester.tap(
      find.text('On-device AI: when the model lives in your pocket'),
    );
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/e/devfest/session/s1');
    expect(find.text('Open Echo'), findsOneWidget);
    expect(find.text('Mara Ilić'), findsWidgets);
  });
}
