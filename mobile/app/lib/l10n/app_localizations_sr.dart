// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get appTitle => 'Eho';

  @override
  String get devStatusTitle => 'Status sistema';

  @override
  String get backendLabel => 'Backend';

  @override
  String get authLabel => 'Prijava';

  @override
  String get statusOk => 'Radi';

  @override
  String get statusChecking => 'Proveravam…';

  @override
  String statusError(String message) {
    return 'Greška: $message';
  }

  @override
  String signedInAnonymously(String uid) {
    return 'Anonimni korisnik $uid';
  }

  @override
  String get notSignedIn => 'Niste prijavljeni';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String eventTitle(String eventId) {
    return 'Događaj $eventId';
  }

  @override
  String get backendUnavailable =>
      'Server trenutno nije dostupan. Proverite internet vezu i pokušajte ponovo.';

  @override
  String get openEventLabel => 'ID događaja';

  @override
  String get openEvent => 'Otvori plan';
}
