# Eho — Tasks (initial)

> Every task is **TODO** with owner **TBD** unless stated otherwise. These tasks build toward **one** demo slice (see `MVP.md`). They do **not** commit us to building every candidate feature.

## Definition: "Ready for integration"

A feature is ready for integration when **all** of these hold:

1. Its API contract is **approved** in `contracts/openapi.yaml`.
2. Request/response **fixtures** exist in `contracts/examples/` and validate against the spec.
3. The backend performs **request/response validation** for it.
4. A **happy-path end-to-end** run works against the real backend (not mocks).

## Phase 0 — Bootstrap

| # | Task | Owner | Status |
| --- | --- | --- | --- |
| 0.1 | Create monorepo scaffold, docs, private GitHub repo | Bootstrap agent | Done (scaffold only) |
| 0.2 | Invite collaborators on GitHub; teammates accept | Repo owner | In progress (2 invites sent 2026-10-10, pending acceptance) |
| 0.3 | Fill in `OWNERSHIP.md` handles; add `CODEOWNERS` | TBD | TODO |
| 0.4 | Each teammate: onboarding (`ONBOARDING.md`): scope guard, agent kickoff | Everyone | TODO |

## Phase 1 — Decide

| # | Task | Owner | Status |
| --- | --- | --- | --- |
| 1.1 | Choose the hero flow / demo slice (`MVP.md`) | TBD | TODO |
| 1.2 | Choose stacks per module; record in `docs/decisions/` | TBD | TODO |
| 1.3 | Decide Gemma model + where it runs | TBD | TODO |
| 1.4 | Run first user interviews (`USER_RESEARCH.md`) | TBD | TODO |

## Phase 2 — Contracts and skeletons (parallel)

| # | Task | Owner | Status |
| --- | --- | --- | --- |
| 2.1 | Minimal contracts for the hero flow + fixtures | TBD | TODO |
| 2.2 | Backend skeleton: health endpoint, validation, adapter interfaces | TBD | TODO |
| 2.3 | Mobile skeleton running on fixtures | TBD | TODO |
| 2.4 | Organizer-web skeleton running on fixtures | TBD | TODO |
| 2.5 | Gemma proof-of-concept: one real call with realistic latency, from the backend | TBD | TODO |

## Phase 3 — Integrate

| # | Task | Owner | Status |
| --- | --- | --- | --- |
| 3.1 | Backend implements hero-flow endpoints | TBD | TODO |
| 3.2 | Clients switch from fixtures to the real API | TBD | TODO |
| 3.3 | Test the real API end-to-end (happy path) | TBD | TODO |
| 3.4 | Write down one technical problem + how it was solved (judging criterion) | TBD | TODO |

## Phase 4 — Demo and pitch

| # | Task | Owner | Status |
| --- | --- | --- | --- |
| 4.1 | Prepare the demo dataset (one conference, fake/permissioned data) | TBD | TODO |
| 4.2 | Rehearse the live demo on the real stack, with a fallback plan | TBD | TODO |
| 4.3 | Pitch deck: problem, research, solution, tech, business, team | TBD | TODO |
| 4.4 | Business section: users vs. buyers, competition, monetization, costs | TBD | TODO |
| 4.5 | Timed pitch rehearsal | TBD | TODO |

## Stretch (only if the hero flow is done)

Venue map · networking · live captions/translation · richer dashboard. Each needs the team's go-ahead first.
