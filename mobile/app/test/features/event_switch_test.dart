import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho_maps/eho_maps.dart' show MapViewerScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _a = EventSummary(
  id: 'event-a',
  name: 'Alpha Conf',
  dates: 'Oct 11, 2026',
  venue: 'Hall A',
);
const _b = EventSummary(
  id: 'event-b',
  name: 'Beta Meetup',
  dates: 'Sep 18, 2026',
  venue: 'Hall B',
  isPast: true,
);

/// Two events whose agenda and Echo transcript differ, so stale content from
/// the other event is visible.
class _TwoEvents extends DemoEventRepository {
  static const events = {'event-a': _a, 'event-b': _b};

  @override
  Future<EventSummary> getEvent(String eventId) async => events[eventId]!;

  @override
  Future<List<Session>> agenda(String eventId) async => [
    Session(
      id: 's1',
      title: 'Talk of $eventId',
      stage: 'Glavna sala',
      start: '10:00',
      end: '11:00',
      speakers: const [],
      isLive: true,
    ),
  ];
}

class _Echo extends DemoEchoRepository {
  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream.value([
        TranscriptLine(
          atSeconds: 0,
          text: 'Spoken in $eventId',
          translated: 'Izgovoreno u $eventId',
        ),
      ]);
}

/// Switching between two joined events with the event shell alive: every tab
/// shows the new event's content, never the old one's, and never the
/// `/e/_/<tab>` placeholder branches.
void main() {
  testWidgets('switching events shows the right content in every tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepositoryProvider.overrideWithValue(_TwoEvents()),
          echoRepositoryProvider.overrideWithValue(_Echo()),
        ],
        child: EhoApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(joinedEventsProvider.notifier)
      ..add(_a)
      ..add(_b);

    GoRouter router() =>
        GoRouter.of(tester.element(find.byType(Scaffold).first));

    String location() =>
        router().routerDelegate.currentConfiguration.last.matchedLocation;

    Future<void> go(String to) async {
      router().go(to);
      await tester.pumpAndSettle();
    }

    Future<void> tapTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    String? mapEvent() {
      final map = find.byType(MapViewerScreen);
      if (map.evaluate().isEmpty) return null;
      return tester.widget<MapViewerScreen>(map).eventId;
    }

    String otherOf(String id) => id == 'event-a' ? 'event-b' : 'event-a';

    // Walks the four tabs of [id] and checks that they show that event.
    Future<void> checkTabs(String id, EventSummary event) async {
      final other = otherOf(id);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Talk of $id'), findsOneWidget);
      expect(find.text('Talk of $other'), findsNothing);
      expect(find.text(event.name), findsWidgets);

      await tapTab('Map');
      expect(location(), startsWith('/e/$id/map'));
      expect(mapEvent(), id);

      await tapTab('Find');
      expect(location(), '/e/$id/find');
      expect(find.text('Find people'), findsOneWidget);

      await tapTab('Profile');
      expect(location(), '/e/$id/profile');
      expect(find.text('Profile'), findsWidgets);

      await tapTab('Agenda');
      expect(location(), '/e/$id/agenda');
      expect(find.text('Talk of $id'), findsOneWidget);
      expect(find.text('Talk of $other'), findsNothing);
    }

    Future<void> checkEcho(String id) async {
      await tester.tap(find.text('Talk of $id'));
      await tester.pumpAndSettle();
      expect(location(), '/e/$id/session/s1');
      await tester.tap(find.text('Open Echo: live transcript & AI'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Spoken in $id'), findsOneWidget);
      expect(find.text('Spoken in ${otherOf(id)}'), findsNothing);
      router().pop();
      await tester.pumpAndSettle();
      router().pop();
      await tester.pumpAndSettle();
    }

    // A: all tabs and Echo.
    await go('/e/event-a/agenda');
    await checkTabs('event-a', _a);
    await checkEcho('event-a');
    expect(location(), '/e/event-a/agenda');

    // Back to My events via the app bar action, then open B.
    await tester.tap(find.byTooltip('My events'));
    await tester.pumpAndSettle();
    expect(location(), '/events');
    expect(find.text('Alpha Conf'), findsOneWidget);
    await tester.tap(find.text('Beta Meetup'));
    await tester.pumpAndSettle();
    expect(location(), '/e/event-b/agenda');
    await checkTabs('event-b', _b);
    await checkEcho('event-b');

    // From B's Map tab, to My events, then A again: A's Map shows A.
    await tapTab('Map');
    await go('/events');
    await go('/e/event-a/map');
    expect(mapEvent(), 'event-a');
    await tapTab('Find');
    expect(location(), '/e/event-a/find');
    await tapTab('Agenda');
    await checkTabs('event-a', _a);

    // Deep link into B while A's shell is alive.
    await go('/e/event-b/agenda');
    await checkTabs('event-b', _b);

    // Deep link to a non-agenda tab of A, then tab memory is per event.
    await go('/e/event-a/find');
    expect(find.text('Find people'), findsOneWidget);
    await tapTab('Agenda');
    expect(find.text('Talk of event-a'), findsOneWidget);
    expect(find.text('Talk of event-b'), findsNothing);

    // Per-tab state of one event must not leak into the other: a Find search,
    // an open person page and an agenda stage filter in A are gone in B.
    await go('/e/event-a/agenda');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Glavna sala'));
    await tester.pumpAndSettle();
    await tapTab('Find');
    await tester.enterText(find.byType(TextField), 'android');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Results for "android"'), findsOneWidget);
    await tester.tap(find.text('Ana Petrović').first);
    await tester.pumpAndSettle();
    expect(location(), '/e/event-a/find/person/p1');

    await go('/events');
    await tester.tap(find.text('Beta Meetup'));
    await tester.pumpAndSettle();
    expect(location(), '/e/event-b/agenda');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All stages'))
          .selected,
      isTrue,
    );
    await tapTab('Find');
    expect(location(), '/e/event-b/find');
    expect(find.text('Results for "android"'), findsNothing);
    expect(find.text('Recommended for you'), findsOneWidget);
    await tapTab('Agenda');
    expect(find.text('Talk of event-b'), findsOneWidget);

    // Same through a deep link while A's shell (with its open person page,
    // search and stage filter) is still alive: no My events in between.
    await go('/e/event-a/agenda');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Glavna sala'));
    await tester.pumpAndSettle();
    await tapTab('Find');
    await tester.enterText(find.byType(TextField), 'android');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Petrović').first);
    await tester.pumpAndSettle();
    expect(location(), '/e/event-a/find/person/p1');

    await go('/e/event-b/find');
    expect(location(), '/e/event-b/find');
    expect(find.text('Results for "android"'), findsNothing);
    expect(find.text('Recommended for you'), findsOneWidget);
    await tapTab('Agenda');
    expect(location(), '/e/event-b/agenda');
    expect(find.text('Talk of event-b'), findsOneWidget);
    expect(find.text('Talk of event-a'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All stages'))
          .selected,
      isTrue,
    );
    await tapTab('Map');
    expect(mapEvent(), 'event-b');
    await go('/e/event-a/agenda');
    await checkTabs('event-a', _a);

    // Let the Echo/demo timers finish.
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
  });
}
