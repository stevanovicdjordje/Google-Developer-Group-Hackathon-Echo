/// Event ids that mean "the demo event": the default `DEMO_EVENT_ID`
/// (`devfest`) and the one used before the rename (`devsummit`).
///
/// With `--dart-define=DEMO_EVENT_ID=<backend id>` both are treated as that
/// backend event: links are redirected (`demoEventRedirect` in
/// `core/router.dart`) and saved joined events are migrated
/// (`JoinedEventsNotifier` in `app_state.dart`).
///
/// `data/repositories.dart` still keeps its own private copy of `'devsummit'`
/// (`_legacyDemoEventId`); fold it into this file when that file is free.
const demoEventAliases = {'devfest', 'devsummit'};
