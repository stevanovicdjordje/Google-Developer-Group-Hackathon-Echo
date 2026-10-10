# Mobile task board

Single writer: the mobile orchestrator (`mobile/docs/WORKFLOW.md`). Statuses: `ready` · `blocked` (say on what) · `in progress` (agent, since) · `review` (branch waiting to merge) · `done` (commit).
Sizes: S < 30 min · M ~1 h · L multi-hour. Agent: `dev` = mobile-dev (Sonnet), `opus` = mobile-dev-opus.

**Hot files** (one running worker at a time): `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.

## Ready


| ID | Task | Size | Agent | Files (expected) | Notes |
| --- | --- | --- | --- | --- | --- |

## Blocked

| ID | Task | Blocked on |
| --- | --- | --- |
| M-10 | Design pass: apply the Claude Design result to `core/theme.dart` + screens | Human runs `/design-login` and makes the design himself. **Don't ask him again.** Then this becomes an opus task. |
| M-12 | Map tab against the live `backend/maps` (seeded event), incl. route + GPS dot + meeting-spot highlight | Go + Firebase CLI being installed by the human (Java 21 present). Then `cd backend/maps && make dev`, `make seed`, `--dart-define=DEMO_EVENT_ID=<seeded id>`. |
| M-13 | Wire real endpoints API-1…API-15 as they land | Backend has no owner yet (`mobile#5`) |
| M-14 | Android build on an emulator/device (`EMULATOR_HOST=10.0.2.2`) + Android App Links for `/e/{id}` | Hosting domain for assetlinks.json; Android SDK on the machine |

## In progress / review

| ID | Agent | Since | Branch | Notes |
| --- | --- | --- | --- | --- |
| M-11 | opus | 2026-10-11 00:58 | worktree | English UI (`product-ui-language` accepted): English default locale, all app strings into ARB (en template, sr kept compiling). Touches every screen: no parallel screen work. |

## Done

| ID | Task | Commit |
| --- | --- | --- |
| M-15 | maps#2: location permissions (Android fine/coarse, iOS when-in-use) | `3cee092` |
| M-9 | Meeting spot "Show" highlights the place with a "Meeting: <name>" pin (`highlightFeatureId`/`highlightLabel`); not yet seen against a live map | `8c675fa` |
| M-8 | Event switch: tab roots keyed by eventId so Find/Agenda state from event A never shows on event B (bug found + fixed, `event_switch_test.dart`) | `c2dd1f3` |
| M-7 | maps#1: map API base URL override in `main.dart`; Profile → For organizers (Create event, Edit venue map → `/o`); `/o` mounted in the router | `5535095` + router fix |
| M-6 | Echo polish: "Ask about this" menu on long-press, auto-scroll pauses + "Jump to live" | `64b2937` |
| M-5 | Tabs keep their state (`StatefulShellRoute.indexedStack`, placeholder branch locations) | `03cfe1f` |
| M-1 | Firebase emulator banner hidden on web (`web/index.html`) | `afcdcd7` |
| M-4 | Organizer flow widget test (review → publish → link/QR; extract via repo) | `cad9c08` |
| M-3 | Organizer review: edit-session sheet | `ba75856` |
| M-2 | Persist client state across reloads (shared_preferences, `data/local_store.dart`) | `095749b` |
| M-0 | Full app skeleton on demo data (all flows from `docs/MVP.md`) | `b72ca57` |
