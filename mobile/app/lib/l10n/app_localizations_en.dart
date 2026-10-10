// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Eho';

  @override
  String get devStatusTitle => 'System status';

  @override
  String get backendLabel => 'Backend';

  @override
  String get authLabel => 'Sign-in';

  @override
  String get statusOk => 'OK';

  @override
  String get statusChecking => 'Checking…';

  @override
  String statusError(String message) {
    return 'Error: $message';
  }

  @override
  String signedInAnonymously(String uid) {
    return 'Anonymous user $uid';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get retry => 'Try again';

  @override
  String eventTitle(String eventId) {
    return 'Event $eventId';
  }

  @override
  String get backendUnavailable =>
      'The server is not reachable right now. Check your connection and try again.';
}
