# Single monorepo with independent modules

- **ID:** `team-monorepo`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-11

## Context

4 people, ~24h, three apps plus a shared contract. We need shared visibility without a shared build system.

## Options

- One repo, plain folders, no Nx/Turborepo/submodules; each module builds independently.
- Multiple repos (harder to keep the contract in sync).
- Monorepo tooling (setup cost not justified).

## Decision

One repo, plain folders, independent builds, as set up and used by every teammate since 2026-10-10. Recorded by @Ilij4n (integration).

## Consequences / follow-ups

- Boundaries rely on discipline (`AGENTS.md`), the optional scope guard and review, not on tooling.
