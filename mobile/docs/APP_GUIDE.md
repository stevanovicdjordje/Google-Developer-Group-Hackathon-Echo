# Eho app guide (for workers)

The one page a worker reads before touching `mobile/app/`. Keep it current: whoever changes the structure updates this file in the same commit.

## What the app is

Flutter (web + Android + iOS), one codebase. Attendees and organizers use the same app. Product: `docs/PRODUCT.md`. Demo plan, including what is mocked: `docs/MVP.md`. Everything except the venue map, Echo and Find runs on **demo data**; Echo and Find fall back to it when their service isn't running.

## Layout

```
mobile/
├── app/                      # the app shell — owned by `mobile`
│   ├── lib/
│   │   ├── main.dart         # Firebase init (non-blocking, 5 s timeout) → EhoApp
│   │   ├── app.dart          # MaterialApp.router, theme, l10n delegates
│   │   ├── core/
│   │   │   ├── router.dart   # ALL routes (see below)
│   │   │   ├── theme.dart    # the ONLY place for colors/typography (see Theme)
│   │   │   ├── ui/           # shared widgets (LiveBadge, SectionLabel, IconTile, AiHint, EhoCard)
│   │   │   ├── api/api_client.dart   # HTTP client for real endpoints (Bearer Firebase token)
│   │   │   ├── config.dart, providers.dart, firebase/
│   │   ├── data/
│   │   │   ├── models.dart        # plain Dart models
│   │   │   ├── demo_data.dart     # hardcoded fake conference (names fictional)
│   │   │   ├── repositories.dart  # interfaces + Demo* implementations + providers
│   │   │   └── app_state.dart     # Riverpod Notifiers: profile, joined events, contacts, meeting spot, unlocked summaries, organizer draft
│   │   ├── features/<area>/       # screens, one folder per area
│   │   └── l10n/                  # ARB (en template, sr) + generated app_localizations*.dart (committed)
│   └── test/
│       └── features/happy_path_test.dart  # walks the whole attendee flow
├── maps/                     # `eho_maps` package — owned by feature:maps (@Vertiglo). DO NOT EDIT.
├── docs/                     # api-needs.md (backend asks), this guide, WORKFLOW/BOARD/HANDOFF (orchestrator)
└── scripts/                  # dev_all.sh (emulators+API+app), shots.sh (screenshots)
```

## Routes (`core/router.dart`)

