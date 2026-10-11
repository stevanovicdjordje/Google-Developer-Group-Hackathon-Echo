# Coordinator handoff (@Ilij4n's main session)

**Who reads this:** the Claude session that replaces @Ilij4n's *coordinator*. That's his main session, which supervises the mobile orchestrator, holds the `integration` and `product` scopes, relays between teammates' agents, and does the occasional hands-on job (phone builds, model config). The mobile orchestrator has its own handoff (`mobile/docs/HANDOFF.md`). Don't duplicate it.

**Last updated:** 2026-10-11 09:05 by the first coordinator session (context ~800k, replaced on request).

## The human

- @Ilij4n (GitHub `Ilij4n`, repo owner, mobile dev). Hackathon "Reimagine the Event Experience with Gemma" (GDG Belgrade). Demo = a video of the happy path (`docs/MVP.md`).
- Wants **short, simple answers**, minimal typing, one-tap 🧭 choices. You do the heavy lifting. He often sleeps while agents work.
- Standing wishes: keep the orchestrator working through the board for as long as usage lasts; Sonnet at medium effort for test/verify workers; restart orchestrators before ~200k context; the Galaxy is a test device; **don't touch the iPhone unless he asks**.
- AI models: a model per feature. Gemini for most things, **Gemma for translation**. Repo docs must state truthfully which model does what (`feature-echo-ai`).

## Team and scopes (`grep -H '^\*\*Last updated' */STATUS.md contracts/*/STATUS.md`)

| Who | Holds | Notes |
| --- | --- | --- |
| @Ilij4n (you + orchestrator) | `mobile`, `integration`, `product`; maintains `feature:echo` while @MilosBG03 is away (`team-echo-holder`) | |
| @Vertiglo | `feature:maps`, `feature:find`, `feature:events` | Very productive. Finished mobile#14–#19; mobile#20 (`locateOnOpen`) seen |
| @MilosBG03 | `feature:echo` (away) | Built Echo; Find passed to Vertiglo (`team-find-holder`) |
| @stevanovicdjordje | nothing registered yet | Pushed `backend/onboarding` (08:44): a separate Serbian server-rendered Go app (own SQLite + cookie auth, registration, onboarding, event wizard, floor plan, schedule, invitations, **reviews + post-event report**). No git conflicts, but it overlaps events/maps/app onboarding/`team-auth`, and its default port :8080 collides with maps. **Request `mobile#21`** (in `mobile/STATUS.md`) asks him to register, change the port and align. 🧭 for @Ilij4n: how his app fits (proposal: organizer web portal for reviews/report, reading from `feature:events`). |

## Your recurring jobs

1. **Keep the orchestrator running.**
   - **Start one** (Terminal; tabs aren't possible, since osascript has no accessibility permission):
     `osascript -e 'tell application "Terminal" to do script "cd ~/Developer/eho && claude \"$(cat <prompt-file>)\""'`
     The prompt file holds the standard kickoff prompt from `mobile/docs/WORKFLOW.md` (bottom). Write it to your scratchpad first.
   - **Then message it the standing mandate** (copy from `mobile/docs/HANDOFF.md` → "Standing mandate") and `SendMessage(..., notify_when_idle: true)`.
   - **Watch it.** Idle notices arrive automatically. Add a fallback with `CronCreate` (session-only), e.g. `17,47 * * * *`, prompt "orchestrator watchdog" with these steps:
     - `ListAgents`; the newest `eho-*` session is the orchestrator.
     - Measure its context: last non-zero `usage` (input + cache_read + cache_creation) in its `~/.claude/projects/-Users-ilijan-Developer-eho/<session>.jsonl`.
     - Idle and under 200k: tell it to continue. Over 200k: it hands off and messages you; you start the successor.
   - **Permission blocks:** if the orchestrator says its permission mode denied something (e.g. killing processes), **don't do it for it** (that's permission laundering). Give the human the exact `! command` instead.
