import 'package:eho/app.dart';
import 'package:eho/core/theme.dart';
import 'package:eho/features/join/join_screens.dart';
import 'package:eho/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// M-46: one transparent status bar app-wide, light icons over ink headers,
/// and onboarding keeps the focused field above the pinned Continue button.
void main() {
  test('app bars use a transparent status bar with dark icons', () {
    final style = lightTheme.appBarTheme.systemOverlayStyle!;
    expect(style.statusBarColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light);
    expect(ehoStatusBarOnDark.statusBarColor, Colors.transparent);
    expect(ehoStatusBarOnDark.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('the whole app sits in the light status bar region', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: EhoApp(
          router: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value, ehoStatusBarOnLight);
  });

  for (final tall in [false, true]) {
    testWidgets(
      'onboarding with the keyboard open keeps the field and Continue visible'
      ' (${tall ? 'step 2 textarea' : 'step 1 fields'})',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625; // ~411 x 914 dp, like a phone
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const OnboardingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(OnboardingScreen)),
        );
        if (tall) {
          await tester.tap(find.text(l10n.continueButton));
          await tester.pumpAndSettle();
        }
        final field = tall
            ? find.widgetWithText(TextField, l10n.onboardingLookingForHint)
            : find.byType(TextField).first;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        // The keyboard (~320 dp) comes up after the field got focus.
        tester.view.viewInsets = const FakeViewPadding(bottom: 320 * 2.625);
        await tester.pumpAndSettle();
        final button = tester.getRect(
          find.widgetWithText(FilledButton, l10n.continueButton),
        );
        final rect = tester.getRect(field);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        // Continue is above the keyboard; the field is fully above Continue.
        expect(button.bottom, lessThanOrEqualTo(screen.height - 320));
        expect(rect.bottom, lessThanOrEqualTo(button.top));
        expect(rect.top, greaterThanOrEqualTo(0));
        if (!tall) {
          // The next field (headline) is visible too.
          expect(
            tester.getRect(find.byType(TextField).at(1)).bottom,
            lessThanOrEqualTo(button.top),
          );
        }
        addTearDown(tester.view.resetViewInsets);
      },
    );
  }
}
