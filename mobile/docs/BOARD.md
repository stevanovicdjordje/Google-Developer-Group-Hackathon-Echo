# Mobile task board

Single writer: the mobile orchestrator (`mobile/docs/WORKFLOW.md`). Statuses: `ready` · `blocked` (say on what) · `in progress` (agent, since) · `review` (branch waiting to merge) · `done` (commit).
Sizes: S < 30 min · M ~1 h · L multi-hour. Agent: `dev` = mobile-dev (Sonnet), `opus` = mobile-dev-opus.

**Hot files** (one running worker at a time): `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.

## Ready

| ID | Task | Size | Agent | Files (expected) | Notes |
| --- | --- | --- | --- | --- | --- |
| M-1 | Hide the Firebase "Running in emulator mode" bar on web | S | dev | `lib/core/firebase/` | It ruins video frames. Firebase JS `connectAuthEmulator(..., {disableWarnings: true})`; check how FlutterFire exposes it, else hide via CSS in `web/index.html`. |
| M-2 | Persist client state across reloads (profile, joined events, contacts, meeting spot, unlocked summaries) | M | dev | `data/app_state.dart`, `pubspec.yaml` (shared_preferences) | Web reload currently resets everything; a deep link opened in a new tab loses the joined state. **Hot files.** |
| M-3 | Organizer review: make the ✏️ on a session open a simple edit sheet (title, time, stage) | S | dev | `features/organizer/organizer_screens.dart`, `data/models.dart` (copyWith) | Today the icon does nothing. Touches a hot file only if `copyWith` is needed. |
| M-4 | Widget test for the organizer flow (upload → extract → review → publish → link screen) | S | dev | `test/features/organizer_flow_test.dart` | FilePicker can't run in tests: add a test seam (e.g. inject picked files) or start the test from `/organizer/review` with a draft in `organizerDraftProvider`. |
| M-5 | Keep each tab's state when switching tabs (scroll, Find results) | M | opus | `core/router.dart`, `features/event/event_shell.dart` | `StatefulShellRoute` failed because branch default locations can't contain `:eventId`. Options: branch `initialLocation` built from the current event, or keep `ShellRoute` + `PageStorageKey`s. **Hot file.** |
| M-6 | Echo polish: "Ask about this" chip when long-pressing a line (today it silently pre-fills the input); auto-scroll pauses when the user scrolls up | S | dev | `features/echo/echo_screen.dart` | |

## Blocked

| ID | Task | Blocked on |
| --- | --- | --- |
| M-10 | Design pass: apply the Claude Design result to `core/theme.dart` + screens | 🧭 Human: run `/design-login`, make the design in Claude Design. Then this becomes an opus task. |
| M-11 | Language of the UI for the video (Serbian/English) + move strings to ARB | 🧭 Human decides the language. |
| M-12 | Map tab against the live `backend/maps` (seeded event) + meeting-spot highlight | 🙋 Go + Firebase CLI on the machine (`brew install go firebase-cli`); `mobile#6` answer from feature:maps |
| M-13 | Wire real endpoints API-1…API-15 as they land | Backend has no owner yet (`mobile#5`) |
| M-14 | Android build on an emulator/device (`EMULATOR_HOST=10.0.2.2`) + Android App Links for `/e/{id}` | Hosting domain for assetlinks.json; Android SDK on the machine |

## In progress / review

| ID | Agent | Since | Branch | Notes |
| --- | --- | --- | --- | --- |
| — | | | | |

## Done

| ID | Task | Commit |
| --- | --- | --- |
| M-0 | Full app skeleton on demo data (all flows from `docs/MVP.md`) | `b72ca57` |
