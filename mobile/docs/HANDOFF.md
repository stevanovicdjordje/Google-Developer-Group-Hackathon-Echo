# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, fifth orchestrator session. Ran M-51 (stack restart), V-7, M-52…M-58, opened `mobile#20`; V-8 dispatched.

## Standing mandate from @Ilij4n (relayed by his other session "ilijan-72")

1. Work through `BOARD.md`, highest demo value first, in parallel where files don't overlap. Use Sonnet at medium effort (`model: sonnet`, `effort: medium`) for test/verify workers.
2. Wire teammates' contracts as they land. Don't wait for him; stop only for real 🧭 product decisions. Note defaults here.
3. **Don't touch the iPhone.** It still runs an old release build. He'll ask for a `devfest` rebuild. The **Galaxy A55** (`adb -s RZCX511WWLF`, `~/Library/Android/sdk/platform-tools/adb`) is a dedicated test device. Reinstall and clear it freely, one device worker at a time.
4. When context nears 200k: WORKFLOW §5 handoff, then `SendMessage` to `ilijan-72`. It starts the successor.

## State in one paragraph

All demo flows run in `mobile/app` on all four real backends, with demo fallback. **Verified e2e on the Galaxy against local `devfest` (V-7):**
- join, agenda, My events/leave
- Echo: ask ~6 s, translate sr
- map: you-are-here and route
- Find: search ~4 s, contact, spot
- organizer: upload → AI draft ~5 s → publish → attendee agenda

Fixes from V-7 are merged:
- M-54: integration_test 6/6 on the device again (harness timing)
- M-55: room-less sessions are clean in the agenda, and Publish with flagged rows asks first
- M-56: demo-only "AI Meetup Novi Sad" is hidden when Events is live
- M-58: Join spinner

Also merged:
- M-52: draft `issues` / publish `warnings`
- M-45: other person's meeting spot via `listContacts`
- M-53: dev shots `echo-answer`, `echo-jump-live`, `messages-spot-picker`

`flutter analyze` is clean, **201/201 tests**.

## Local stack (running since ~07:08, started by this session)

- Firebase emulators: the **old** processes (node 84459, java 84497) on 127.0.0.1, which survived the kill. Reused, not restarted, because `phone_android.sh`'s `fwd6.py` + adb reverse handle 127.0.0.1.
- maps API :8080: new code, `go run ./cmd/api` with the emulator env vars, not via `make dev`, which would start a second emulator set.
- Find :8083 and Events :8084: `make dev`, Gemini.
- Echo :8082: the other session's process (25634). Leave it alone.
- Logs: `/private/tmp/claude-501/-Users-ilijan-Developer-eho/3a9df22b-2784-4690-9927-259687df740a/scratchpad/stack/` (session scratchpad; it may be gone in a new session, so re-check with `lsof -nP -iTCP -sTCP:LISTEN`).
- Seeds: maps `devfest` (DEMO_LOCATION entrance `44.799820,20.400025`; walk entrance → Glavna sala `44.799820,20.400025;44.799820,20.400557;44.799910,20.400557`), Find 20 attendees, Events 7 sessions.
- **The Events agenda was re-seeded after V-7's test publish. V-8 publishes again, so re-seed after it:** `cd backend/events && EVENT=devfest make seed`.
- **Before recording the video:** `cd backend/echo && make replay EVENT=devfest` (no `-instant`) so `s1` is live in Echo. The previous replay ended, so Echo showed ENDED while the agenda shows LIVE. Also re-seed Find (`make seed`) to clear test contacts.

## In flight

- **V-8** (verifier, Sonnet medium): Galaxy re-check of M-52/55/56/58/45 on `devfest`. After it, re-seed Events (above) and fix whatever it finds.

## Next up

1. Act on V-8's findings.
2. **M-57** blocked on feature:maps `mobile#20` (`MapViewerScreen.locateOnOpen`, silent you-are-here on open). When it lands, one line in `map_tab.dart` + a widget test + a shot.
3. Optional:
   - dev shots seeded with draft issues / publish warnings (`dev_shot_routes.dart`, `_FlaggedDraft`)
   - feed the server's contact `state` from `listContacts` into `contactsProvider`
   - Events `getDraft`

## Defaults decided this session (no 🧭 needed; tell him if asked)

- Publishing with flagged rows is allowed, after a "Publish anyway / Review" dialog (the contract says issues don't block).
- Server issue messages are shown as sent (English); only the headings are localized.
- Demo-only events disappear from My events when the Events service is live. They stay in demo fallback.
- Kept from before: Echo translate keeps the chrome English; `devfest` `s1` is always live; organizer on emulator builds = demo organizer on a second Firebase app; Android back on Map/Find/Profile → Agenda.

## Human preferences (important)

- He types little and wants **simple, short** explanations and ready-to-use outputs. Only real decisions, as one-tap 🧭.
- The orchestrator doesn't implement; dispatch workers in parallel where files don't overlap.
- Mock only what's genuinely hard (`docs/MVP.md`). Models are chosen per feature: Gemini for Echo/Find/Events text, Gemma for translation. Don't misstate this in docs.

## Gotchas

- **Auto mode blocks `kill`** of running services. Ask the human (🙋 with an exact `! kill …`). Never ask another session to do it. Run `git worktree remove` as its own command.
- Integration tests on the device run very fast (the human sees the Start screen flash 5 times; that's normal). Flow tests must wait with `pumpUntil`/`waitForJoin` (`test/flows/flow_helpers.dart`) for anything with a real-time delay. `pumpAndSettle` alone returns early on a device.
- A verifier using the main checkout for a device build: hold merges until it's done, or have later workers merge the pending branch into their worktree first (as M-45 did with M-52).
- Usage limits kill workers mid-task. `SendMessage` to the same agent id resumes it.
- Briefs that scope only the data layer can't finish wiring. Include the hot files the flow needs when nobody else holds them, or do the one-line UI hookup yourself after the merge (as for M-45).
- Workers sometimes run `dart format` on files outside their scope. Check worktrees.
- ARB merges auto-merge fine. Always run `flutter gen-l10n` + analyze + test after a batch.
- The other @Ilij4n session works **in this same checkout** (phones, Echo backend). Never stage its files; `git pull --rebase=merges --autostash`.
- `shots.sh` builds with `USE_ECHO_API=false` by default and forwards `DEMO_EVENT_ID`, `LINK_BASE`, `DEMO_LOCATION`. Give each worker its own scratchpad subdir.
- eho_maps (`mobile/maps/`) is feature:maps, read-only. The viewer's GPS state is private, so any map behavior change is a request.
- Design source of truth: `mobile/docs/design/` (v1 + v2). The live canvas is private: don't fetch it.
- Kept from before: `StatefulShellRoute` placeholder branches (`/e/_/<tab>`, navigate with `context.go`, never `goBranch`); web Firebase init has a 5 s timeout; extra `pump` after Echo streams in widget tests.
