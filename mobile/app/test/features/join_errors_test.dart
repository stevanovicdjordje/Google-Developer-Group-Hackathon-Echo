import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flows/flow_helpers.dart';

/// `getEvent` fails with [error] until [error] is cleared, then answers.
class _FlakyEvents extends DemoEventRepository {
  _FlakyEvents(this.error);

  Object? error;
  int calls = 0;

  @override
  Future<EventSummary> getEvent(String eventId) async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return const EventSummary(
      id: 'x1',
      name: 'Pop-up Conf',
      dates: 'Oct 11, 2026',
      venue: 'Hall A',
    );
  }
}

/// The Join screen explains why an event can't be opened, instead of printing
/// the exception.
void main() {
  testWidgets('not found: friendly message, no retry, back to start', (
    tester,
  ) async {
    final repo = _FlakyEvents(const EventsException(EventsErrorKind.notFound));
    await startApp(
      tester,
      overrides: [eventRepositoryProvider.overrideWithValue(repo)],
    );
    await openLink(tester, '/e/x1');

    expect(find.text("This event isn't available yet"), findsOneWidget);
    expect(find.textContaining('Check the link'), findsOneWidget);
    expect(find.textContaining('EventsException'), findsNothing);
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Back to start'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/');
    expect(find.text('Join with a link or code'), findsOneWidget);
  });

  testWidgets('offline: friendly message, Try again reloads the event', (
    tester,
  ) async {
    final repo = _FlakyEvents(const EventsException(EventsErrorKind.offline));
    await startApp(
      tester,
      overrides: [eventRepositoryProvider.overrideWithValue(repo)],
    );
    await openLink(tester, '/e/x1');

    expect(find.text("Can't reach Eho right now"), findsOneWidget);
    expect(find.textContaining('EventsException'), findsNothing);
    expect(find.text('Back to start'), findsOneWidget);
    expect(repo.calls, 1);

    // Still down: retry asks the repository again and shows the message again.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text("Can't reach Eho right now"), findsOneWidget);

    // Back online: the retry loads the join screen.
    repo.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.calls, 3);
    expect(find.text('Pop-up Conf'), findsOneWidget);
    expect(find.text('Join event'), findsOneWidget);
  });

  testWidgets('other failures: generic message with Try again', (tester) async {
    final repo = _FlakyEvents(StateError('boom'));
    await startApp(
      tester,
      overrides: [eventRepositoryProvider.overrideWithValue(repo)],
    );
    await openLink(tester, '/e/x1');

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Back to start'), findsOneWidget);
  });
}
