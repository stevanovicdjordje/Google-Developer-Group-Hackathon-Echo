# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, fourth orchestrator session. Ran M-43, M-44, V-6, M-46…M-50, M-13. A usage limit interrupted M-46…49 at ~05:00; all resumed and merged.

## Standing mandate from @Ilij4n (relayed by his other session "ilijan-72")

1. Work through `BOARD.md`, highest demo value first, in parallel where files don't overlap. Use Sonnet at medium effort (`model: sonnet`, `effort: medium`) for test/verify workers.
2. Wire teammates' contracts as they land. Don't wait for him; stop only for real 🧭 product decisions. Note defaults here.
3. **Don't touch the iPhone.** It still runs an old release build on event `ik6vmvjr7wlektj6`. He'll ask for a `devfest` rebuild when he's up. The **Galaxy A55** (`adb -s RZCX511WWLF`, `~/Library/Android/sdk/platform-tools/adb`) is a dedicated test device. Reinstall and clear it freely, one worker at a time.
4. When context nears 200k: WORKFLOW §5 handoff, then `SendMessage` to `ilijan-72`. It starts the successor.

## State in one paragraph

All demo flows run in `mobile/app` in the human's design with an English UI. **All four backends are wired with demo fallback:**
- Echo: contract 0.3.1, verified e2e.
- Maps: `eho_maps`, verified e2e.
- Find: contract 0.2.0, verified e2e via the API (M-37). Meeting `time` is sent and read (M-43).
- **Events:** contract 0.1.0 (M-13). Covers join, agenda, My events, leave, and organizer upload with bytes → AI draft → saves → publish into `devfest`. Mapping tests only; **not e2e yet**.

Polish from the Galaxy pass V-6 is merged: status bar (M-46), Find/Person (M-47), Echo translate (M-48), sheets over the nav + Android back (M-49), friendly join errors (M-50). `flutter analyze` is clean, **176/176 tests**. `DEMO_LOCATION` (pretend GPS) is forwarded by `phone_android.sh`/`shots.sh` (M-44). `phone_android.sh` also reverses 8084.

## Blocked: stack restart (M-51), then V-7

The local stack still runs the **old** setup: emulators on 127.0.0.1 with old maps API code, Find offline-ranking, no Events. @Vertiglo's new setup:
- stable event id `devfest` (re-seeding keeps it)
- emulators on `::`/0.0.0.0, so no forwarders are needed
- Find on Gemini with an 8 s timeout
- Events on :8084

`backend/maps` `make seed` **fails against the old API** (500 deleting the old event), so a restart is required. Auto mode **denied this session killing processes** ("Interfere With Workloads"). I asked the human (🙋) to run:
```
! kill 1771 36443 84453 84499 84510 24520 24528 24545
```
Those are:
- 1771: the other session's LAN forwarder
- 36443: the V-5 `::1` forwarder
- 84453/84499/84510: maps `dev.sh` + go run + API; dev.sh's trap stops the emulators, which export to `.emulator-data`
- 24520/24528/24545: Find `dev.sh` + go run + API

Leave Echo (25625/25630/25634, :8082) alone. If he runs it, or the PIDs changed (re-check with `lsof -nP -iTCP -sTCP:LISTEN`), then:
1. `cd backend/maps && make dev` (background, `nohup`, log to the scratchpad), then `make seed` → note the `DEMO_LOCATION` values it prints.
2. `cd backend/echo && make replay EVENT=devfest`. Use no `-instant` for the video, so `s1` is live. The app shows `devfest` `s1` live anyway (M-13).
3. `cd backend/find && make dev` (it reads `.env`; `GEMMA_MODEL` there is ignored now, and `AI_MODEL` defaults to `gemini-3-flash-preview`), then `make seed`.
4. `cd backend/events && make dev` (`.env` **already created** from the example with the key; git-ignored, never print it), then `make seed`.
5. Dispatch **V-7** (verifier, Sonnet medium). Spec is on the board: Galaxy with `DEMO_EVENT_ID=devfest DEMO_LOCATION=…`, `integration_test/`, live smoke incl. organizer upload of `backend/events/demo/*` (organizer = `organizer@eho.test` / `eho-demo-123`, auto sign-in on emulator builds) and publish, re-check M-46 on the device.

## In flight

Nothing. No worker branches open.

## Next up (after V-7)

1. Fix whatever V-7 finds. Then update `mobile/STATUS.md` *Contract coverage*: events → verified e2e.
2. Optional: wire Events `getDraft`, draft `issues` and publish `warnings`. Today the review flags only sessions with no stage itself.
3. M-45 (low): the other person's meeting spot via `listContacts`.
4. Before recording the video: re-seeding on `devfest` cleans the test leftovers V-6 saw (a duplicate Q&A question; "Dev Tester"/"Ilija" in Find). The map title comes from the seed name.

## Defaults decided this session (no 🧭 needed; tell him if asked)

- Echo with translate on: **chrome stays English**, only content (transcript, answers, catch-up, summary) is Serbian (M-48, per `product-ui-language`).
- `devfest` keynote `s1` always shows live (demo script), other events by time (M-13).
- Organizer on emulator builds signs in as the demo organizer on a second Firebase app, so the attendee's anonymous user is kept (M-13).
- Android back on Map/Find/Profile → Agenda (M-49).

## Human preferences (important)

- He types little and wants **simple, short** explanations and ready-to-use outputs. Only real decisions, as one-tap 🧭.
- The orchestrator doesn't implement; dispatch workers in parallel where files don't overlap.
- Mock only what's genuinely hard (`docs/MVP.md`). Models are chosen per feature: Gemini for Echo/Find/Events text, Gemma for translation. Don't misstate this in docs.

## Gotchas

- **Auto mode blocks `kill`** of running services, and sometimes `git worktree remove` when chained with `lsof`. Run worktree cleanup as its own command.
- Usage limits kill workers mid-task. `SendMessage` to the same agent id resumes it. If its worktree vanished, it recreates one (tell it to branch off local main, never work in the main checkout).
- Briefs that scope only the data layer can't finish wiring (M-43 needed `repositories.dart`/`app_state.dart`). Include the hot files the flow needs when nobody else holds them.
- Workers sometimes run `dart format` on files outside their scope. If left uncommitted in a worktree, verify it's whitespace-only.
- ARB merges auto-merge fine. Always run `flutter gen-l10n` + analyze + test after a batch.
- The other @Ilij4n session works **in this same checkout** (phones, Echo backend). Never stage its files; `git pull --rebase=merges --autostash`.
- `shots.sh` builds with `USE_ECHO_API=false` by default and forwards `DEMO_EVENT_ID`, `LINK_BASE`, `DEMO_LOCATION`. Give each worker its own scratchpad subdir.
- Design source of truth: `mobile/docs/design/` (v1 + v2). The live canvas is private: don't fetch it.
- Kept from before: `StatefulShellRoute` placeholder branches (`/e/_/<tab>`, navigate with `context.go`, never `goBranch`); web Firebase init has a 5 s timeout; extra `pump` after Echo streams in widget tests.
