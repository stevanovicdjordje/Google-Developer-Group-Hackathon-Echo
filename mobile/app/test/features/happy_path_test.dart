import 'package:eho/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Walks the attendee happy path on demo data (no Firebase; the Map tab is
/// not opened because it needs the emulators).
void main() {
  testWidgets('deep link → join → onboarding → agenda → Echo → Find', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final app = EhoApp();
    await tester.pumpWidget(ProviderScope(child: app));
    await tester.pumpAndSettle();
    expect(find.text('Join with a link or code'), findsOneWidget);

    // Deep link
    GoRouter.of(tester.element(find.text('Eho'))).go('/e/devsummit');
    await tester.pumpAndSettle();
    expect(find.text('DevSummit Belgrade 2026'), findsOneWidget);

    // Join → onboarding (3 steps)
    await tester.tap(find.text('Join event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ilija');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI / ML'));
    await tester.tap(find.text('Mobile'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Agenda → session → Echo
    expect(find.text('All stages'), findsOneWidget);
    await tester.tap(
      find.text('On-device AI: when the model lives in your pocket'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Echo: live transcript & AI'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.textContaining('Good morning'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'what about battery?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('12% battery'), findsOneWidget);
    // Let the transcript replay finish.
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(find.text('Full talk summary'), findsOneWidget);

    // Back to the tabs → Find
    GoRouter.of(tester.element(find.text('Full talk summary'))).go(
      '/e/devsummit/find',
    );
    await tester.pumpAndSettle();
    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Ana Petrović'), findsOneWidget);
  });
}
