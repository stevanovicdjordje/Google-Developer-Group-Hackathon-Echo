# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, sixth orchestrator session. Done: M-57, M-59…M-63, V-8, V-9, R-1. Opened mobile#22 and mobile#23 (both done by feature:maps/find). R-2 running.

## Standing mandate from @Ilij4n (relayed by his coordinator session **eho-f7**; message it, not ilijan-72)

1. Work through `BOARD.md`, highest demo value first, in parallel where files don't overlap. Use Sonnet at medium effort (`model: sonnet`, `effort: medium`) for test/verify workers.
2. Wire teammates' contracts as they land. Don't wait for him; stop only for real 🧭 product decisions. Note defaults here.
3. **Don't touch the iPhone.** The **Galaxy A55** (`adb -s RZCX511WWLF`) is the test device **and now the recording phone**. Run one device worker at a time.
4. When context nears 200k: WORKFLOW §5 handoff, then `SendMessage` to `eho-f7`. It starts the successor.

## State in one paragraph

All demo flows run in `mobile/app` against all real backends, with demo fallback. V-8 on the Galaxy verified M-55/56/57/45/60/61/52 live. `flutter analyze` is clean and **232/232 tests** pass. The video now ends with the organizer **post-event report** (feature:onboarding, :8085, `docs/MVP.md` step 8).

## Recording prep (the current goal)

- **Galaxy:** a release APK (no debug banner).
  - Build: `flutter build apk --release --dart-define=EMULATOR_HOST=0.0.0.0 --dart-define=DEMO_EVENT_ID=devfest --dart-define=DEMO_LOCATION=44.799820,20.400025`
  - Install: `adb install -r`, then `pm clear rs.eho.eho`, then `pm grant … ACCESS_FINE_LOCATION`.
  - R-2 is rebuilding it with the new eho_maps first view (mobile#22).
  - adb reverse covers 8080–8084, 9099 and 9199. fwd6.py is PID 58985, started 07:10 from mobile/ by another session.
- **Seeds** (order matters):
  1. `cd backend/onboarding && make seed`. It also re-seeds maps and events.
  2. `cd backend/find && RESET=1 make seed`. This removes non-demo people and contacts.
  3. Echo replay: `cd backend/echo && make replay EVENT=devfest` (no `-instant`), **only when he says "record"**. The keynote lasts ~3.5 min at speed 2.
  4. Re-seed Events (`cd backend/events && EVENT=devfest make seed`) after any test publish.
- **Organizer report:** http://localhost:8085/org/events/devfest-report/report. Log in as organizer@eho.test / eho-demo-123.

## Local stack

- Firebase emulators on 127.0.0.1: node 84459, java 84497.
- maps :8080, Echo :8082 (the other session's process, leave it alone), Find :8083, Events :8084.
- Onboarding web :8085: started by session 6 with `make dev` (background); its log is in that session's scratchpad.
- Check with `lsof -nP -iTCP -sTCP:LISTEN`.

## In flight

- Nothing running. R-2 is done and the Galaxy is **ready to record**. Waiting for the human's "record", then start the Echo replay.

## Next up

1. After recording: anything the human or eho-f7 reports from the video.
2. Optional:
   - parse the server's `Draft.sourceFiles` into `EventDraft` (models.dart) instead of the persisted count (M-63 follow-up)
   - Events `hasMap`/`hasAgenda`
   - M-58 spinner check by eye (join takes <1.2 s, so it's hard to see)
   - Messages chat history is canned demo text even with live Find (no chat contract; fine for the demo).

## Defaults decided (no 🧭 needed; tell him if asked)

- Session 6: an organizer draft id and file count are persisted to resume after a restart; the id is cleared on any `getDraft` failure (also offline). Android release builds allow cleartext only to local hosts.

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
