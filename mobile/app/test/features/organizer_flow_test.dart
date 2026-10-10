import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
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
    expect(find.text(link), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
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

    GoRouter.of(tester.element(find.text('New event'))).go('/organizer/review');
    await tester.pumpAndSettle();
    expect(find.text('Review your event'), findsOneWidget);
    expect(find.text(firstSession.title), findsOneWidget);
  });
}
