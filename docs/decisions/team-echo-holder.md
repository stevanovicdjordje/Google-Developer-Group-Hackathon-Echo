# feature:echo maintainer while @MilosBG03 is away

- **ID:** `team-echo-holder`
- **Status:** accepted
- **Writer:** Integration holder · @Ilij4n
- **Affects:** feature:echo, mobile
- **Created:** 2026-10-11 · **Decided:** 2026-10-11

## Context

@MilosBG03 built Echo (`backend/echo`, `contracts/echo`) and went offline. The team (@Ilij4n) wants per-feature AI models in Echo (a Gemini model for most features, Gemma for translation), which needs a small change in `backend/echo`.

## Decision

While @MilosBG03 is away, **@Ilij4n's agents maintain `feature:echo`**: small changes only, recorded in `contracts/echo/STATUS.md` and `CHANGELOG.md`, committed with `eho.scope` including `feature:echo`. `team-find-holder`'s permission for @Vertiglo's paired DevFest rename in `backend/echo/cmd/replay` still applies. When @MilosBG03 returns, he takes Echo back.

## Consequences / follow-ups

- First change: `assist.Routed` (Gemini for Ask/Catch up/Summary/grouping, Gemma for Translate), `feature-echo-ai` revised.
