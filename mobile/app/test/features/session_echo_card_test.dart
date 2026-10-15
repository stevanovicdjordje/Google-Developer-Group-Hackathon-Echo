import 'package:eho/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The "Echo is on" card on the session page appears only for the live talk.
void main() {
  Future<void> open(WidgetTester tester, String sessionId) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: EhoApp()));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/e/devfest/session/$sessionId');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('live talk shows the Echo card', (tester) async {
    await open(tester, 's1');
    expect(find.text('Echo is on for this talk'), findsOneWidget);
    expect(find.text('Open Echo'), findsOneWidget);
  });

  testWidgets('talk without Echo hides the Echo card', (tester) async {
    await open(tester, 's2');
    expect(
      find.text('Scaling event-driven backends on a startup budget'),
      findsOneWidget,
    );
    expect(find.text('Echo is on for this talk'), findsNothing);
    expect(find.text('Open Echo'), findsNothing);
  });
}
