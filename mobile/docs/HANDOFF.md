# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, second orchestrator session (@Ilij4n): batch 1 (M-1…M-9, M-11, M-12, M-15, M-16), Echo on the real API (M-18, M-21), the full design pass (M-10a–g, M-20), DevFest rename (M-17).

## State in one paragraph

The whole demo flow runs in `mobile/app` in the human's design (`mobile/docs/design/`, v1 + v2; theme tokens + bundled fonts in `core/theme.dart`, shared widgets in `core/ui/`), English UI with every string in ARB. Demo event: "DevFest Belgrade 2026" (`devfest`; old `devsummit` links alias). Echo runs on the real Echo API (feature:echo, contract 0.3.0: Firestore transcript, catch-up, ask, Q&A with votes + merged questions, structured summary with time links, Serbian via `language=sr`), demo data as fallback. The Map tab runs on the live maps backend (seeded event `v7y6hpytx3iyhhvd`): plan, `?at=` dot, routes, meeting-spot highlight. `flutter analyze` clean, 60/60 tests. Join/agenda/Find/organizer still on demo data: no backend owner (`mobile#5`).

## In flight

Nothing. No worker branches open. The maps emulators + API may still be running from this session (`backend/maps/scripts/dev.sh`, port 8080); check `curl -s localhost:8080/healthz` before starting another.

## Next up

- M-19 map detail sheet when feature:maps answers `mobile#8`; apply their `mobile#10` polish when it lands (nothing for mobile to do unless the API changes).
- After feature:echo renames the replay event (`mobile#11`) and maps renames the seed (`mobile#10`): re-seed (`make seed`), re-run `make replay`, rebuild with the new `DEMO_EVENT_ID`, and do a full demo run-through with a verifier (Echo overlays, meeting spot pin, QR flow).
- Before the video: run Echo with `GEMINI_API_KEY` on the Echo service (otherwise answers are extractive and English).

## Waiting on the human (ask only if a ready task depends on it)

- Design: done and applied. If he re-exports the canvas into `mobile/docs/design/`, treat it as a new version (diff frames, add tasks).
- 🧭 Who owns the backend (stevanovicdjordje or the 4th teammate)? Not mobile's call, but blocks M-13.

## Waiting on teammates

- `mobile#5` (backend endpoints): no backend holder registered yet.
- `mobile#8` (maps: route to the selected stage + app-provided sheet content → M-19), `mobile#10` (maps: DevFest seed name, map chrome + `/o` polish), `mobile#11` (echo: DevFest replay name): open.

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
