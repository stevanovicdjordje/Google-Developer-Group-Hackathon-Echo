# Mobile task board

Single writer: the mobile orchestrator (`mobile/docs/WORKFLOW.md`). Statuses: `ready` · `blocked` (say on what) · `in progress` (agent, since) · `review` (branch waiting to merge) · `done` (commit).
Sizes: S < 30 min · M ~1 h · L multi-hour. Agent: `dev` = mobile-dev (Sonnet), `opus` = mobile-dev-opus.

**Hot files** (one running worker at a time): `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.

## Ready


| ID | Task | Size | Agent | Files (expected) | Notes |
| --- | --- | --- | --- | --- | --- |
| M-10d | Design: Echo screen | M | dev | `features/echo/` | After M-10a **and M-18** (both touch Echo). `Echo.dc.html` |
| M-17 | Demo-event name: join screen/agenda say "DevSummit Belgrade 2026" while the map event is "Eho Demo Expo" | S | — | — | Cosmetic. Decide with the design pass / demo script; maybe ask feature:maps to seed the same name. |

## Blocked

| ID | Task | Blocked on |
| --- | --- | --- |
| M-13 | Wire real endpoints API-1…API-15 as they land | Backend has no owner yet (`mobile#5`) |
| M-14 | Android build on an emulator/device (`EMULATOR_HOST=10.0.2.2`) + Android App Links for `/e/{id}` | Hosting domain for assetlinks.json; Android SDK on the machine |

## In progress / review

| ID | Agent | Since | Branch | Notes |
| --- | --- | --- | --- | --- |
| M-10b | dev | 2026-10-11 01:26 | worktree | Design: Start, Join, Onboarding, My events |
| M-10c | dev | 2026-10-11 01:26 | worktree | Design: Agenda + session detail |
| M-10e | dev | 2026-10-11 01:26 | worktree | Design: Find, person, Messages + meeting spot |
| M-10f | dev | 2026-10-11 01:26 | worktree | Design: Profile + Map tab chrome + event shell nav |
| M-10g | dev | 2026-10-11 01:26 | worktree | Design: Organizer upload/review/published |
| M-18 | opus | 2026-10-11 01:16 | worktree | echo#1: wire `EchoRepository` to the Echo API (`backend/echo`, :8082) + Firestore transcript; demo repo stays the fallback |

## Done

| ID | Task | Commit |
| --- | --- | --- |
| M-10a | Design foundation: theme tokens (`EhoColors`, `context.eho`), bundled Bricolage Grotesque + Instrument Sans, component themes, `core/ui/` widgets | `9fc22c1` |
| M-16 | QR flow: `/e/{id}?at=` survives join + onboarding → `/e/{id}/map?at=` (`qr_join_test.dart`). Note: `/e/{id}/stand/{id}` still opens the map without the join screen (fine for the demo) | `89c6163` |
| M-11 | English UI by default (`locale: en`), 138 strings in ARB (en template + sr), `product-ui-language` | `35ffbd5` |
| M-12 | Live map verified on this machine (seed `v7y6hpytx3iyhhvd`): Map tab renders the plan, `/map?at=` shows "Vi ste ovde", route API 52 m/43 s, all demo meeting-spot names match seeded features, `/o` login renders. Not tapped through in-app: route button, meeting-spot pin | verification only |
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
