import 'package:eho/app.dart';
import 'package:eho/features/dev/dev_shot_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every `/dev/shot/<state>` route builds without exceptions and shows its
/// key text (see `features/dev/dev_shot_routes.dart`).
void main() {
  // State name -> text that must be on screen.
  const expected = <String, String>{
    'echo-qa': 'Questions for Mara',
    'echo-paywall': 'Missed something? Get the whole talk in 2 minutes.',
    'echo-summary': 'AI SUMMARY · PREMIUM',
    'echo-translated': 'Translated live from English · tap SR for the original',
    'echo-ended': 'Premium · AI summary of the whole talk',
    'echo-ended-unlocked': 'Unlocked',
    'person-none': 'Send contact request',
    'person-pending': 'Request sent · waiting for Ana',
    'person-connected': 'Ana accepted · Message',
    'messages-spot': 'Ana Petrović',
    'find-results': 'Results for "On-device ML on Android"',
    'myevents-live': 'LIVE NOW',
    'organizer-review': 'Review your event',
    'organizer-published': 'PUBLISHED',
  };

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: EhoApp(
          router: GoRouter(initialLocation: location, routes: devShotRoutes()),
        ),
      ),
    );
    // Echo transcripts and sheets open on timers; let them run.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  test('every state has a test expectation', () {
    expect(devShots.map((s) => s.name).toSet(), expected.keys.toSet());
  });

  for (final e in expected.entries) {
    testWidgets('/dev/shot/${e.key} builds', (tester) async {
      await open(tester, '/dev/shot/${e.key}');
      expect(tester.takeException(), isNull);
      expect(find.textContaining(e.value), findsWidgets);
    });
  }

  testWidgets('/dev/shot lists every state as a link', (tester) async {
    await open(tester, '/dev/shot');
    for (final s in devShots) {
      expect(find.text('/dev/shot/${s.name}'), findsOneWidget);
    }
    await tester.tap(find.text('/dev/shot/person-none'));
    await tester.pumpAndSettle();
    expect(find.text('Send contact request'), findsOneWidget);
  });

  testWidgets('unknown state shows the index', (tester) async {
    await open(tester, '/dev/shot/nope');
    expect(find.text('Unknown state "nope".'), findsOneWidget);
    expect(find.text('/dev/shot/echo-qa'), findsOneWidget);
  });
}
