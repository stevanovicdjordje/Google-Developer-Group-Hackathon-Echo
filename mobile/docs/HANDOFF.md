# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, second orchestrator session (@Ilij4n), ended at the human's request (context limit). Ran M-1…M-12, M-15…M-18, M-20…M-22, the full design pass M-10a–g, V-2.

## State in one paragraph

The whole demo flow runs in `mobile/app` in the human's design (`mobile/docs/design/`, v1 + v2; theme tokens + bundled fonts in `core/theme.dart`, shared widgets in `core/ui/`), English UI with every string in ARB. Demo event: "DevFest Belgrade 2026" (`devfest`; old `devsummit` links alias). Echo runs on the real Echo API (feature:echo @MilosBG03, contract 0.3.0: Firestore transcript, catch-up, ask, Q&A with votes + merged questions, structured summary with time links, Serbian via `language=sr`), demo data as fallback. The Map tab runs on the live maps backend (seeded event `v7y6hpytx3iyhhvd`): plan, `?at=` dot, routes, meeting-spot highlight. `flutter analyze` clean, 64/64 tests (HEAD `4ceb68d`). A non-emulator build takes real Firebase options from `--dart-define` (`FIREBASE_*`, M-22 / maps#3 done; no real project exists yet). Still on demo data: Find (feature:find now @Vertiglo, `team-find-holder`, `mobile#12`; wire when `contracts/find/openapi.yaml` lands = M-23) and the Events backend (API-1, 2, 3, 12, 13, 14: join, agenda, organizer import/publish) which has **no owner**.

## In flight

Nothing. No worker branches open. The maps emulators + API may still be running from this session (`backend/maps/scripts/dev.sh`, port 8080); check `curl -s localhost:8080/healthz` before starting another.

## Next up (priority order — start here)

1. **Sync** (`docs/COORDINATION.md` §3) and handle whatever landed: `mobile#8` (maps → unblocks M-19), `mobile#10`/`mobile#11` (paired DevFest rename of the map seed + Echo replay; the replay finds the event **by name**, so both must change together), `contracts/find/openapi.yaml` (→ M-23).
2. **M-24 (ready, dev/opus): dev-only state routes for screenshots**, e.g. `/dev/shot/<state>` that renders Echo Q&A sheet, paywall, summary, translated view, Person contact states, Messages with a meeting-spot card, My events live card, organizer review/published with a draft. Reason: `shots.sh` loads fresh pages, so these states have never been visually checked against the design (V-2 gap). Touches `core/router.dart` (hot) + a new `features/dev/` file; guard behind a `DEV_ROUTES` define (default on in debug/demo builds is fine).
3. **V-3 (verifier) after M-24:** screenshot every state vs. `mobile/docs/design/` (v2 frames EchoQA/EchoEnded/EchoSummary/EchoTranslated/Person/FindResults/MapDetail) and turn gaps into tasks.
4. **When the rename lands:** re-seed (`cd backend/maps && make seed` with the emulator env vars from Gotchas), re-run Echo `make replay` (needs GNU `timeout`? an M-21 worker saw macOS lacking it — check the Makefile), rebuild with the new `DEMO_EVENT_ID`, full hero-flow run-through with a verifier.
5. **M-19** map detail sheet once `mobile#8` lands; **M-23** Find wiring once the Find contract lands.
6. Small cleanups (S, dev): migrate persisted joined event `devsummit` → `devfest` in `LocalStore`; hide or soften the session page's "Echo is on" card for talks without a transcript (V-2 noticed it on non-live talks).
7. Before the video: Echo service with `GEMINI_API_KEY` (🙋 the human sets it on the Echo service; otherwise answers are extractive and English).

Not mobile's to start: Events backend owner (API-1, 2, 3, 12, 13, 14) — `coord(integration): help wanted` is out; M-13 waits for it. Android (M-14) waits for an Android SDK + hosting domain.

## Waiting on the human (ask only if a ready task depends on it)

- Design: done and applied. If he re-exports the canvas into `mobile/docs/design/`, treat it as a new version (diff frames, add tasks).
- Events backend owner (API-1, 2, 3, 12, 13, 14): unowned; the integration session posted help-wanted. Not mobile's call; blocks M-13.
- Real Firebase project: 🙋 only when someone actually deploys (M-22 is ready for it).

## Waiting on teammates

- `mobile#5` (rest of the backend endpoints): Echo part done by feature:echo; Find part → feature:find (@Vertiglo, `mobile#12`); Events part unowned.
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
