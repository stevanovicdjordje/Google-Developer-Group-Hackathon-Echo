import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/echo_models.dart';
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho/features/echo/echo_screen.dart';
import 'package:eho/features/echo/echo_summary_screen.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transcript that arrives in two snapshots and then ends, so the talk
/// "ends while you watch" (the paywall opens by itself).
class _EndingEcho extends DemoEchoRepository {
  @override
  Stream<List<TranscriptLine>> transcript(
    String eventId,
    String sessionId,
  ) async* {
    const a = TranscriptLine(atSeconds: 0, text: 'Hello', translated: '');
    const b = TranscriptLine(atSeconds: 5, text: 'Thanks', translated: '');
    yield const [a];
    await Future<void>.delayed(const Duration(milliseconds: 200));
    yield const [a, b];
  }
}

/// The demo keynote, ending while you watch, with the summary requested
/// languages recorded.
class _KeynoteEcho extends DemoEchoRepository {
  final summaryLanguages = <String>[];

  @override
  Stream<List<TranscriptLine>> transcript(
    String eventId,
    String sessionId,
  ) async* {
    yield demo.keynoteTranscript.take(3).toList();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    yield demo.keynoteTranscript;
  }

  @override
  Future<EchoSummary> fullSummary(
    String eventId,
    String sessionId, {
    String language = 'en',
  }) {
    summaryLanguages.add(language);
    return super.fullSummary(eventId, sessionId, language: language);
  }
}

