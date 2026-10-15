import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho/features/echo/echo_screen.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Echo repository whose transcript arrives all at once, so the list is long
/// enough to scroll (then it ends).
class _FakeEcho extends DemoEchoRepository {
  static List<TranscriptLine> get lines => [
    for (var i = 0; i < 40; i++)
      TranscriptLine(
        atSeconds: i * 5,
        text: 'Spoken line number $i',
        translated: 'Izgovorena linija $i',
      ),
  ];

  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream.value(lines);

  @override
  Future<TranscriptTranslation> translate(
    String eventId,
    String sessionId, {
    required String language,
    int fromIndex = 0,
  }) async => (
    lines: {for (var i = fromIndex; i < 40; i++) i: 'Prevedena linija $i'},
    nextIndex: 40,
  );
}

/// Still live (never ends), so the pill says "Jump to live".
class _LiveEcho extends _FakeEcho {
  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream<List<TranscriptLine>>.multi((c) {
        c.add(_FakeEcho.lines);
      });
}

/// Fails the first Ask with `502 ai_unavailable`, then answers.
class _FlakyEcho extends _FakeEcho {
  int asks = 0;

  @override
  Future<String> ask(
    String eventId,
    String sessionId,
    String question, {
    String language = 'en',
  }) async {
    if (asks++ == 0) {
      throw const EchoException(EchoErrorKind.aiBusy, 'ai_unavailable');
    }
    return 'Grounded answer';
  }
}

/// Records the language of every AI request.
class _LanguageEcho extends _FakeEcho {
  final languages = <String>[];

  /// Still live (never ends), so the catch-up card is shown.
  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream<List<TranscriptLine>>.multi((c) {
        c.add(_FakeEcho.lines);
      });

  @override
  Future<String> catchUp(
    String eventId,
    String sessionId, {
    String language = 'en',
  }) async {
    languages.add('catchUp:$language');
    return language == 'sr' ? 'Sažetak na srpskom' : 'English catch-up';
  }

  @override
  Future<String> ask(
    String eventId,
    String sessionId,
    String question, {
    String language = 'en',
  }) async {
    languages.add('ask:$language');
    return language == 'sr' ? 'Odgovor na srpskom' : 'English answer';
  }
}

/// Like [_LanguageEcho] but the talk has ended (the default fake stream).
class _EndedLanguageEcho extends _FakeEcho {
  final languages = <String>[];

  @override
  Future<String> ask(
    String eventId,
    String sessionId,
    String question, {
    String language = 'en',
  }) async {
    languages.add('ask:$language');
    return language == 'sr' ? 'Odgovor na srpskom' : 'English answer';
  }
}

