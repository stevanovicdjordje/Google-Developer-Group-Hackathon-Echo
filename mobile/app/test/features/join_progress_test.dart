import 'dart:async';

import 'package:eho/data/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flows/flow_helpers.dart';

/// A join that finishes only when [gate] completes.
class _SlowJoin extends DemoEventRepository {
  final gate = Completer<void>();

  @override
  Future<void> join(String eventId) => gate.future;
}

void main() {
  testWidgets('join button shows a spinner while joining, then navigates', (
    tester,
  ) async {
    final repo = _SlowJoin();
    await startApp(
      tester,
      overrides: [eventRepositoryProvider.overrideWithValue(repo)],
    );
    await openLink(tester, '/e/devfest');
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Join event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ilija');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Join event'), findsNothing);

    repo.gate.complete();
    await waitForJoin(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(locationOf(tester), '/e/devfest/agenda');
  });
}
