# Single monorepo with independent modules

- **ID:** `team-monorepo`
- **Status:** proposed
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · handle TBD
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** —

## Context

4 people, ~24h, three apps plus a shared contract. We need shared visibility without a shared build system.

## Options

- One repo, plain folders, no Nx/Turborepo/submodules; each module builds independently.
- Multiple repos (harder to keep the contract in sync).
- Monorepo tooling (setup cost not justified).

## Decision

Proposed: option 1. This is how the repo is set up today.

## Consequences / follow-ups

- Boundaries rely on discipline (`AGENTS.md`), the optional scope guard and review, not on tooling.