| Route | Screen | File |
| --- | --- | --- |
| `/` | Start | `features/start/start_screen.dart` |
| `/events` | My events (picker) | `features/join/join_screens.dart` |
| `/onboarding` | 3-step onboarding, pops `true` | `features/join/join_screens.dart` |
| `/o`, `/o/e/:eventId` | Venue map editor from `eho_maps` (only these routes of `mapsRoutes()` are mounted); reachable from Profile → For organizers | `mobile/maps` (feature:maps, read-only) |
| `/organizer` → `/review` → `/published?url&name` | Organizer upload / review / link+QR | `features/organizer/organizer_screens.dart` |
| `/e/:eventId` | `EventEntry`: join screen, or redirect to agenda (or map if `?at=`) | `core/router.dart`, `features/join/` |
| `/e/:eventId/{agenda,map,find,profile}` | Tabs inside `EventShell` (a `StatefulShellRoute.indexedStack`: each tab is a branch kept alive, so state survives tab switches; tab index from URL; branch `initialLocation`s are `/e/_/<tab>` placeholders that are never opened. Navigate tabs with `context.go('/e/{id}/<tab>')`, never `goBranch`. Tab root pages get `key: ValueKey(eventId)` so switching events never shows another event's state) | `features/event/event_shell.dart` + per-tab folders |
| `/e/:eventId/map/stand/:standId` | Map tab focused on a feature | `features/map/map_tab.dart` |
| `/e/:eventId/stand/:standId` | redirect → `/map/stand/…` (link format from `team-event-join`) | |
| `/e/:eventId/find/person/:personId?why=` | Person + contact (full screen: `EventShell` hides the bottom nav on this route) | `features/find/find_screens.dart` |
| `/e/:eventId/session/:sessionId` (+ `/echo`) | Session detail, Echo | `features/agenda/`, `features/echo/echo_screen.dart` |
| `/e/:eventId/messages/:personId` | Messages (MOCK) + meeting spot | `features/find/find_screens.dart` |
| `/dev` | Backend/auth status (dev only) | `features/dev/` |
| `/dev/shot`, `/dev/shot/:state` | Index / one screen state opened directly (see Verifying) | `features/dev/dev_shot_routes.dart` |

Use `context.go` for tab/top-level navigation and `context.push` for drill-down pages that should keep "back".

## Data

- Screens read data **only** through providers in `data/repositories.dart` (`eventRepositoryProvider`, `echoRepositoryProvider`, `findRepositoryProvider`, `organizerRepositoryProvider`) and the Notifiers in `data/app_state.dart`.
- Each interface method is tagged with an `[API-n]` ID from `mobile/docs/api-needs.md`. To wire a real endpoint: add an HTTP implementation using `ApiClient`, switch the provider, and leave the screens alone.
- **Echo** (`echoRepositoryProvider`) is the one wired area besides the map: `data/echo_api_repository.dart` talks to the Echo service (`contracts/echo`, `ECHO_API_BASE_URL`, default `http://localhost:8082`). Transcript = Firestore listener on `events/{e}/published/echo/sessions/{s}/lines` (behind `EchoTranscriptSource`, faked in tests); AI, questions/votes and translation = HTTP with the anonymous Firebase ID token. It is used only when `USE_ECHO_API` (default true), Firebase initialized, and `/healthz` answers on first use (`FallbackEchoRepository`); otherwise `DemoEchoRepository`. Tests never initialize Firebase, so they always get demo data. Failures arrive as `EchoException` (`aiBusy`, `rateLimited`, `offline`, `noTranscript`, `failed`); the screen maps them to friendly text + "Try again". Echo 0.3.0 types (`EchoSummary`/`TalkSummary`, `QuestionSubmission`) live in `data/echo_models.dart`; AI calls take `language` (`sr` while translate is on).
- **Find** (`findRepositoryProvider`) is wired the same way: `data/find_api_repository.dart` talks to the Find service (`contracts/find` 0.1.1, `FIND_API_BASE_URL`, default `http://localhost:8083`) with the anonymous Firebase ID token. Used only when `USE_FIND_API` (default true), Firebase initialized, and `/healthz` answers on first use (`FallbackFindRepository`); otherwise `DemoFindRepository`, so tests and a stopped service look exactly like the demo. Call order is handled inside the repository: `putMyProfile` (only once `Profile.onboarded`; consents exactly as set; edits coalesced; never logged), `joinFind` once per event, then recommendations / search / person / contact / meeting spot (it re-joins once on `not_present`). `ProfileNotifier.save` pushes every profile/consent change; `MeetingSpotNotifier.agree(eventId, spot)` saves the spot with the contact (`MeetingSpot.personId`; `time`/`floor` stay app-only). Person and Messages read the person through `personDetailProvider` (`FindRepository.person` → `PersonDetail`, null = not visible); the server's `contactState` overwrites the local `contactsProvider` entry (`incoming` shows as `none`; sending a request accepts theirs). `requestContact` is a stream of states (demo: `requested`, then `accepted` after 2 s; API: the server's state). Failures arrive as `FindException` (`offline`, `rateLimited`, `aiBusy`, `notFound`, `notAllowed`, `profileRequired`, `failed`); Find/Person/Messages show friendly text (`findError*` keys) + "Try again"; Person shows `personNotAccepting` when `allowContact` is false. `recommendationsProvider` reloads only when interests/lookingFor/visibleInFind/onboarded change, after a 2 s debounce (`findReloadDelayProvider`; consent toggles don't reload). `joinFind` runs lazily on the first Find call per event (= opening the Find tab). `deleteProfile` exists but no screen offers it yet.
- Firebase: `core/firebase/firebase_init.dart`. Default `USE_EMULATORS=true` uses the `demo-eho` emulator project; `USE_EMULATORS=false` builds `FirebaseOptions` from `FIREBASE_*` dart-defines (`realFirebaseOptions`, README "Build-time settings").
- Venue map data comes from `eho_maps` (`publishedEventProvider(eventId)` gives `PublishedEvent` with `map.features`). Stage names in demo data equal room names on the seeded map; the app links them **by name**. Selecting a stage on the Map tab opens the app's own sheet (`features/map/map_feature_sheet.dart`, via `featureSheetBuilder`: capacity, walk time, NOW/NEXT session, Start route, Open Echo); other places keep the maps default sheet.
- Attendee state (profile, joined events, contacts, meeting spot, unlocked summaries) is persisted via `data/local_store.dart` (shared_preferences, key prefix `eho.`), loaded before `runApp`. Without the `sharedPreferencesProvider` override (e.g. in tests) state stays in memory. The organizer draft is never persisted.

## UI rules

- Colors and text styles only via `Theme.of(context)` (`colorScheme`, `textTheme`). No hex colors in screens (exception: white behind the QR code).
- Material 3 components. Phone-first: check 412 px width (no `RenderFlex overflowed`).
- UI text is English and comes from the ARB files (see Strings). No hardcoded user-visible strings in screens.

## Theme (design tokens → API)

Design source: `mobile/docs/design/` (README token table + one `.dc.html` per screen). Everything lives in `core/theme.dart`; the app is **light only** (`themeMode: ThemeMode.light`). Fonts are bundled assets (`assets/fonts/`, OFL): **Bricolage Grotesque** 700 (`displayFont`) and **Instrument Sans** 400/500/600 (`bodyFont`, the default family).

| Design token | Use in code |
| --- | --- |
| background `#F3F5F9` (screen ground) | `scaffoldBackgroundColor` (automatic), `colorScheme.surfaceContainer`, `context.eho.background` |
| surface `#FFFFFF` (cards, inputs, nav) | `colorScheme.surface` |
| ink `#0D1321` (text) | `colorScheme.onSurface`; dark hero blocks / selected chip: `context.eho.ink` + `context.eho.onInk` (= `inverseSurface`/`onInverseSurface`) |
| ink-secondary `#4A5468` | `colorScheme.onSurfaceVariant` |
| body-on-tint `#1F2A44` | `context.eho.bodyOnTint` |
| outline `#C9D0DC` / divider `#DDE2EB` | `colorScheme.outline` / `colorScheme.outlineVariant` (also `Divider()`) |
| primary `#2F4BFF`, pressed `#1A33D6` | `colorScheme.primary`; `colorScheme.onPrimaryContainer` = `context.eho.primaryPressed` |
| primary-container `#E6EAFF` | `colorScheme.primaryContainer` |
| live `#E85D1F` | `context.eho.live` (= `colorScheme.secondary` = `tertiary`), text on it `eho.onLive` |
| live-container `#FFEDE3` / on-live-container `#C2410C` | `context.eho.liveContainer` / `context.eho.onLiveContainer` (= `secondaryContainer`/`onSecondaryContainer`, same for tertiary) |
| on-dark `#D5DBE6` / `#B9C3FF` / `#FFB48C` | `context.eho.onInkMuted` / `onInkPrimary` / `onInkLive`; round button on ink: `eho.inkOverlay` |

`context.eho` needs `import 'package:eho/core/theme.dart';` (relative: `../../core/theme.dart`). Note: Material widgets that default to `secondaryContainer` (`FilledButton.tonal`, `SegmentedButton` without the theme) come out live-orange; use `primaryContainer` explicitly when you want blue tint.

**Text styles** (`Theme.of(context).textTheme`):

| Style | Font / size / weight | Design use |
| --- | --- | --- |
| `displayLarge` | Bricolage 72/700, -2 | Start wordmark |
| `displayMedium` | Bricolage 40/700, -1 | Join hero title |
| `displaySmall` | Bricolage 34/700, -0.5 | big titles (34 px screens) |
| `headlineLarge` | Bricolage 32/700, -0.5 | screen titles ("Agenda", "Find people") |
| `headlineMedium` | Bricolage 26/700, -0.5 | event card title |
| `headlineSmall` | Bricolage 24/700, -0.3 | section/sheet headlines |
| `titleLarge` | Bricolage 20/700 | app bar title, dialog/sheet titles |
| `titleMedium` | Instrument 17/600 | card titles (session, person) |
| `titleSmall` | Instrument 15/600 | small headings, time column |
| `bodyLarge` | Instrument 17/400, 1.45 | transcript, list rows |
| `bodyMedium` | Instrument 15/400, 1.45 | default body |
| `bodySmall` | Instrument 14/400 | meta lines (pair with `onSurfaceVariant`) |
| `labelLarge` | Instrument 14/600 | chips, small buttons, AI hint |
| `labelMedium` | Instrument 13/500 | captions |
| `labelSmall` | Instrument 12/600, +0.6 | overline / LIVE label (upper-case it) |

**Component themes** (no per-screen styling needed): Filled/Elevated buttons 56 h, radius 16, 17/600, primary; Outlined = white, 1.5 `outline` border; TextButton = primary 16/600; IconButton 44×44 circle; Chips radius 18 (stadium), white + `outline` border, selected = ink fill + white label, no checkmark; Card white, radius 18, no elevation, no margin; inputs filled white, radius 16, 1.5 `outline`, focused `primary`; NavigationBar white, primary-container stadium indicator, label 12, active primary / inactive ink-secondary (Material can't draw the 1 px top border: put a `Divider()` above the bar in the shell if wanted); AppBar = scaffold color, no elevation/scroll tint, Bricolage `titleLarge`; ListTile title 17/500, subtitle 14 `onSurfaceVariant`; SnackBar floating ink; BottomSheet white, radius 24 top, drag handle; SegmentedButton = `surfaceContainer` track, selected white + primary text.

**Shared widgets** (`import '../../core/ui/ui.dart';`, all colors from the theme):

| Widget | Usage |
| --- | --- |
| `LiveBadge('Live now · Echo on')` | live dot + upper-cased 12/600 label in `onLiveContainer`; `onDark: true` on ink blocks |
| `SectionLabel('With Eho you get')` | upper-case 13/600 +0.8 overline in `onSurfaceVariant`, 8 px bottom padding |
| `IconTile(Icons.calendar_today)` | 40×40 `primaryContainer` rounded square, `primary` icon; `live: true` for the live tint; `size:` to scale |
| `AiHint('Catch-up')` | sparkle (`Icons.auto_awesome`) + `labelLarge` text in `primary`; `color:`/`style:` to override |
| `EhoCard(child: …, onTap: …)` | white radius-18 card, 16 padding, ink ripple; `borderColor: context.eho.live` for live sessions, `color:` for tinted cards |

## Strings

The app UI is English by default (`locale: const Locale('en')` in `app.dart`, decision `product-ui-language`); Serbian is kept compiling as a second locale. To add a string:

1. Add the key to `lib/l10n/app_en.arb` (the template). Placeholders and plurals need an `@key` entry, e.g. `"sessionShowOnMap": "Show {stage} on map"` with `"@sessionShowOnMap": {"placeholders": {"stage": {"type": "String"}}}`; counts use ICU plurals (`{count, plural, =1{1 stage} other{{count} stages}}`).
2. Add the same key to `lib/l10n/app_sr.arb` (Serbian, Latin script; copy the English if unsure). Every key must exist in both files.
3. Run `flutter gen-l10n` (or `flutter pub get`/`flutter analyze`, which regenerate) and commit the regenerated `lib/l10n/app_localizations*.dart`.
4. Use it in the screen: `final l10n = AppLocalizations.of(context);` then `Text(l10n.sessionShowOnMap(s.stage))`.

Not in ARB: demo data content (`demo_data.dart`), debug logs, URLs. The venue map (`eho_maps`) has its own `MapsLocalizations`; it follows the same app locale. Widget tests that build a bare `MaterialApp` must pass `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales: AppLocalizations.supportedLocales`.

## Verifying

```bash
cd mobile/app
flutter pub get
flutter analyze             # must be "No issues found!"
flutter test                # all tests must pass
# screenshots (builds web first; each route is a fresh page load):
../scripts/shots.sh /tmp/eho-shots start=/ agenda=/e/devfest/agenda echo=/e/devfest/session/s1/echo
```

`DEMO_EVENT_ID=<backend id>` (shots.sh forwards it as a dart-define, README "Build-time settings") makes the router redirect `/e/devfest/...` and the legacy `/e/devsummit/...` to `/e/<backend id>/...` (`demoEventRedirect` in `core/router.dart`, query kept). Screens take the event id from the URL (not from `demoEventId`), so links with another id are not redirected; with the default `devfest` nothing is. Saved joined events `devfest`/`devsummit` are migrated to `<backend id>` (`data/demo_ids.dart` holds the alias set), so no second join screen; stand links keep `?at=` for the map's "you are here" marker.

- `shots.sh` builds with `USE_ECHO_API=false` (Echo shows demo data); `export USE_ECHO_API=true` before it to screenshot the real Echo service. Find uses its service when it answers on `:8083`, demo data otherwise.
- **Shot routes** (dev only, `DEV_ROUTES` dart-define, default true; `--dart-define=DEV_ROUTES=false` unmounts them): `shots.sh` can't tap, so states that need interaction have a direct URL: `/dev/shot/<state>` for `echo-qa`, `echo-qa-own`, `echo-selected`, `echo-paywall`, `echo-summary`, `echo-translated`, `echo-ended`, `echo-ended-unlocked`, `person-none|pending|connected`, `messages-spot`, `find-results`, `myevents-live`, `organizer-review`, `organizer-published`, `organizer-upload-files`, `organizer-upload-progress`. `/dev/shot` lists them as links. Add a new state in `devShots` (seed it with a nested `ProviderScope`, or open the sheet in a post-frame callback) and in `test/features/dev_shot_routes_test.dart`.
- Widget tests: follow `test/features/happy_path_test.dart`. Use a phone-sized `tester.view`, `pumpAndSettle` for navigation, and an extra `pump` after stream/async updates (Echo uses timed streams; `pumpAndSettle` alone won't wait for them).
- Look at screenshots with the Read tool. The Map tab shows "The server is not reachable right now…" unless the `backend/maps` emulators are running. That's expected locally.
- The Firebase Auth emulator banner is hidden on web by CSS + a MutationObserver in `web/index.html` (FlutterFire doesn't expose `disableWarnings`).

## Run on phones (local backend)

Start the backends on the Mac first (`backend/maps/scripts/dev.sh`, `backend/echo/scripts/dev.sh`; seed + replay per HANDOFF). Then from `mobile/app`, with the seeded event id:

- **Android (USB):** `adb reverse tcp:8080 tcp:8080` and the same for 8081, 8082, 8083, 9099, 9199, then `flutter run -d <device> --dart-define=DEMO_EVENT_ID=<id>`. `localhost` on the phone now reaches the Mac. Cleartext HTTP is allowed in the debug manifest only.
- **iPhone (same Wi-Fi):** `flutter run -d <device> --dart-define=DEMO_EVENT_ID=<id> --dart-define=EMULATOR_HOST=<mac LAN ip> --dart-define=API_BASE_URL=http://<mac LAN ip>:8080 --dart-define=ECHO_API_BASE_URL=http://<mac LAN ip>:8082` (+ `FIND_API_BASE_URL` once Find runs). The Go APIs listen on all interfaces, but the Firebase emulators bind to localhost, so forward `<ip>:8081/9099/9199` → `127.0.0.1` (e.g. `socat TCP-LISTEN:8081,bind=<ip>,fork TCP:127.0.0.1:8081`). Signing team is set in the Xcode project; iOS allows local networking (ATS `NSAllowsLocalNetworking`).
- **Deep links:** `eho://open/e/<id>` opens the installed app on both platforms (`adb shell am start -a android.intent.action.VIEW -d "eho://open/e/<id>"`, or paste in Safari). https links for `/e/<id>` need a hosting domain (board M-14).
- **GPS:** the seeded venue is georeferenced at a fictional spot (44.8000, 20.4000), so a real GPS dot lands off the plan anywhere else. Use the QR "you are here" (`?at=<markerId>`) until there's a demo location override (`mobile#14`).