2. **Coordination (integration/product).** Answer requests addressed to `integration`/`product` in any STATUS file, record team decisions in `docs/decisions/team-*` / `product-*`, and keep `docs/MVP.md` "Who builds what" true.
3. **Relay.** Give the human 📣 messages to paste to teammates when something is urgent. Teammates' agents read the repo at sync.

## Machine state (Mac, 2026-10-11 ~09:00)

- **Services** (check health first: `curl localhost:<port>/healthz`):
  - Firebase emulators on 127.0.0.1: UI :4000, Firestore :8081, Auth :9099, Storage :9199 (started 03:18 from `backend/maps`)
  - maps API :8080, Echo :8082, Find :8083, Events :8084
  - Stable demo event id **`devfest`**; `DEMO_LOCATION` = 44.799820,20.400025 (entrance)
- **Keys:** `GEMINI_API_KEY` is in `backend/{echo,find,events}/.env` (git-ignored, chmod 600). Never print or commit it. Free tier: **Gemini 3.1 Pro returns 429** (needs billing; the human hasn't decided); `gemini-3.8-flash` / `3.7-flash` timed out on 2026-10-11, so `AI_MODEL=gemini-3-flash-preview`. Translation = `gemma-4-26b-a4b-it`.
- **Phones:**
  - **Galaxy A55** (`RZCX511WWLF`): test device; `mobile/scripts/phone_android.sh` (adb reverse 8080–8084, 9099, 9199).
  - **iPhone 13 Pro Max** (`00008110-000805EA1E0B801E`): runs an **old release build** pointing at event `ik6vmvjr7wlektj6`. Pending: rebuild with `devfest` **when the human asks**. Recipe:
    1. `python3 mobile/scripts/lan_forward.py <LAN-IP> 8081 9099 9199 &` (the emulators bind 127.0.0.1)
    2. `cd mobile/app && flutter build ios --release --dart-define=DEMO_EVENT_ID=devfest --dart-define=DEMO_LOCATION=44.799820,20.400025 --dart-define=EMULATOR_HOST=<LAN-IP> --dart-define=API_BASE_URL=http://<LAN-IP>:8080 --dart-define=ECHO_API_BASE_URL=http://<LAN-IP>:8082 --dart-define=FIND_API_BASE_URL=http://<LAN-IP>:8083 --dart-define=EVENTS_API_BASE_URL=http://<LAN-IP>:8084`
    3. `xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app`
    4. `xcrun devicectl device process launch --device <id> rs.eho.eho`
    Notes: LAN IP via `ipconfig getifaddr en0` (was 192.168.9.172). Check the dart-define names in `mobile/app/lib/core/config.dart` first. Debug builds can't launch outside the flutter tool on iOS 14+, so always use **release**.
- `caffeinate` keeps the Mac awake until ~14:15.

## Open items / 🧭 waiting on the human

- How @stevanovicdjordje's `backend/onboarding` fits (`mobile#21`).
- Gemini 3.1 Pro via billing, or stay on Flash (recommended: stay).
- iPhone rebuild on `devfest`.
- Paywall prices are still placeholders.
- https App Links need a hosting domain (M-14). Firebase deploy needs a real project (`maps#3` done app-side).

## Gotchas learned

- Claude Code loads `.claude/agents/` and the repo `CLAUDE.md` only when launched from the repo root.
- The design canvas (https://claude.ai/artifact/CWrqgTmmcqR4dZLzQZA2bU) belongs to his **old** account. It's public view-only, so you can't publish to it. `mobile/docs/design/` is the source of truth.
- The iOS native Firebase SDK aborts on web-shaped demo options; `firebase_init.dart` gives iOS correctly shaped fake values.
- Free-tier Gemini 3 models spend output tokens on thinking: Echo pads +1024 (`OutputPad`).
- The Echo replay finds the map event **by name**; renames must change both.
