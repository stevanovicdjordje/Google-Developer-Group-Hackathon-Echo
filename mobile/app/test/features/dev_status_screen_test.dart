import 'package:eho/app.dart';
import 'package:eho/features/auth/auth_providers.dart';
import 'package:eho/features/dev/dev_status_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows backend and auth status in Serbian', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendHealthProvider.overrideWith((ref) async {}),
          ensureSignedInProvider.overrideWith((ref) async => 'uid-123'),
        ],
        child: const EhoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status sistema'), findsOneWidget);
    expect(find.text('Radi'), findsOneWidget);
    expect(find.text('Anonimni korisnik uid-123'), findsOneWidget);
  });
}
