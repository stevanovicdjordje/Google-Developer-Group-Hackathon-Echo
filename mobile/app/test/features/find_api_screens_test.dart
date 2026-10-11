import 'package:eho/data/app_state.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho/features/find/find_screens.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _teodora = Person(
  id: 'k7Qm2xLp',
  name: 'Teodora Nikolić',
  headline: 'ML researcher, Univ. of Belgrade',
  interests: ['AI / ML', 'Data'],
  lookingFor: 'Industry partners for speech models',
);

/// Answers like the Find service: people not in the demo data, server
/// contact state, and failures on demand.
class _ServiceLike extends DemoFindRepository {
  bool failRecommendations = true;
  FindErrorKind failKind = FindErrorKind.offline;
  int recommendationCalls = 0;
  PersonDetail? detail;

  @override
  Future<List<PersonMatch>> recommendations(String eventId, Profile me) async {
    recommendationCalls++;
    if (failRecommendations) throw FindException(failKind, 'down');
    return const [PersonMatch(person: _teodora, why: 'Speech models.')];
  }

  @override
  Future<PersonDetail?> person(String eventId, String personId) async =>
      detail ??
      (personId == _teodora.id
          ? const PersonDetail(
              person: _teodora,
              contactState: ContactState.accepted,
            )
          : null);
}

Widget _app(Widget home, FindRepository repo) => ProviderScope(
  overrides: [findRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('Person shows a server person and its contact state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repo = _ServiceLike()..failRecommendations = false;
    await tester.pumpWidget(
      _app(
        const PersonScreen(eventId: 'ev', personId: 'k7Qm2xLp', why: 'x'),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Teodora Nikolić'), findsOneWidget);
    expect(find.text('Teodora accepted · Message'), findsOneWidget);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(PersonScreen)),
    );
    expect(c.read(contactsProvider)['k7Qm2xLp'], ContactState.accepted);
  });

  testWidgets('Find shows a friendly error with Try again', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repo = _ServiceLike();
    await tester.pumpWidget(_app(const FindScreen(eventId: 'ev'), repo));
    await tester.pumpAndSettle();
    expect(
      find.text("Find can't be reached. Check your connection and try again."),
      findsOneWidget,
    );
    repo.failRecommendations = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Teodora Nikolić'), findsOneWidget);
  });

  testWidgets('Find explains a rate limit in its own words', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repo = _ServiceLike()..failKind = FindErrorKind.rateLimited;
    await tester.pumpWidget(_app(const FindScreen(eventId: 'ev'), repo));
    await tester.pumpAndSettle();
    expect(
      find.text('Too many requests. Wait a few seconds and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Person hints that someone does not accept contact requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repo = _ServiceLike()
      ..failRecommendations = false
      ..detail = const PersonDetail(
        person: _teodora,
        contactState: ContactState.none,
        allowContact: false,
      );
    await tester.pumpWidget(
      _app(
        const PersonScreen(eventId: 'ev', personId: 'k7Qm2xLp', why: 'x'),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Teodora doesn't accept contact requests."), findsOne);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send contact request'),
    );
    expect(button.onPressed, isNull);

    // With contact allowed there is no hint.
    repo.detail = const PersonDetail(
      person: _teodora,
      contactState: ContactState.none,
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(PersonScreen)),
    );
    c.invalidate(personDetailProvider(('ev', 'k7Qm2xLp')));
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't accept"), findsNothing);
  });

  group('recommendations reload', () {
    Future<(ProviderContainer, _ServiceLike)> setUp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final repo = _ServiceLike()..failRecommendations = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            findRepositoryProvider.overrideWithValue(repo),
            findReloadDelayProvider.overrideWithValue(
              const Duration(seconds: 2),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FindScreen(eventId: 'ev'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(FindScreen)),
      );
      return (c, repo);
    }

    testWidgets('a burst of ranking edits reloads once, after the delay', (
      tester,
    ) async {
      final (c, repo) = await setUp(tester);
      expect(repo.recommendationCalls, 1);
      final p = c.read(profileProvider);
      for (var i = 0; i < 4; i++) {
        c
            .read(profileProvider.notifier)
            .save(p.copyWith(visibleInFind: i.isEven, interests: ['a$i']));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(repo.recommendationCalls, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(repo.recommendationCalls, 2);
    });

    testWidgets('toggling contact and meeting-spot consents does not reload', (
      tester,
    ) async {
      final (c, repo) = await setUp(tester);
      final p = c.read(profileProvider);
      c
          .read(profileProvider.notifier)
          .save(p.copyWith(allowContact: true, shareMeetingSpot: true));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.recommendationCalls, 1);
    });
  });
}
