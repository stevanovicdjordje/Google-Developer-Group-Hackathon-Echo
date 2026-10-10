# Mobile task board

Single writer: the mobile orchestrator (`mobile/docs/WORKFLOW.md`). Statuses: `ready` · `blocked` (say on what) · `in progress` (agent, since) · `review` (branch waiting to merge) · `done` (commit).
Sizes: S < 30 min · M ~1 h · L multi-hour. Agent: `dev` = mobile-dev (Sonnet), `opus` = mobile-dev-opus.

**Hot files** (one running worker at a time): `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.

## Ready

Nothing ready: batch 1 (M-1…M-7) dispatched in parallel.

| ID | Task | Size | Agent | Files (expected) | Notes |
| --- | --- | --- | --- | --- | --- |

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
| M-1 | dev | 2026-10-11 00:40 | worktree | Hide Firebase emulator bar on web |
| M-2 | dev | 2026-10-11 00:40 | worktree | Persist client state (shared_preferences) |
| M-3 | dev | 2026-10-11 00:40 | worktree | Organizer session edit sheet |
| M-4 | dev | 2026-10-11 00:40 | worktree | Organizer flow widget test |
| M-5 | opus | 2026-10-11 00:40 | worktree | Keep tab state across tab switches |
| M-6 | dev | 2026-10-11 00:40 | worktree | Echo polish (ask chip, scroll pause) |
| M-7 | dev | 2026-10-11 00:40 | worktree | maps#1 (b)+(c): maps base URL + Profile → /o |

## Done

| ID | Task | Commit |
| --- | --- | --- |
| M-0 | Full app skeleton on demo data (all flows from `docs/MVP.md`) | `b72ca57` |
