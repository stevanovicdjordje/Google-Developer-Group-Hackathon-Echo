# feature:find holder while @MilosBG03 is away

- **ID:** `team-find-holder`
- **Status:** accepted
- **Writer:** Integration holder · @Ilij4n
- **Affects:** feature:find, feature:echo, feature:maps, mobile
- **Created:** 2026-10-11 · **Decided:** 2026-10-11

## Context

@MilosBG03 registered `feature:find` at 01:56 but went offline before implementing anything: `contracts/find/` holds only `STATUS.md`, and there is no `backend/find/`. Find (recommendations, prompt search, contacts, meeting spot) is one of the four selling features in the video. @Vertiglo is active and finished map phases 1–8.

Separately, `mobile#10`/`mobile#11` (rename the demo event to "DevFest Belgrade 2026") must land **together**: `backend/echo/cmd/replay` finds the map's demo event by name (`Where("name", "==", demoEventName)`), so renaming only the map seed breaks the Echo replay.

## Decision

1. **`feature:find` passes to @Vertiglo.** His agent takes over `contracts/find/STATUS.md` (Owner line, keeps the history), `backend/find/`, `contracts/find/`, `docs/decisions/feature-find-*`, and builds API-9, 10, 11, 15 + the profile part of API-14 from `mobile/docs/api-needs.md`. If @MilosBG03 comes back, he and @Vertiglo agree who continues.
2. **Paired rename:** @Vertiglo's agent may make the one-line `demoEventName` change in `backend/echo/cmd/replay/main.go` (plus any Echo test that asserts the name) in the same push as the map seed rename. Commit it with `git config eho.scope feature:maps,feature:find,feature:echo` for that commit only. Record it in `contracts/maps/STATUS.md` and answer `mobile#11` there. No other Echo changes.

## Consequences / follow-ups

- @Vertiglo: register `feature:find` (`git config eho.scope feature:maps,feature:find`), then contract first (`contracts/find/openapi.yaml`), then the Go service and a seed of ~20 fake attendees with consent switches on the demo event.
- mobile: wires `FindRepository` to the contract when it lands.