/// Live transcript that never ends.
class _LiveEcho extends DemoEchoRepository {
  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream<List<TranscriptLine>>.multi((c) {
        c.add(const [
          TranscriptLine(atSeconds: 0, text: 'Hello', translated: ''),
        ]);
      });
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  EchoRepository repo,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [echoRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EchoScreen(eventId: 'devfest', sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return container;
}

List<String> _questionOrder(WidgetTester tester) {
  const texts = [
    'Which model did you use for the hybrid router?',
    'How do you update on-device models without app releases?',
    'Does quantization hurt Serbian language quality?',
    'Mine: what about iOS?',
  ];
  final found = [
    for (final t in texts)
      if (find.text(t).evaluate().isNotEmpty)
        (t, tester.getTopLeft(find.text(t)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final f in found) f.$1];
}

void main() {
  testWidgets('Q&A sheet: sort Top / Newest / Mine, vote, ask the speaker', (
    tester,
  ) async {
    await _pump(tester, _LiveEcho());
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Questions for Mara'), findsOneWidget);
    expect(
      find.text('3 questions · shown to the speaker at the end'),
      findsOneWidget,
    );

    // Ask Mara a question from the sheet.
    await tester.enterText(
      find.widgetWithText(TextField, 'Ask Mara a question…'),
      'Mine: what about iOS?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(
      find.text('4 questions · shown to the speaker at the end'),
      findsOneWidget,
    );
    expect(find.text('YOUR QUESTION'), findsOneWidget);
    // After asking, the sheet shows Newest: your question first.
    expect(_questionOrder(tester).first, 'Mine: what about iOS?');

    await tester.tap(find.text('Top'));
    await tester.pumpAndSettle();
    expect(_questionOrder(tester), [
      'Which model did you use for the hybrid router?',
      'How do you update on-device models without app releases?',
      'Does quantization hurt Serbian language quality?',
      'Mine: what about iOS?',
    ]);

    // Voting a question up to 10 moves it above the 9-vote one.
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget, reason: 'vote toggles back');

    await tester.tap(find.text('Mine'));
    await tester.pumpAndSettle();
    expect(_questionOrder(tester), ['Mine: what about iOS?']);

    // The AI grouped 3 similar questions into the first one (design chip).
    await tester.tap(find.text('Top'));
    await tester.pumpAndSettle();
    expect(find.text('3 similar questions merged'), findsOneWidget);

    // The vote button is the design's 52×56 and filled when voted.
    final voteBox = find.ancestor(
      of: find.text('1'),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 52 && w.height == 56,
      ),
    );
    expect(voteBox, findsOneWidget);
  });

  testWidgets('a question the server merged highlights the existing one', (
    tester,
  ) async {
    await _pump(tester, _LiveEcho());
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Ask Mara a question…'),
      'What model runs the router?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();

    expect(
      find.text('Merged with a similar question · your vote counts'),
      findsOneWidget,
    );
    // No new question: the existing one is now yours, with your vote.
    expect(
      find.text('3 questions · shown to the speaker at the end'),
      findsOneWidget,
    );
    expect(find.text('What model runs the router?'), findsNothing);
    expect(find.text('YOUR QUESTION'), findsOneWidget);
    expect(
      _questionOrder(tester).first,
      'Which model did you use for the hybrid router?',
    );
    expect(find.text('15'), findsOneWidget);
    expect(find.text('4 similar questions merged'), findsOneWidget);
  });

  testWidgets('summary: structured rows; a timestamp jumps to the line', (
    tester,
  ) async {
    final repo = _KeynoteEcho();
    await _pump(tester, repo);
    await tester.tap(find.text('Unlock summary'));
    await tester.pumpAndSettle();

    expect(find.text('Model size'), findsOneWidget);
    expect(find.text('Hard questions'), findsOneWidget);
    expect(repo.summaryLanguages, ['en']);

    // Serbian from the header button, requested with language=sr.
    await tester.tap(find.byTooltip('Translate to Serbian'));
    await tester.pumpAndSettle();
    expect(repo.summaryLanguages, ['en', 'sr']);
    expect(find.text('Baterija'), findsOneWidget);
    await tester.tap(find.byTooltip('Show original'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('00:55'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('00:55'));
    await tester.pumpAndSettle();
    // Back on Echo with the 00:55 line highlighted ("Ask about this").
    expect(find.text('AI SUMMARY · PREMIUM'), findsNothing);
    expect(find.text('Ask about this'), findsOneWidget);
    expect(
      find.text(
        'The second trade-off is model size. You cannot ship forty gigabytes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('talk ends → paywall → unlock → summary screen', (tester) async {
    final container = await _pump(tester, _EndingEcho());

    // The paywall opened by itself when the talk ended.
    expect(
      find.text('Missed something? Get the whole talk in 2 minutes.'),
      findsOneWidget,
    );
    expect(find.text('This talk'), findsOneWidget);
    expect(find.text('Every talk at DevFest Belgrade 2026'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(container.read(unlockedSummariesProvider), isEmpty);

    // The summary card opens the paywall again.
    await tester.tap(find.text('Full talk summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock summary'));
    await tester.pumpAndSettle();
    expect(container.read(unlockedSummariesProvider), {'s1'});

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
    // This transcript has no line near 00:44: the time is shown, not linked.
    expect(
      find.text(
        '12% hit for continuous transcription → process audio in '
        'batches. 00:44',
      ),
      findsOneWidget,
    );

    // Back on Echo the card says Unlocked and opens the summary directly.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Unlocked'), findsOneWidget);
  });

  testWidgets('"Every talk" unlocks every talk of the event', (tester) async {
    final container = await _pump(tester, _EndingEcho());
    await tester.tap(find.text('Every talk at DevFest Belgrade 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock summary'));
    await tester.pumpAndSettle();
    final unlocked = container.read(unlockedSummariesProvider);
    expect(unlocked, contains('s1'));
    expect(unlocked.length, greaterThan(1));
    expect(unlocked, isNot(contains('s0')), reason: 's0 is a break');
  });

  group('parseEchoSummary', () {
    test('API style: bullets only, "Advice:" becomes the takeaway', () {
      final p = parseEchoSummary(
        '• Cost: drops to zero.\n• Privacy: stays local.\n'
        '• Advice: start hybrid.',
      );
      expect(p.takeaway, 'start hybrid.');
      expect(p.keyPoints, ['Cost: drops to zero.', 'Privacy: stays local.']);
      expect(p.tradeoffs, isEmpty);
    });

    test(
      'API style without a labeled bullet: first bullet is the takeaway',
      () {
        final p = parseEchoSummary('• One.\n• Two.');
        expect(p.takeaway, 'One.');
        expect(p.keyPoints, ['Two.']);
      },
    );

    test('sectioned text: takeaway, key points and trade-offs', () {
      final p = parseEchoSummary(
        'My talk — Mara\n\nKey points\n• A.\n• B.\n\n'
        'Trade-offs and fixes\n• Battery: 12% hit. Fix: batching.\n\n'
        'Takeaway\nStart hybrid.',
        title: 'My talk',
      );
      expect(p.takeaway, 'Start hybrid.');
      expect(p.keyPoints, ['A.', 'B.']);
      expect(p.tradeoffs.single.issue, 'Battery');
      expect(p.tradeoffs.single.detail, '12% hit. Fix: batching.');
      expect(p.paragraphs, isEmpty);
    });
  });
}
