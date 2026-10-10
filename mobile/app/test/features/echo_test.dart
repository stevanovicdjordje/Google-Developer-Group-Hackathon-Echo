import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho/features/echo/echo_screen.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Echo repository whose transcript arrives all at once, so the list is long
/// enough to scroll.
class _FakeEcho extends DemoEchoRepository {
  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream.value([
        for (var i = 0; i < 40; i++)
          TranscriptLine(
            atSeconds: i * 5,
            text: 'Spoken line number $i',
            translated: 'Izgovorena linija $i',
          ),
      ]);
}

Future<void> _pumpEcho(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [echoRepositoryProvider.overrideWithValue(_FakeEcho())],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EchoScreen(eventId: 'devsummit', sessionId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The transcript is a timed stream: one more pump after settling.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
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

  testWidgets('scrolling up pauses follow and shows Jump to live', (
    tester,
  ) async {
    await _pumpEcho(tester);
    // Following the live edge: the newest line is visible, no button.
    expect(find.text('Spoken line number 39'), findsOneWidget);
    expect(find.text('Jump to live'), findsNothing);

    await tester.drag(find.byType(ListView).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Jump to live'), findsOneWidget);
    expect(find.text('Spoken line number 39'), findsNothing);

    await tester.tap(find.text('Jump to live'));
    await tester.pumpAndSettle();
    expect(find.text('Jump to live'), findsNothing);
    expect(find.text('Spoken line number 39'), findsOneWidget);
  });
}