Future<void> _pumpEcho(
  WidgetTester tester, [
  EchoRepository? repo,
  bool atTop = false,
]) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        echoRepositoryProvider.overrideWithValue(repo ?? _FakeEcho()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EchoScreen(eventId: 'devfest', sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The transcript is a timed stream: one more pump after settling.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  if (!atTop) {
    // An ended talk opens at the top; these tests read from the newest line.
    final list = tester.widget<ListView>(find.byType(ListView).last);
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('long-press a line → "Ask about this" → input pre-filled', (
    tester,
  ) async {
    await _pumpEcho(tester);

    await tester.longPress(find.text('Spoken line number 39'));
    await tester.pumpAndSettle();
    expect(find.text('Ask about this'), findsOneWidget);
    // Nothing is pre-filled until the affordance is tapped.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    await tester.tap(find.text('Ask about this'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains('Spoken line number 39'));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('an ended talk opens at the top, first line below the banner', (
    tester,
  ) async {
    await _pumpEcho(tester, null, true);
    expect(find.text('Full talk summary'), findsOneWidget);
    final banner = tester.getBottomLeft(
      find.text('Premium · AI summary of the whole talk'),
    );
    final first = tester.getTopLeft(find.text('Spoken line number 0'));
    expect(first.dy, greaterThan(banner.dy));
    expect(find.text('Spoken line number 39'), findsNothing);
  });

  testWidgets('an ended talk labels the pill Jump to end, not live', (
    tester,
  ) async {
    await _pumpEcho(tester, null, true);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Jump to end'), findsOneWidget);
    expect(find.text('Jump to live'), findsNothing);
  });

  testWidgets('scrolling up pauses follow and shows Jump to end', (
    tester,
  ) async {
    await _pumpEcho(tester);
    // Following the live edge: the newest line is visible, no button.
    expect(find.text('Spoken line number 39'), findsOneWidget);
    expect(find.text('Jump to end'), findsNothing);

    await tester.drag(find.byType(ListView).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Jump to end'), findsOneWidget);
    expect(find.text('Spoken line number 39'), findsNothing);

    await tester.tap(find.text('Jump to end'));
    await tester.pumpAndSettle();
    expect(find.text('Jump to end'), findsNothing);
    expect(find.text('Spoken line number 39'), findsOneWidget);
  });

  testWidgets('a live talk labels the pill Jump to live', (tester) async {
    await _pumpEcho(tester, _LiveEcho());
    await tester.drag(find.byType(ListView).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Jump to live'), findsOneWidget);
    expect(find.text('Jump to end'), findsNothing);
  });

  testWidgets('AI failure shows a friendly message and Try again', (
    tester,
  ) async {
    await _pumpEcho(tester, _FlakyEcho());

    await tester.enterText(find.byType(TextField), 'What about battery?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text("Echo couldn't answer right now."), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Grounded answer'), findsOneWidget);
    expect(find.text("Echo couldn't answer right now."), findsNothing);
  });

  testWidgets('voting toggles the count in the questions sheet', (
    tester,
  ) async {
    await _pumpEcho(tester);
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();
    expect(find.text('14'), findsOneWidget);

    await tester.tap(find.text('14'));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.text('14'), findsOneWidget);
  });

  testWidgets('translate toggle shows translated lines', (tester) async {
    await _pumpEcho(tester);
    await tester.tap(find.byTooltip('Translate to Serbian'));
    await tester.pumpAndSettle();
    expect(find.text('Prevedena linija 39'), findsOneWidget);
    expect(find.text('Spoken line number 39'), findsNothing);
  });

  testWidgets('translate on: catch-up and Ask are requested in Serbian', (
    tester,
  ) async {
    final repo = _LanguageEcho();
    await _pumpEcho(tester, repo);
    expect(repo.languages, ['catchUp:en']);

    await tester.tap(find.byTooltip('Translate to Serbian'));
    await tester.pumpAndSettle();
    expect(repo.languages, ['catchUp:en', 'catchUp:sr']);
    await tester.tap(find.text('Catch up'));
    await tester.pumpAndSettle();
    expect(find.text('Sažetak na srpskom'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kako su rešili bateriju?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repo.languages.last, 'ask:sr');
    expect(find.text('Odgovor na srpskom'), findsOneWidget);
  });

  testWidgets('translated banner: "live" only while the talk is live', (
    tester,
  ) async {
    await _pumpEcho(tester, _LiveEcho(), true);
    await tester.tap(find.byTooltip('Translate to Serbian'));
    await tester.pumpAndSettle();
    expect(
      find.text('Translated live from English · tap SR for the original'),
      findsOneWidget,
    );
    expect(find.text('Ask about this talk…'), findsOneWidget);
  });

  testWidgets('ended talk, translate on: banner without "live", English '
      'chrome, ask after switching sends language=sr', (tester) async {
    final repo = _EndedLanguageEcho();
    await _pumpEcho(tester, repo, true);
    await tester.tap(find.byTooltip('Translate to Serbian'));
    await tester.pumpAndSettle();
    expect(
      find.text('Translated from English · tap SR for the original'),
      findsOneWidget,
    );
    expect(
      find.text('Translated live from English · tap SR for the original'),
      findsNothing,
    );
    // The chrome stays English; only content is translated.
    expect(find.text('Ask about this talk…'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Full talk summary'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kako su rešili bateriju?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repo.languages.last, 'ask:sr');
    expect(find.text('Odgovor na srpskom'), findsOneWidget);
  });
}
