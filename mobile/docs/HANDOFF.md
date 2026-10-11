# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, third orchestrator session (@Ilij4n asleep since ~04:15; standing mandate below). Ran M-19, M-23…M-25, M-28…M-33, M-35…M-40, V-3, V-4a/b, M-26/26b, M-37.

## Standing mandate from @Ilij4n (relayed by his other session "ilijan-72")

1. Test the critical flows with Sonnet subagents at medium effort (`model: sonnet`, `effort: medium`), turn failures into board tasks, fix them.
2. Then keep working through the board autonomously, highest demo value first, in parallel where files don't overlap. Wire new backends (Events from @Vertiglo) as soon as their contracts land.
3. Don't wait for him; stop only for real 🧭 product decisions. Make sensible defaults, note them here.
4. Don't touch the iPhone (release build installed with devicectl). The **Galaxy A55** (`adb -s RZCX511WWLF`, `~/Library/Android/sdk/platform-tools/adb`) is a dedicated test device: reinstall/clear freely, one worker at a time.
5. When context nears 200k: do the WORKFLOW §5 handoff and tell the other session (`SendMessage` to `ilijan-72`; it subscribes to idle notices and starts a fresh orchestrator).

## State in one paragraph

All demo flows run in `mobile/app` in the human's design, English UI (all strings in ARB, sr too). Echo on the real Echo API (contract 0.3.1; Gemini `gemini-3-flash-preview` for ask/catch-up/summary/grouping, Gemma for translate; app shows no model names). Map tab on the live maps backend incl. the app's own stage sheet (M-19). Find wired to `contracts/find` 0.1.1 with demo fallback (M-23), verified end to end via API (M-37); fresh users get "Complete profile" (M-39). `/e/devfest|devsummit/...` redirect to `DEMO_EVENT_ID` (M-32); saved alias joins migrate (M-33). Dev screenshot routes `/dev/shot/<state>` (incl. `find-live`), tap-through flow tests in `test/flows/` (5 flows). `flutter analyze` clean, **144/144 tests** + 5 integration flows passing on the Galaxy (`integration_test/`, V-5). Runs on Android + iPhone (`9dbd308`, `31fcb1b`; APP_GUIDE *Run on phones*). Still demo data: Events (join/agenda/organizer) → @Vertiglo `mobile#17`.

## In flight

Nothing. No worker branches open.

## Running locally (don't kill; the human's phones use them)

Firebase emulators (Firestore 8081, Auth 9099, Storage 9199) + maps API 8080 (`backend/maps/scripts/dev.sh`, started by this session), Echo 8082 (restarted by the other session with `.env`), Find 8083 (started by this session, **offline** ranking; `backend/find/.env` with the key exists — restart with AI after `mobile#15` lands). Seeded event **`ik6vmvjr7wlektj6`** (still named "Eho Demo Expo"; emulator data is not persisted across restarts), keynote replayed into `s1` (`-instant`, ended), Find seeded with `EVENT=ik6vmvjr7wlektj6`. QR markers: `wjn26mhpr6udcopm` (Ulaz), `pxz2ixe5uopcnmwb` (Centralni hodnik), `cfzut3eby55lyp7a` (Kod hrane); Glavna sala feature `gjckurw6wpdro3ob`.

## Next up (priority order)

1. Sync. Ready now: **M-43** (find 0.2.0 meeting time) and **M-44** (`DEMO_LOCATION` for phones) — parallel-safe. Android phone: `DEMO_EVENT_ID=<id> mobile/scripts/phone_android.sh RZCX511WWLF`. A `::1` forwarder from V-5 (PID 36443) may still serve 8081/9099/9199.
2. Watch @Vertiglo's list (in `mobile/STATUS.md` 04:40): `mobile#16` stable event id + emulators on 0.0.0.0 (then re-seed once, rebuild phones with the stable id — replaces M-34), `mobile#15` Find on Gemini with timeout fallback (then restart Find with its `.env`), `mobile#17` Events backend (→ M-13: wire like M-23 with demo fallback).
3. For the video: replay the keynote **without** `-instant` (`cd backend/echo && make replay EVENT=<id>`) so `s1` is live; with `-instant` it's ended while the demo agenda says LIVE.
4. Ideas if idle: real-device visual pass on the Galaxy vs design; hide the Echo "Echo is on" card logic for past talks with transcripts (needs a `hasEcho` flag); share via a package (needs a 🧭 if a new dependency matters to him — it's a small call, default: keep copy-to-clipboard).

## Waiting on the human

- M-34/re-seed: he hasn't said testing is done; prefer `mobile#16` (stable id) so the phones never need a new id again.
- Real Firebase project / hosting domain (M-14 https links): only when someone deploys.

## Human preferences (important)

- Types little; wants **simple, short** explanations and ready-to-use outputs. Only real decisions as one-tap 🧭.
- Orchestrator doesn't implement; dispatch workers in parallel where files don't overlap.
- Mock only what's genuinely hard (`docs/MVP.md`). Models chosen per feature: Gemini for Echo/Find text, Gemma for translation — don't misstate in docs.

## Gotchas

- Worktrees vanish if a worker dies before writing (rate limit): resumed workers recreate them; a fresh dispatch is fine too. Check `git worktree list` and `git status` on main after interruptions.
- Workers sometimes run `dart format` on files outside their scope (theme.dart, live_badge.dart, happy_path_test.dart): briefs say don't; if left uncommitted in a worktree, verify whitespace-only and `worktree remove --force`.
- ARB merges: tell workers to insert keys next to related keys; after merging, `flutter gen-l10n`.
- The other @Ilij4n session works **in this same checkout** (phones, Echo backend). Never stage its files; `git pull --rebase=merges --autostash` carries its edits along. Ask it via SendMessage before touching anything you didn't make.
- `shots.sh` builds with `USE_ECHO_API=false` by default (export `USE_ECHO_API=true` for the real Echo), forwards `DEMO_EVENT_ID` and `LINK_BASE`; give each worker its own scratchpad subdir.
- Echo's Gemini models `gemini-3.8-flash`/`3.7-flash` hung on Google's side (B-1); `gemini-3-flash-preview` works.
- Design source of truth: `mobile/docs/design/` (v1 + v2). The live canvas is private: don't fetch it.
- Keep from before: `StatefulShellRoute` placeholder branches (`/e/_/<tab>`, navigate with `context.go`, never `goBranch`); web Firebase init 5 s timeout; headless Chrome via `shots.py` DevTools; extra `pump` after Echo streams in widget tests; pull before merging a batch.
