# Eho app guide (for workers)

The one page a worker reads before touching `mobile/app/`. Keep it current: whoever changes the structure updates this file in the same commit.

## What the app is

Flutter (web + Android + iOS), one codebase. Attendees and organizers use the same app. Product: `docs/PRODUCT.md`. Demo plan, including what is mocked: `docs/MVP.md`. Everything except the venue map currently runs on **demo data**.

## Layout

```
mobile/
├── app/                      # the app shell — owned by `mobile`
│   ├── lib/
│   │   ├── main.dart         # Firebase init (non-blocking, 5 s timeout) → EhoApp
│   │   ├── app.dart          # MaterialApp.router, theme, l10n delegates
│   │   ├── core/
│   │   │   ├── router.dart   # ALL routes (see below)
│   │   │   ├── theme.dart    # the ONLY place for colors/typography
│   │   │   ├── api/api_client.dart   # HTTP client for real endpoints (Bearer Firebase token)
│   │   │   ├── config.dart, providers.dart, firebase/
│   │   ├── data/
│   │   │   ├── models.dart        # plain Dart models
│   │   │   ├── demo_data.dart     # hardcoded fake conference (names fictional)
│   │   │   ├── repositories.dart  # interfaces + Demo* implementations + providers
│   │   │   └── app_state.dart     # Riverpod Notifiers: profile, joined events, contacts, meeting spot, unlocked summaries, organizer draft
│   │   ├── features/<area>/       # screens, one folder per area
│   │   └── l10n/                  # ARB (sr template, en) — only the old dev screen uses it so far
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
| `/organizer` → `/review` → `/published?url&name` | Organizer upload / review / link+QR | `features/organizer/organizer_screens.dart` |
| `/e/:eventId` | `EventEntry`: join screen, or redirect to agenda (or map if `?at=`) | `core/router.dart`, `features/join/` |
| `/e/:eventId/{agenda,map,find,profile}` | Tabs inside `EventShell` (a `ShellRoute`; tab index from URL) | `features/event/event_shell.dart` + per-tab folders |
| `/e/:eventId/map/stand/:standId` | Map tab focused on a feature | `features/map/map_tab.dart` |
| `/e/:eventId/stand/:standId` | redirect → `/map/stand/…` (link format from `team-event-join`) | |
| `/e/:eventId/find/person/:personId?why=` | Person + contact | `features/find/find_screens.dart` |
| `/e/:eventId/session/:sessionId` (+ `/echo`) | Session detail, Echo | `features/agenda/`, `features/echo/echo_screen.dart` |
| `/e/:eventId/messages/:personId` | Messages (MOCK) + meeting spot | `features/find/find_screens.dart` |
| `/dev` | Backend/auth status (dev only) | `features/dev/` |

Use `context.go` for tab/top-level navigation and `context.push` for drill-down pages that should keep "back".

## Data

- Screens read data **only** through providers in `data/repositories.dart` (`eventRepositoryProvider`, `echoRepositoryProvider`, `findRepositoryProvider`, `organizerRepositoryProvider`) and the Notifiers in `data/app_state.dart`.
- Each interface method is tagged with an `[API-n]` ID from `mobile/docs/api-needs.md`. To wire a real endpoint: add an HTTP implementation using `ApiClient`, switch the provider, and leave the screens alone.
- Venue map data comes from `eho_maps` (`publishedEventProvider(eventId)` gives `PublishedEvent` with `map.features`). Stage names in demo data equal room names on the seeded map; the app links them **by name**.
- State is in memory: a web reload resets it.

## UI rules

- Colors and text styles only via `Theme.of(context)` (`colorScheme`, `textTheme`). No hex colors in screens (exception: white behind the QR code).
- Material 3 components. Phone-first: check 412 px width (no `RenderFlex overflowed`).
- UI text is currently English and hardcoded. Don't add ARB keys unless the task says so.

## Verifying

```bash
cd mobile/app
flutter pub get
flutter analyze             # must be "No issues found!"
flutter test                # all tests must pass
# screenshots (builds web first; each route is a fresh page load):
../scripts/shots.sh /tmp/eho-shots start=/ agenda=/e/devsummit/agenda echo=/e/devsummit/session/s1/echo
```

- Widget tests: follow `test/features/happy_path_test.dart`. Use a phone-sized `tester.view`, `pumpAndSettle` for navigation, and an extra `pump` after stream/async updates (Echo uses timed streams; `pumpAndSettle` alone won't wait for them).
- Look at screenshots with the Read tool. The Map tab shows "Server trenutno nije dostupan" unless the `backend/maps` emulators are running. That's expected locally.
- The red "Running in emulator mode" bar on web screenshots comes from the Firebase Auth emulator. It's a known item on the board.
