import 'package:eho/data/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flow_helpers.dart';

/// Flow 2: Echo on the live keynote (transcript, ask, translate, Q&A), then
/// the talk ends → paywall → unlock → summary. Demo data, no Firebase.
void main() {
  testWidgets('session → Echo → ask, translate, Q&A → paywall → summary', (
    tester,
  ) async {
    final container = await startApp(tester);
    await openLink(tester, '/e/devfest');
    await joinAndOnboard(tester);
    await tapTab(tester, 'Agenda');
    await tester.tap(
      find.text('On-device AI: when the model lives in your pocket'),
    );
    await tester.pumpAndSettle();

    // Session s1 → Echo.
    await tester.tap(find.text('Open Echo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(locationOf(tester), '/e/devfest/session/s1/echo');
    expect(find.text('Ask AI'), findsOneWidget);
    // The demo transcript streams in line by line.
    expect(find.textContaining('Good morning everyone'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('Three years ago'), findsOneWidget);

    // Long-press a line → "Ask about this" pre-fills the question.
    await tester.longPress(find.textContaining('Good morning everyone'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ask about this'), findsOneWidget);
    await tester.tap(find.text('Ask about this'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      contains('Good morning everyone'),
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    // The answer card appears (the demo's default answer for this line).
    expect(find.textContaining('Based on the talk so far'), findsOneWidget);

    // Ask a typed question → the canned battery answer.
    await tester.enterText(find.byType(TextField), 'what about battery?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('12% battery'), findsOneWidget);

    // Translate to Serbian: banner, SR pill and Serbian placeholder.
    await tester.tap(find.byTooltip('Translate to Serbian'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Translated live from English · tap SR for the original'),
      findsOneWidget,
    );
    expect(find.text('SR'), findsWidgets);
    expect(find.text('Pitajte bilo šta o predavanju…'), findsOneWidget);
    expect(find.textContaining('Vaš granični trošak'), findsOneWidget);
    await tester.tap(find.byTooltip('Show original'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Translated live from English · tap SR for the original'),
      findsNothing,
    );

    // Q&A sheet: vote, then ask the speaker.
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Questions for Mara'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    await tester.tap(find.text('14'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('15'), findsOneWidget);
    expect(find.text('14'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ask Mara a question…'),
      'Will the slides be shared?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Will the slides be shared?'), findsOneWidget);
    expect(
      find.text('13 questions · shown to the speaker at the end'),
      findsOneWidget,
    );

    // Close the sheet, let the replay run to the end.
    await tester.tapAt(const Offset(200, 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();

    // The talk ended: the paywall opens by itself (or via the summary card).
    if (find.text('Unlock summary').evaluate().isEmpty) {
      await tester.tap(find.text('Full talk summary'));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Missed something? Get the whole talk in 2 minutes.'),
      findsOneWidget,
    );
    expect(container.read(unlockedSummariesProvider), isEmpty);
    await tester.tap(find.text('Unlock summary'));
    await tester.pumpAndSettle();
    expect(container.read(unlockedSummariesProvider), {'s1'});

    // Summary page: takeaway and key points.
    expect(find.text('AI SUMMARY · PREMIUM'), findsOneWidget);
    expect(find.text('TAKEAWAY'), findsOneWidget);
    expect(
      find.text(
        'Start hybrid, measure, and move work to the device over time.',
      ),
      findsOneWidget,
    );
    expect(find.text('Key points'), findsOneWidget);
    expect(find.text('Trade-offs and fixes'), findsOneWidget);
    expect(find.text('Battery'), findsOneWidget);
  });
}
