# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11 ~01:30, second orchestrator session (@Ilij4n). Ran batch 1 (M-1…M-8), M-9 + M-15 (maps follow-ups), M-11 (English UI), M-12 (live map verified), M-16 (QR flow through join).

## State in one paragraph

The whole demo flow from `docs/MVP.md` runs in `mobile/app` on demo data. Batch 1 added: state persisted across reloads (shared_preferences), tabs keep state (`StatefulShellRoute.indexedStack`, keyed by eventId), organizer session edit sheet, Echo "Ask about this" + "Jump to live", emulator banner hidden on web, Profile → For organizers (`/organizer`, map editor `/o` mounted from `eho_maps`), meeting spot shown as a labelled pin on the map (M-9), location permissions for native GPS (M-15), English UI with all strings in ARB (M-11, `product-ui-language`), QR `?at=` kept through join (M-16). Map tab verified against the live `backend/maps` (M-12). 20/20 tests. `flutter analyze` clean, 18/18 tests, verifier screenshots of 10 routes all OK. The venue map still hasn't been seen against a live backend on this machine. `feature:echo` (@MilosBG03) now owns the Echo server + contract (API-4…8, translation); the Echo screens stay with mobile and will switch to their API via `EchoRepository` once `contracts/echo/openapi.yaml` lands. Join/agenda/Find/organizer endpoints (rest of `mobile#5`) still have no backend owner.

## In flight

Nothing. No worker branches open. The maps emulators + API may still be running from this session (`backend/maps/scripts/dev.sh`, port 8080); check `curl -s localhost:8080/healthz` before starting another.

## Next up

- M-10 design pass as soon as the human has a design (opus; touches `core/theme.dart` + all screens: no parallel screen work).
- Wire `EchoRepository` to `contracts/echo/openapi.yaml` when feature:echo publishes it.
- M-17 demo-event naming, together with the demo-video script.

## Waiting on the human (ask only if a ready task depends on it)

- Design (M-10): the human runs `/design-login` and makes the design himself. **Don't ask him about it again.** He wants it to build on the existing navigation skeleton.
- 🧭 Who owns the backend (stevanovicdjordje or the 4th teammate)? Not mobile's call, but blocks M-13.

## Waiting on teammates

- `mobile#5` (backend endpoints): no backend holder registered yet.
- `mobile#7` (feature:maps: English map screens for the video): open.
- feature:echo contract (`contracts/echo/openapi.yaml`): watch for it at each sync, then add a task to wire `EchoRepository` to it.

## Human preferences (important)

- The human types little and wants **simple, short** explanations and **ready-to-use** outputs. Do the heavy lifting; ask only real decisions, as one-tap 🧭 choices.
- Don't implement features in the orchestrator session. Dispatch to workers (Sonnet high by default, Opus medium for hard tasks), in parallel where files don't overlap.
- Mock only what's genuinely hard or needs heavy cross-module coordination (`docs/MVP.md`).
- AI models: chosen per feature, Gemma for translation (`docs/MVP.md`). Don't write repo docs that misstate which model a feature uses.

## Gotchas

- Design source of truth = the repo copy `mobile/docs/design/` (v1 + v2, README). The live canvas is private to the human's old Claude account: don't fetch it. A later re-export = new design version: diff frames, add board tasks.
- Live map locally: `cd backend/maps && ./scripts/dev.sh` (emulators + API :8080), then `make seed` with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199 FIREBASE_PROJECT_ID=demo-eho`; it prints the eventId (2026-10-11: `v7y6hpytx3iyhhvd`, kept in the git-ignored `.emulator-data`). App: `DEMO_EVENT_ID=<id> mobile/scripts/shots.sh …` (config defaults already point at localhost:8080 + emulators). Quote `?at=` args in zsh.
- Use `git pull --rebase=merges --autostash` after merging worker branches: it keeps merge commits and their hashes.
- `git pull --rebase` after `git merge` of worker branches linearizes the merges (new hashes) if origin moved. Pull **before** merging a batch; record hashes after pushing. Old worker branches then need `git branch -D` (check with `git cherry main <branch>` first).
- shots.sh loads each route fresh, so it can't show sheets/menus or a draft set in a provider. Interactive states are covered by widget tests only.
- Worktrees branch from local `main`: commit before dispatching.
- `StatefulShellRoute` can't use `/e/:eventId/...` branch defaults (assertion). Since M-5 the branches use `/e/_/<tab>` placeholders that are never opened; navigate tabs with `context.go`, never `goBranch`.
- On web, Firebase init would hang without emulators. `main.dart` now has a 5 s timeout. Keep it.
- Headless Chrome needs the DevTools approach in `mobile/scripts/shots.py`; `chrome --screenshot` gives blank pages for Flutter.
- In widget tests, Echo's transcript is a timed stream: add an extra `pump` after `pumpAndSettle`.
