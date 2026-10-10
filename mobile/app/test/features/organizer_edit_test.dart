import 'package:eho/app.dart';
import 'package:eho/data/app_state.dart';
import 'package:eho/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _session = Session(
  id: 'a1',
  title: 'Opening keynote',
  stage: 'Main Hall',
  start: '09:00',
  end: '10:00',
  speakers: [],
);

const _draft = EventDraft(
  name: 'Test Conf',
  dates: '1 Jan',
  venue: 'Hall',
  stages: ['Main Hall', 'Workshop Room'],
  sessions: [_session],
  speakers: [],
);

Future<ProviderContainer> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(organizerDraftProvider.notifier).set(_draft);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: EhoApp()),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.text('Eho'))).go('/organizer/review');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('edit a session: save updates the draft and the row', (
    tester,
  ) async {
    final container = await _open(tester);
    expect(find.text('Opening keynote'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit session'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Closing keynote');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workshop Room').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit session'), findsNothing);
    expect(find.text('Closing keynote'), findsOneWidget);
    expect(find.text('Opening keynote'), findsNothing);
    expect(find.textContaining('Workshop Room'), findsOneWidget);
    final saved = container.read(organizerDraftProvider)!.sessions.single;
    expect(saved.title, 'Closing keynote');
    expect(saved.stage, 'Workshop Room');
    expect(saved.start, '09:00');
  });

  testWidgets('empty title is rejected; cancel leaves the session', (
    tester,
  ) async {
    final container = await _open(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Title is required'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit session'), findsNothing);
    expect(find.text('Opening keynote'), findsOneWidget);
    expect(
      container.read(organizerDraftProvider)!.sessions.single.title,
      'Opening keynote',
    );
  });
}
