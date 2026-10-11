# Mobile task board

Single writer: the mobile orchestrator (`mobile/docs/WORKFLOW.md`). Statuses: `ready` · `blocked` (say on what) · `in progress` (agent, since) · `review` (branch waiting to merge) · `done` (commit).
Sizes: S < 30 min · M ~1 h · L multi-hour. Agent: `dev` = mobile-dev (Sonnet), `opus` = mobile-dev-opus.

**Hot files** (one running worker at a time): `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.

## Ready


| ID | Task | Size | Agent | Files (expected) | Notes |
| --- | --- | --- | --- | --- | --- |
| M-38 | Echo screen: the "Full talk summary / Premium" banner overlaps/clips the top transcript line on ended talks (V-4a echo.png) | S | dev | `features/echo/` | |
| M-34 | Re-seed emulators so the event is "DevFest Belgrade 2026" (current `ik6vmvjr7wlektj6` is still "Eho Demo Expo"), `make replay` in backend/echo, record new DEMO_EVENT_ID in HANDOFF | S | orchestrator | none | Only after the human finishes click-testing on :5070 (re-seed deletes the old event) — ask first |

## Blocked

| ID | Task | Blocked on |
| --- | --- | --- |
| M-13 | Wire real endpoints API-1…API-15 as they land | Backend has no owner yet (`mobile#5`) |
| M-14 | https App Links / Universal Links for `/e/{id}` (assetlinks.json / apple-app-site-association) | Hosting domain. Phones themselves run (`9dbd308`: `eho://open/e/{id}`, Android + iPhone 13 Pro Max on the local backends) |

## In progress / review

| ID | Agent | Since | Branch | Notes |
| --- | --- | --- | --- | --- |
| V-5 | dev (sonnet, medium) | now | worktree | Galaxy A55 (`RZCX511WWLF`): integration_test of 5 flows + live adb smoke (one device worker at a time; iPhone off-limits) |
| M-39 | dev (sonnet, medium) | now | worktree | Find profile-required → Complete profile; retryAfter; `find-live` shot |
| M-38 | dev (sonnet, medium) | now | worktree | Echo banner overlap |

## Done

