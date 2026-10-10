# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11 ~01:30, second orchestrator session (@Ilij4n). Ran batch 1 (M-1…M-8), then M-9 + M-15 (maps follow-ups).

## State in one paragraph

The whole demo flow from `docs/MVP.md` runs in `mobile/app` on demo data. Batch 1 added: state persisted across reloads (shared_preferences), tabs keep state (`StatefulShellRoute.indexedStack`, keyed by eventId), organizer session edit sheet, Echo "Ask about this" + "Jump to live", emulator banner hidden on web, Profile → For organizers (`/organizer`, map editor `/o` mounted from `eho_maps`), meeting spot shown as a labelled pin on the map (M-9), location permissions for native GPS (M-15). `flutter analyze` clean, 18/18 tests, verifier screenshots of 10 routes all OK. The venue map still hasn't been seen against a live backend on this machine. `feature:echo` (@MilosBG03) now owns the Echo server + contract (API-4…8, translation); the Echo screens stay with mobile and will switch to their API via `EchoRepository` once `contracts/echo/openapi.yaml` lands. Join/agenda/Find/organizer endpoints (rest of `mobile#5`) still have no backend owner.

## In flight

Nothing. No worker branches open.

## Waiting on the human (ask only if a ready task depends on it)

- 🧭 UI language for the video (Serbian or English) → unblocks M-11. (asked 2026-10-11 ~00:45, no answer yet)
- 🧭/🙋 Design: `/design-login`, then design in Claude Design → unblocks M-10. The human wants the design to build on the existing navigation skeleton. (asked 2026-10-11 ~00:45, no answer yet)
- 🙋 Install Go + Firebase CLI to see the Map tab with real data (M-12). (asked 2026-10-11 ~00:45, no answer yet)
- 🧭 Who owns the backend (stevanovicdjordje or the 4th teammate)? Not mobile's call, but blocks M-13.

## Waiting on teammates

- `mobile#5` (backend endpoints): no backend holder registered yet.
- feature:echo contract (`contracts/echo/openapi.yaml`): watch for it at each sync, then add a task to wire `EchoRepository` to it.

## Human preferences (important)

- The human types little and wants **simple, short** explanations and **ready-to-use** outputs. Do the heavy lifting; ask only real decisions, as one-tap 🧭 choices.
- Don't implement features in the orchestrator session. Dispatch to workers (Sonnet high by default, Opus medium for hard tasks), in parallel where files don't overlap.
- Mock only what's genuinely hard or needs heavy cross-module coordination (`docs/MVP.md`).
- AI models: chosen per feature, Gemma for translation (`docs/MVP.md`). Don't write repo docs that misstate which model a feature uses.

## Gotchas

- `git pull --rebase` after `git merge` of worker branches linearizes the merges (new hashes) if origin moved. Pull **before** merging a batch; record hashes after pushing. Old worker branches then need `git branch -D` (check with `git cherry main <branch>` first).
- shots.sh loads each route fresh, so it can't show sheets/menus or a draft set in a provider. Interactive states are covered by widget tests only.
- Worktrees branch from local `main`: commit before dispatching.
- `StatefulShellRoute` can't use `/e/:eventId/...` branch defaults (assertion). Since M-5 the branches use `/e/_/<tab>` placeholders that are never opened; navigate tabs with `context.go`, never `goBranch`.
- On web, Firebase init would hang without emulators. `main.dart` now has a 5 s timeout. Keep it.
- Headless Chrome needs the DevTools approach in `mobile/scripts/shots.py`; `chrome --screenshot` gives blank pages for Flutter.
- In widget tests, Echo's transcript is a timed stream: add an extra `pump` after `pumpAndSettle`.
