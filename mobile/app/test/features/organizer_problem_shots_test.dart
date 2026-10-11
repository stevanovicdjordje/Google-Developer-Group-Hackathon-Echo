import 'package:eho/app.dart';
import 'package:eho/features/dev/dev_shot_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The organizer "problem" shots show the server's issue messages and the
/// publish warnings (`features/dev/dev_shot_routes.dart`).
void main() {
  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: EhoApp(
          router: GoRouter(initialLocation: location, routes: devShotRoutes()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('organizer-review-issues shows row and general issues', (
    tester,
  ) async {
    await open(tester, '/dev/shot/organizer-review-issues');
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('No room given for this session'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Speaker not found in the speakers list'),
      findsOneWidget,
    );
    expect(find.text('2 sessions overlap in Sala A at 11:00'), findsOneWidget);
    expect(find.text('TO CHECK'), findsOneWidget);
  });

  testWidgets('organizer-published-warnings lists the publish warnings', (
    tester,
  ) async {
    await open(tester, '/dev/shot/organizer-published-warnings');
    expect(tester.takeException(), isNull);
    expect(find.text('CHECK BEFORE THE EVENT'), findsOneWidget);
    expect(
      find.text("Session s3 has no room; attendees won't see it on the map"),
      findsOneWidget,
    );
    expect(
      find.text('Speaker "Dr. Petrov" has no photo or bio'),
      findsOneWidget,
    );
  });
}
