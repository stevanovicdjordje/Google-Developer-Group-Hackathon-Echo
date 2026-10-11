import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flow_helpers.dart';

/// Flow 4: Find → recommendations → AI search → person → contact request
/// (demo auto-accept after 2 s) → Messages → meeting spot.
void main() {
  testWidgets('Find → search → person → request → Messages → meeting spot', (
    tester,
  ) async {
    await startApp(tester, mapStaysLoading: true);
    await openLink(tester, '/e/devfest');
    await joinAndOnboard(tester);

    // Find tab: three recommendation cards.
    await tapTab(tester, 'Find');
    expect(locationOf(tester), '/e/devfest/find');
    expect(find.text('Find people'), findsOneWidget);
    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Ana Petrović'), findsOneWidget);
    expect(find.text('Teodora Nikolić'), findsOneWidget);
    expect(find.text('Nina Popović'), findsOneWidget);
    expect(find.text('Katarina Božić'), findsNothing);

    // The canned prompt: results include the keynote speaker.
    await tester.enterText(find.byType(TextField), 'On-device ML on Android');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('people here fit'), findsOneWidget);
    expect(find.text('Ana Petrović'), findsOneWidget);
    expect(find.text('Katarina Božić'), findsOneWidget);
    expect(find.text('Mara Ilić'), findsOneWidget);
    expect(find.text('Recommended for you'), findsNothing);

    // Open a person: full screen, "Why you should meet", Send request.
    await tester.tap(find.text('Ana Petrović'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), startsWith('/e/devfest/find/person/p1'));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Android dev at Fintio'), findsWidgets);
    expect(find.text('Why you should meet'), findsOneWidget);
    await tester.tap(find.text('Send contact request'));
    // The demo "thinks" for 500 ms, then the request is pending.
    await tester.pump(const Duration(milliseconds: 600));

    // Pending, then the demo auto-accepts after 2 s.
    expect(find.text('Request sent · waiting for Ana'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Ana accepted · Message'), findsOneWidget);

    // Message → Messages screen with the system pill.
    await tester.tap(find.text('Ana accepted · Message'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/e/devfest/messages/p1');
    expect(find.text('Ana accepted your contact request'), findsOneWidget);
    expect(find.textContaining('Saw your request'), findsOneWidget);
    expect(find.text('Meet at Info pult'), findsNothing);

    // Agree a meeting spot: the card shows place and time/floor.
    await tester.tap(find.byTooltip('Suggest a meeting spot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info pult'));
    await tester.pumpAndSettle();
    expect(find.text('Meet at Info pult'), findsOneWidget);
    expect(find.text('15:20 · Ground floor'), findsOneWidget);
    expect(find.text('Show on map'), findsOneWidget);

    // Let the 2 s recommendation debounce timer finish.
    await tester.pump(const Duration(seconds: 3));
  });
}
