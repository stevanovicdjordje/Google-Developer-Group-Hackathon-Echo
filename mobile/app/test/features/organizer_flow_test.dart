import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:eho/features/organizer/organizer_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Organizer flow on demo data: review → publish → link/QR. The file picker
/// can't run in widget tests, so the upload step is covered by calling the
/// repository's `extract` directly and putting the result in the draft
/// provider, which is exactly what the upload screen does after picking files.
void main() {
  void usePhoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  final firstSession = demo.sessions.firstWhere((s) => !s.isBreak);

  testWidgets('review → publish → join link and QR', (tester) async {
    usePhoneView(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(organizerDraftProvider.notifier)
        .set(
          EventDraft(
            name: demo.demoEventName,
            dates: demo.demoEventDates,
            venue: demo.demoEventVenue,
            stages: demo.stages,
            sessions: demo.sessions.where((s) => !s.isBreak).toList(),
            speakers: demo.speakers,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: EhoApp()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Eho'))).go('/organizer/review');
    await tester.pumpAndSettle();

    // Review shows the extracted event and its sessions.
    expect(find.text('Review your event'), findsOneWidget);
    expect(find.text(demo.demoEventName), findsOneWidget);
    // Count tiles: the number is big, the unit sits under it.
    expect(find.text('${demo.stages.length}'), findsWidgets);
    expect(find.text('stages'), findsOneWidget);
    expect(find.text(firstSession.title), findsOneWidget);

    // Publish (the demo repository "thinks" for a second first). The button
    // sits below the session list, so scroll the lazy ListView to it.
    await tester.scrollUntilVisible(
      find.text('Publish & get join link'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish & get join link'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Link/QR screen shows the `/e/{eventId}` join link.
    final link = '${linkBase()}/e/$demoEventId';
    expect(find.text('${demo.demoEventName} is live'), findsOneWidget);
    // Shown short (no scheme); copy and QR keep the full link.
    expect(find.text(displayJoinLink(link)), findsOneWidget);
    expect(find.text(link), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    // "Open as attendee" lands on the event's join screen.
    await tester.scrollUntilVisible(
      find.text('Open as attendee'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open as attendee'));
    await tester.pumpAndSettle();
    expect(find.text('Join event'), findsOneWidget);
  });

  testWidgets('extract (upload step) → draft → review', (tester) async {
    usePhoneView(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: EhoApp()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Eho'))).go('/organizer');
    await tester.pumpAndSettle();

    // Nothing picked yet: the build button is disabled.
    expect(find.text('Drop in whatever you have'), findsOneWidget);
    final buildButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Build my event with AI'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(buildButton.onPressed, isNull);

    // What the screen does after picking files, minus the picker.
    final extracting = container.read(organizerRepositoryProvider).extract(
      const [UploadedFile(name: 'agenda.pdf', sizeBytes: 2048)],
    );
    await tester.pump(const Duration(seconds: 3));
    final draft = await extracting;
    container.read(organizerDraftProvider.notifier).set(draft);
    expect(draft.sessions, isNotEmpty);
    expect(draft.sessions.any((s) => s.isBreak), isFalse);
    // The demo extraction leaves one session without a stage (flagged row).
    expect(
      [for (final s in draft.sessions.where((s) => s.stage.isEmpty)) s.id],
      [demo.organizerFlaggedSessionId],
    );

    GoRouter.of(tester.element(find.text('New event'))).go('/organizer/review');
    await tester.pumpAndSettle();
    expect(find.text('Review your event'), findsOneWidget);
    expect(find.text(firstSession.title), findsOneWidget);
  });

  test('displayJoinLink drops the scheme and may use a public host', () {
    expect(
      displayJoinLink('http://127.0.0.1:52020/e/devfest', publicBase: ''),
      '127.0.0.1:52020/e/devfest',
    );
    expect(
      displayJoinLink('https://eho.app/e/devfest', publicBase: ''),
      'eho.app/e/devfest',
    );
    expect(
      displayJoinLink(
        'http://127.0.0.1:52020/e/devfest?at=s1',
        publicBase: 'https://eho.app',
      ),
      'eho.app/e/devfest?at=s1',
    );
  });

  testWidgets('review says how many files the event was extracted from', (
    tester,
  ) async {
    usePhoneView(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(organizerFileCountProvider.notifier).set(3);
    container
        .read(organizerDraftProvider.notifier)
        .set(
          EventDraft(
            name: demo.demoEventName,
            dates: demo.demoEventDates,
            venue: demo.demoEventVenue,
            stages: demo.stages,
            sessions: demo.sessions.where((s) => !s.isBreak).toList(),
            speakers: demo.speakers,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: EhoApp()),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Eho'))).go('/organizer/review');
    await tester.pumpAndSettle();
    expect(find.text('Extracted from 3 files'), findsOneWidget);
  });
}
