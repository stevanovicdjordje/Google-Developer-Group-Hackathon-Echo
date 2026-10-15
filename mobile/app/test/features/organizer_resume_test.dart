import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/local_store.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho/features/organizer/organizer_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resuming an open draft after a restart: the draft id is remembered in
/// local storage, and opening `/organizer` goes to the review of that draft.
class _FakeOrganizer extends DemoOrganizerRepository {
  _FakeOrganizer({this.stored, this.error})
    : super('devfest', 'https://eho.app');

  /// What the server still has for the remembered id, if anything.
  final EventDraft? stored;
  final EventsException? error;
  final asked = <String>[];
  var published = 0;

  @override
  Future<EventDraft?> getDraft(String id) async {
    asked.add(id);
    if (error != null) throw error!;
    return stored;
  }

  @override
  Future<PublishedLink> publish(EventDraft draft) async {
    published++;
    return super.publish(draft);
  }
}

final _sessions = demo.sessions.where((s) => !s.isBreak).toList();

EventDraft _draft() => EventDraft(
  id: 'k2v9q3m1x8a7b6c5',
  name: 'Resumed Conf',
  dates: demo.demoEventDates,
  venue: demo.demoEventVenue,
  stages: demo.stages,
  sessions: _sessions,
  speakers: demo.speakers,
);

void main() {
  void usePhoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Future<(ProviderContainer, SharedPreferences)> open(
    WidgetTester tester,
    _FakeOrganizer repo, {
    String? rememberedId = 'k2v9q3m1x8a7b6c5',
  }) async {
    usePhoneView(tester);
    SharedPreferences.setMockInitialValues({
      if (rememberedId != null) 'eho.organizerDraftId': '"$rememberedId"',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        organizerRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: EhoApp()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Eho'))).go('/organizer');
    await tester.pumpAndSettle();
    return (container, prefs);
  }

  testWidgets('a remembered open draft goes straight to its review', (
    tester,
  ) async {
    final repo = _FakeOrganizer(stored: _draft());
    final (c, prefs) = await open(tester, repo);

    expect(repo.asked, ['k2v9q3m1x8a7b6c5']);
    expect(find.text('Review your event'), findsOneWidget);
    expect(find.text('Resumed Conf'), findsOneWidget);
    expect(find.text(_sessions.first.title), findsOneWidget);
    expect(c.read(organizerDraftProvider)!.name, 'Resumed Conf');
    // Still remembered until it is published.
    expect(prefs.getString('eho.organizerDraftId'), '"k2v9q3m1x8a7b6c5"');
  });

  testWidgets('the resumed review shows how many files it came from', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'eho.organizerDraftId': '"k2v9q3m1x8a7b6c5"',
      'eho.organizerDraftFileCount': '3',
    });
    final prefs = await SharedPreferences.getInstance();
    usePhoneView(tester);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        organizerRepositoryProvider.overrideWithValue(
          _FakeOrganizer(stored: _draft()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: EhoApp()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Eho'))).go('/organizer');
    await tester.pumpAndSettle();

    expect(find.text('Review your event'), findsOneWidget);
    expect(find.textContaining('Extracted from 3 files'), findsOneWidget);
  });

  testWidgets('a resumed review with an unknown file count hides the line', (
    tester,
  ) async {
    await open(tester, _FakeOrganizer(stored: _draft()));

    expect(find.text('Review your event'), findsOneWidget);
    expect(find.textContaining('Extracted from'), findsNothing);
  });

  testWidgets('a draft that is gone: upload screen, id cleared', (
    tester,
  ) async {
    final repo = _FakeOrganizer(); // getDraft → null (404 / published)
    final (c, prefs) = await open(tester, repo);

    expect(repo.asked, ['k2v9q3m1x8a7b6c5']);
    expect(find.text('Review your event'), findsNothing);
    expect(find.text('Choose files'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(c.read(organizerDraftIdProvider), isNull);
    expect(prefs.getString('eho.organizerDraftId'), isNull);
  });

  testWidgets('a failing lookup: upload screen without noise, id cleared', (
    tester,
  ) async {
    final repo = _FakeOrganizer(
      error: const EventsException(EventsErrorKind.offline),
    );
    final (c, _) = await open(tester, repo);

    expect(find.text('Choose files'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(c.read(organizerDraftIdProvider), isNull);
  });

  testWidgets('nothing remembered: no lookup', (tester) async {
    final repo = _FakeOrganizer(stored: _draft());
    await open(tester, repo, rememberedId: null);

    expect(repo.asked, isEmpty);
    expect(find.text('Choose files'), findsOneWidget);
  });

  testWidgets('back from the resumed review does not resume again', (
    tester,
  ) async {
    final repo = _FakeOrganizer(stored: _draft());
    await open(tester, repo);
    expect(find.text('Review your event'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose files'), findsOneWidget);
    expect(repo.asked, hasLength(1));
  });

  testWidgets('publishing clears the remembered id', (tester) async {
    final repo = _FakeOrganizer(stored: _draft());
    final (c, prefs) = await open(tester, repo);

    // No flagged rows in this draft, so publish goes straight through.
    await tester.scrollUntilVisible(
      find.text('Publish & get join link'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish & get join link'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(repo.published, 1);
    expect(find.text('Resumed Conf is live'), findsOneWidget);
    expect(c.read(organizerDraftIdProvider), isNull);
    expect(prefs.getString('eho.organizerDraftId'), isNull);
  });

  test('the file count is kept with the id and forgotten with it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer fresh() {
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    final first = fresh();
    first.read(organizerDraftIdProvider.notifier).set('abc123');
    first.read(organizerFileCountProvider.notifier).set(3);
    expect(fresh().read(organizerFileCountProvider), 3);
    first.read(organizerDraftIdProvider.notifier).set(null);
    expect(fresh().read(organizerFileCountProvider), 0);
  });

  test('the draft id survives a restart and can be forgotten', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer fresh() {
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    expect(fresh().read(organizerDraftIdProvider), isNull);
    fresh().read(organizerDraftIdProvider.notifier).set('abc123');
    final restarted = fresh();
    expect(restarted.read(organizerDraftIdProvider), 'abc123');
    restarted.read(organizerDraftIdProvider.notifier).set(null);
    expect(fresh().read(organizerDraftIdProvider), isNull);
  });
}
