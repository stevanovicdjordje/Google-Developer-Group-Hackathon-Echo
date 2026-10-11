import 'package:eho/data/app_state.dart';
import 'package:eho/data/models.dart';
import 'package:eho/features/find/find_screens.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Spot extends MeetingSpotNotifier {
  @override
  MeetingSpot? build() => const MeetingSpot(
    personName: 'Ana Petrović',
    place: 'Info pult',
    time: '16:05',
    floor: 'Prizemlje',
  );
}

void main() {
  testWidgets('meeting spot card shows its time and floor', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [meetingSpotProvider.overrideWith(_Spot.new)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MessagesScreen(eventId: 'devfest', personId: 'p1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meet at Info pult'), findsOneWidget);
    expect(find.text('16:05 · Prizemlje'), findsOneWidget);
    // No profile interests: "Matched on" uses Ana's, in sentence case.
    expect(find.text('Matched on mobile and AI / ML'), findsOneWidget);
  });
}