| ID | Task | Commit |
| --- | --- | --- |
| B-1 | Echo Gemini timeouts: `gemini-3.8-flash`/`3.7-flash` hung on Google's side; Echo now `AI_MODEL=gemini-3-flash-preview` (ask en 4.5 s / sr 2.4 s), translate stays Gemma (other @Ilij4n session) | `3bfd0b7` |
| M-26 | Echo on real AI end to end: Gemini (`gemini-3-flash-preview`) for ask/catch-up/summary/grouping, Gemma for translate; app sends `language` per 0.3.1, shows no model name | verification + `3bfd0b7` |
| M-37 | Find e2e (API): profile → joinFind → recs → search → person → contact (auto-accept) → meeting spot "Info pult" all 200 and parse-compatible with `find_api_repository.dart`; 429 not reproducible. App: fresh profile dead-ends on "Finish your profile" + Try again → M-39 | verification |
| V-4b | Tap-through flow tests `test/flows/` (deep link→join→onboarding→agenda; Echo ask/translate/Q&A/paywall/summary; map stage sheet + spot banner; Find→person→contact→messages→spot; organizer upload→review→publish). All pass on demo data; no app bugs. Live map pins/route not covered | `c9ad750` |
| V-4a | Live flows on web vs local backends: join, agenda, session, Echo transcript, map + you-are-here, stand sheet (400 seats, 1 min / 52 m, NOW, Start route, Open Echo), Find (demo), messages, organizer, published all OK. Echo API: translate sr (Gemma) OK, questions/votes OK; ask/catch-up/summary 502 (B-1). App↔contract: no mismatch | verification |
| M-35 | Agenda "<event> · Day N" (N=1: no day data in models), "Live · Day {day}", Profile "Premium" badge, demo extract flags s3, alias cleanup in repositories.dart, shots.sh forwards `LINK_BASE` | `e693bc1` |
| M-36 | Find error strings (`findError*`, `personNotAccepting` hint), recommendations reload debounced 2 s and only on ranking fields; joinFind stays lazy (fires on Find tab open) | `2bcd600` |
| P-1 | Run on phones (other @Ilij4n session): Galaxy A55 via `adb reverse`, iPhone via LAN + port forward for emulators; eho:// deep links; APP_GUIDE *Run on phones* | `9dbd308` |
| M-23 | Find on contract 0.1.1 (`data/find_api_repository.dart`, health-check fallback to demo; `USE_FIND_API`, `FIND_API_BASE_URL`), `PersonDetail`, contact state stream, `MeetingSpotNotifier.agree` → `putMeetingSpot`; 15 mapping tests on the fixtures. Not e2e (service down) | `0f11f3d` |
| M-31 | Organizer: "✦ Extracted from N files", short join link (`LINK_BASE` define, else host), "Copy", upload shots `organizer-upload-files`/`-progress`; dev shots use new demo data (fit line, Info pult 15:20, seeded questions) | `64be061` |
| M-33 | Stand links keep `?at=` → map `markerId`; `data/demo_ids.dart` `demoEventAliases`; saved `devfest`/`devsummit` joins migrate to `DEMO_EVENT_ID` (`demoEventIdProvider`). Left: repositories.dart private `_legacyDemoEventId` → use `demoEventAliases` (M-35) | `96e428c` |
| M-30 | Find/Person/Messages: natural fit lines + canned prompt results (Mara as speaker), top-3 recs, caption one line, Person without bottom nav (`event_shell.dart`), Messages "Matched on …" + spot "15:20 · Ground floor" (`MeetingSpot.time/floor`, app-only), 12 Echo demo questions | `59d3507` |
| M-19 | Map stage sheet (MapDetail v2): room + capacity + floor, walk time from route, NOW/NEXT session → session page, Start route, Open Echo (live only); non-stage places keep the default sheet. Live shots of Glavna sala / Sala A / Info pult | `66c037b` |
| M-28 | Echo: catch-up preview, neutral ended pill, paywall doc icon, share icon + computed read time, shots `echo-qa-own`/`echo-selected`, shots.sh `USE_ECHO_API` default false. Kept: live line untinted (frame tints only the selected line), share still copies (no share_plus) | `a9dcf10` |
| M-29 | Session (header row + bookmark, AI TRACK, Open Echo, pinned Map), Start tagline, My events (Happening now, Live · Day 1, leave menu only on past cards), Profile one "For organizers" row + sheet, Onboarding "1 of 3" | `fc3410d` |
| M-32 | `/e/devfest|devsummit/...` redirect to `/e/<DEMO_EVENT_ID>/...` (path + query kept; no-op by default); live: Echo transcript + map on `/e/devfest` | `37e3170` |
| M-26b | App on real Echo: `/e/<backend id>/session/s1/echo` shows the server transcript; app sends `language` per echo 0.3.1; no model name in the UI. Bug: `/e/devfest/...` ignores `DEMO_EVENT_ID` → M-32 | verification |
| V-3 | Every state vs design: no errors/overflow; all match or minor gaps → M-28…M-31. Screenshots/renders in the session scratchpad (not kept) | verification |
| M-24 | `/dev/shot/<state>` (14 states + index) behind `DEV_ROUTES` (default on); `EchoScreen.startTranslated`, `FindScreen.initialPrompt` hooks. Not covered: Echo AI-answer card, Jump-to-live, organizer edit sheet, spot-picker sheet | `8b358ea` |
| M-25 | Saved `devsummit` joined event migrates to `devfest` (deduped, written back once); session "Echo is on" card only when `Session.isLive`. Follow-up: export the legacy id from repositories.dart; a `hasEcho` flag if past talks with transcripts should show it | `600a12c` |
| M-22 | maps#3: `USE_EMULATORS=false` builds take `FIREBASE_API_KEY`/`APP_ID`/`PROJECT_ID` (+ optional sender id, auth domain, storage bucket) from `--dart-define` | `c192f2a` |
| M-17 | Demo event "DevFest Belgrade 2026", default id `devfest` (old `devsummit` links alias to it), Find fit-line casing, interest options via repository | `7490c90` |
| M-21 | Echo 0.3.0 (mobile#9): structured summary + trade-off time links into the transcript, "N similar questions merged", merged submit, `language=sr` for catch-up/ask/summary when translating; demo repo mirrors it | `91e9ec3` |
| M-20 | Design polish: missing copy in ARB (21 keys), `Session.isLive`, My events live card + Next row, Top match, results caption, contact notes, Messages pill + "Show on map" → `?spot=1` highlight | `899429a` |
| V-2 | Redesign screenshot review: all screens match/minor gaps; hex literals 0; follow-ups → M-20 additions, mobile#10 (map chrome, `/o`) | verification |
| M-10d | Design: Echo + v2 (translated banner/pill, Q&A sheet with sort + votes, paywall sheet, summary page via Navigator.push) | `0a1a027` |
| M-10b | Design: Start (echo mark), Join (ink header, perks), Onboarding (progress bar, chips, consent toggles), My events (dark card, past cards, FAB) | `b32d2d6` |
| M-10g | Design: Organizer upload (drop zone, file rows, progress with real counts), review (count tiles, flagged rows for empty stage), published (ink + QR card) | `d9b71b7` |
| M-10e | Design: Find (+ results state, clear ×), Person (contact-state button), Messages (bubbles, meeting-spot card, composer) | `988669d` |
| M-10c | Design: Agenda (live card, chips, breaks), Session detail (v2: badges, speaker card, Echo card, Show on map) | `3480a1f` |
| M-10f | Design: Profile, event bottom nav (divider, line icons), Map meeting-spot floating card. Map plan chrome (chips, route card) is eho_maps → mobile#8 | `cfa27db` |
| M-18 | echo#1: Echo screen on the real Echo API (Firestore transcript, catch-up, ask, Q&A + votes, summary, translate to sr; health-check fallback to demo data). E2E: server transcript shown in the web app | `138b7be` |
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
