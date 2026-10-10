# Mobile orchestrator handoff

Rewritten by the orchestrator at the end of every session. The next orchestrator reads this right after syncing (`mobile/docs/WORKFLOW.md` §1).

**Last session:** 2026-10-11, @Ilij4n's first orchestrator (it also bootstrapped the repo and wrote the coordination protocol).

## State in one paragraph

The whole demo flow from `docs/MVP.md` runs in `mobile/app` on demo data (commit `b72ca57`): organizer upload → publish → link/QR, deep-link join + onboarding, My events, the 4 tabs, Echo, Find → contact → mock messages → meeting spot. `flutter analyze` is clean, tests pass 5/5, and the web build renders every screen. The venue map (`mobile/maps`, feature:maps, @Vertiglo) is embedded in the Map tab but has never been seen against a live backend on this machine. Nobody owns the backend: what the app needs from it is in `mobile/docs/api-needs.md` (request `mobile#5`).

## In flight

Nothing. No worker branches open.

## Waiting on the human (ask only if a ready task depends on it)

- 🧭 UI language for the video (Serbian or English) → unblocks M-11.
- 🧭/🙋 Design: `/design-login`, then design in Claude Design → unblocks M-10. The human wants the design to build on the existing navigation skeleton.
- 🙋 Install Go + Firebase CLI to see the Map tab with real data (M-12).
- 🧭 Who owns the backend (stevanovicdjordje or the 4th teammate)? Not mobile's call, but blocks M-13.

## Waiting on teammates

- `mobile#5` (backend endpoints): no backend holder registered yet.
- `mobile#6` (feature:maps accepts the Map-tab embedding; optional "highlight place" API): open.

## Human preferences (important)

- The human types little and wants **simple, short** explanations and **ready-to-use** outputs. Do the heavy lifting; ask only real decisions, as one-tap 🧭 choices.
- Don't implement features in the orchestrator session. Dispatch to workers (Sonnet high by default, Opus medium for hard tasks), in parallel where files don't overlap.
- Mock only what's genuinely hard or needs heavy cross-module coordination (`docs/MVP.md`).
- AI models: chosen per feature, Gemma for translation (`docs/MVP.md`). Don't write repo docs that misstate which model a feature uses.

## Gotchas

- Worktrees branch from local `main`: commit before dispatching.
- `StatefulShellRoute` can't use `/e/:eventId/...` branch defaults (assertion). Tabs use `ShellRoute` (see M-5).
- On web, Firebase init would hang without emulators. `main.dart` now has a 5 s timeout. Keep it.
- Headless Chrome needs the DevTools approach in `mobile/scripts/shots.py`; `chrome --screenshot` gives blank pages for Flutter.
- In widget tests, Echo's transcript is a timed stream: add an extra `pump` after `pumpAndSettle`.
