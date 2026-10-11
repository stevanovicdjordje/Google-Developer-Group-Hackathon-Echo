/// Event ids that mean "the demo event": the default `DEMO_EVENT_ID`
/// (`devfest`) and the one used before the rename (`devsummit`).
///
/// With `--dart-define=DEMO_EVENT_ID=<backend id>` both are treated as that
/// backend event: links are redirected (`demoEventRedirect` in
/// `core/router.dart`) and saved joined events are migrated
/// (`JoinedEventsNotifier` in `app_state.dart`), and `DemoEventRepository`
/// resolves them to the demo event.
const demoEventAliases = {'devfest', 'devsummit'};

/// Events that exist only in the demo data (`pastEvent` in `demo_data.dart`).
/// The Events service doesn't know them unless it lists them in My events, so
/// with the live service they are dropped from the joined events and leaving
/// one never calls the server.
const demoOnlyEventIds = {'ai-meetup-ns-2026'};
