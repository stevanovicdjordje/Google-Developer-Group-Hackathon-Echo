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

  @override
  Future<List<PersonMatch>> recommendations(String eventId, Profile me) async {
    if (failRecommendations) {
      throw const FindException(FindErrorKind.offline, 'down');
    }
    return const [PersonMatch(person: _teodora, why: 'Speech models.')];
  }

  @override
  Future<PersonDetail?> person(String eventId, String personId) async =>
      personId == _teodora.id
      ? const PersonDetail(
          person: _teodora,
          contactState: ContactState.accepted,
        )
      : null;
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
      find.text(
        'The server is not reachable right now. Check your connection and '
        'try again.',
      ),
      findsOneWidget,
    );
    repo.failRecommendations = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Teodora Nikolić'), findsOneWidget);
  });
}
