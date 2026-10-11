import 'package:eho/app.dart';
import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/models.dart';
import 'package:eho/features/agenda/agenda_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A published session may have no room (the extraction left it empty): the
/// agenda shows no empty stage chip and no stray "·" before the speaker.
void main() {
  final jana = demo.speakers.firstWhere((p) => p.name.contains('Jana'));
  final sessions = [
    Session(
      id: 'n1',
      title: 'Designing for crowded rooms',
      stage: '',
      start: '10:00',
      end: '10:30',
      speakers: [jana],
    ),
    const Session(
      id: 'n2',
      title: 'Opening keynote',
      stage: 'Main Hall',
      start: '09:00',
      end: '10:00',
      speakers: [],
    ),
    const Session(
      id: 'n3',
      title: 'Hallway track',
      stage: '',
      start: '11:00',
      end: '11:30',
      speakers: [],
    ),
  ];

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agendaProvider('devfest').overrideWith((ref) async => sessions),
        ],
        child: EhoApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
    // The demo repository "thinks" before answering (event summary).
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('no empty stage chip and no leading separator', (tester) async {
    await open(tester, '/e/devfest/agenda');

    // "All stages" + "Main Hall" only.
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.widgetWithText(ChoiceChip, 'Main Hall'), findsOneWidget);

    // The speaker alone; nothing starting with a separator.
    expect(find.text(jana.name), findsOneWidget);
    final texts = tester.widgetList<Text>(find.byType(Text));
    expect(texts.where((t) => (t.data ?? '').trim().startsWith('·')), isEmpty);
  });

  testWidgets('session detail without a room: no separator, no map button', (
    tester,
  ) async {
    await open(tester, '/e/devfest/session/n1');
    expect(find.text('Designing for crowded rooms'), findsWidgets);
    expect(find.text('10:00–10:30'), findsOneWidget);
    expect(find.textContaining('Show'), findsNothing);
  });
}
