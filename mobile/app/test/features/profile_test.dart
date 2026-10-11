import 'package:eho/features/profile/profile_screen.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Profile shows organizer entries and opens the map editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // `/o` is the eho_maps editor and needs Firebase, so a stub stands in.
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (c, s) => const ProfileScreen()),
        GoRoute(path: '/o', builder: (c, s) => const Text('editor stub')),
        GoRoute(
          path: '/organizer',
          builder: (c, s) => const Text('upload stub'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Create event'), findsNothing);
    await tester.tap(find.text('For organizers'));
    await tester.pumpAndSettle();
    expect(find.text('Create event'), findsOneWidget);
    await tester.tap(find.text('Edit venue map'));
    await tester.pumpAndSettle();
    expect(find.text('editor stub'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/o',
    );
  });
}
