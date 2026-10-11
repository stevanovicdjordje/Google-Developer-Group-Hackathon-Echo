import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Publishing with rows still flagged (server issue, or no room) asks first;
/// with nothing flagged it publishes straight away.
void main() {
  const publish = 'Publish & get join link';

  EventDraft draft({
    List<Session>? sessions,
    List<DraftIssue> issues = const [],
  }) => EventDraft(
    name: demo.demoEventName,
    dates: demo.demoEventDates,
    venue: demo.demoEventVenue,
    stages: demo.stages,
    sessions: sessions ?? demo.sessions.where((s) => !s.isBreak).toList(),
    speakers: demo.speakers,
    issues: issues,
  );

  Session noRoom(Session s) => Session(
    id: s.id,
    title: s.title,
    stage: '',
    start: s.start,
    end: s.end,
    speakers: s.speakers,
  );

  Future<void> open(WidgetTester tester, EventDraft d) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(organizerDraftProvider.notifier).set(d);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: EhoApp()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Eho'))).go('/organizer/review');
    await tester.pumpAndSettle();
  }

  Future<void> tapPublish(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text(publish),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(publish));
    await tester.pump();
  }

  testWidgets('flagged rows: dialog; Review keeps us on the screen', (
    tester,
  ) async {
    final sessions = demo.sessions.where((s) => !s.isBreak).toList();
    await open(
      tester,
      draft(
        sessions: [noRoom(sessions[0]), ...sessions.skip(1)],
        issues: const [
          DraftIssue(
            field: 'startDate',
            message: 'The event has no start date.',
          ),
        ],
      ),
    );
    await tapPublish(tester);
    await tester.pumpAndSettle();

    // One row without a room + one general issue.
    expect(find.text('2 sessions still need a check'), findsOneWidget);
    expect(find.text('Publish anyway'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('2 sessions still need a check'), findsNothing);
    expect(find.text('Review your event'), findsOneWidget);
    expect(find.text(publish), findsOneWidget);
  });

  testWidgets('flagged row: Publish anyway publishes', (tester) async {
    final sessions = demo.sessions.where((s) => !s.isBreak).toList();
    await open(
      tester,
      draft(sessions: [noRoom(sessions[0]), ...sessions.skip(1)]),
    );
    await tapPublish(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 session still needs a check'), findsOneWidget);

    await tester.tap(find.text('Publish anyway'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('${demo.demoEventName} is live'), findsOneWidget);
  });

  testWidgets('a server issue on a row counts as flagged', (tester) async {
    final sessions = demo.sessions.where((s) => !s.isBreak).toList();
    await open(
      tester,
      draft(
        sessions: sessions,
        issues: [
          DraftIssue(
            sessionId: sessions[1].id,
            field: 'sessions[1].end',
            message: 'Overlaps another session on this stage.',
          ),
        ],
      ),
    );
    await tapPublish(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 session still needs a check'), findsOneWidget);
  });

  testWidgets('nothing flagged: publishes without a dialog', (tester) async {
    await open(tester, draft());
    await tapPublish(tester);
    expect(find.text('Publish anyway'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('${demo.demoEventName} is live'), findsOneWidget);
  });
}
