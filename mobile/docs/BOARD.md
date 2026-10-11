# Mobile task board

Single writer: the mobile orchestrator (`mobile/docs/WORKFLOW.md`). Statuses: `ready` · `blocked` (say on what) · `in progress` (agent, since) · `review` (branch waiting to merge) · `done` (commit).
Sizes: S < 30 min · M ~1 h · L multi-hour. Agent: `dev` = mobile-dev (Sonnet), `opus` = mobile-dev-opus.

**Hot files** (one running worker at a time): `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.

## Ready


| ID | Task | Size | Agent | Files (expected) | Notes |
| --- | --- | --- | --- | --- | --- |
| M-26 | Echo on real Gemma — API part verified 2026-10-11: `/healthz` → `gemma-4-26b-a4b-it`; ask (en 2 s, sr via body `language`), catch-up `?language=sr`, translate sr (50 lines, 13 s) all answer from Gemma on the replayed keynote. Left: app-side look (build with `DEMO_EVENT_ID=ik6vmvjr7wlektj6`, Echo route shows server transcript) after V-3 | S | verifier | none | Emulator data was not persisted: re-seeded, event now `ik6vmvjr7wlektj6`, keynote replayed `-instant`. Key lives only in git-ignored `backend/echo/.env`. |
| M-31 | Organizer polish (V-3 #7): "✦ Extracted from 3 files" overline, flag "Designing for crowded rooms" (seed), short link display `eho.app/e/<id>`, "Copy"; shot routes for upload files-chosen + progress | S | dev | `features/organizer/`, `data/demo_data.dart`, `features/dev/` | After M-30 (demo_data) and M-28 (dev shots) |
| M-23 | Wire `FindRepository` to the Find API (API-9 recommendations, API-10 prompt search, API-11 contact requests, API-15 meeting spot, profile/consent) | M | opus | `data/` | Blocked on `contracts/find/openapi.yaml` (feature:find → @Vertiglo, `mobile#12`, `team-find-holder`). Keep demo data until then. |
| M-19 | Map detail (v2 `MapDetail.dc.html`): stage sheet with capacity, walk time, NOW session → session, Start route + Open Echo | M | dev | `features/map/map_tab.dart` | Blocked on `mobile#8` (feature:maps: a hook for app-provided sheet content + route line to the selected stage). |

## Blocked

| ID | Task | Blocked on |
| --- | --- | --- |
| M-13 | Wire real endpoints API-1…API-15 as they land | Backend has no owner yet (`mobile#5`) |
| M-14 | Android build on an emulator/device (`EMULATOR_HOST=10.0.2.2`) + Android App Links for `/e/{id}` | Hosting domain for assetlinks.json; Android SDK on the machine |

## In progress / review

| ID | Agent | Since | Branch | Notes |
| --- | --- | --- | --- | --- |
| M-28 | dev | 03:26 | worktree | Echo polish (V-3 #1–3, #9 echo part) + shots.sh USE_ECHO_API |
| M-29 | dev | 03:26 | worktree | Agenda/session + Start/My events/Profile/Onboarding copy (V-3 #4, #8) |
| M-30 | opus | 03:26 | worktree | Find/Person/Messages + demo data (V-3 #5, #6) |
| M-26b | verifier | 03:26 | — | app-side Echo on Gemma check |

## Done

| ID | Task | Commit |
| --- | --- | --- |
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
