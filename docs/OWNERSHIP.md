# Eho — Ownership

> **Status: Owners TBD.** Fill in GitHub handles when the team assigns roles. There are 4 people and 5 workstreams, so one person can hold several. Once handles are known, add `.github/CODEOWNERS`. It's absent until then so no identities are invented.

## Team (GitHub)

| Handle | Repo access | Workstream(s) |
| --- | --- | --- |
| `Ilij4n` | Admin (repo owner) | TBD |
| `stevanovicdjordje` | Write (invited 2026-10-10) | TBD |
| `Vertiglo` | Write (invited 2026-10-10) | TBD |
| TBD | — | TBD |

## Workstreams

| Workstream | Owner GitHub handle | Owned paths | Publishes in | Dependencies | Status |
| --- | --- | --- | --- | --- | --- |
| Mobile (attendee app) | TBD | `mobile/**`, `docs/decisions/mobile-*` | `mobile/STATUS.md` | `contracts/`, backend API | Not initialized |
| Backend (API, AI adapters) | TBD | `backend/**`, `docs/decisions/backend-*` | `backend/STATUS.md` | `contracts/`, Gemma/STT providers (TBD) | Not initialized |
| Organizer web | TBD | `organizer-web/**`, `docs/decisions/organizer-web-*` | `organizer-web/STATUS.md` | `contracts/`, backend API | Not initialized |
| Contracts / integration | TBD | `contracts/**`, `docs/decisions/contracts-*`, `docs/decisions/team-*`, root rules files, `.github/`, `.githooks/`, `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `docs/INTEGRATION.md`, `docs/DECISIONS.md` | `contracts/STATUS.md`, `contracts/CHANGELOG.md` | All modules | Skeleton only |
| Product / demo | TBD | Other `docs/**`, `docs/decisions/product-*` | `docs/MVP.md`, `docs/TASKS.md` | Everyone; user research | Draft |

Live module status is **not** tracked here. It's in each module's `STATUS.md`.

## Rules for shared changes

1. Write only in your owned paths. Everything else is read-only for you and your agents.
2. Need something elsewhere? Open a request in your own `STATUS.md` (`docs/COORDINATION.md` §4) and ping the owner in chat if it blocks you.
3. Contract changes go through the contracts owner, following the procedure in `contracts/AGENTS.md`.
4. Cross-cutting (`team-*`) decisions are agreed by the team, then written by the integration owner.

## Git workflow

- Trunk-based on `main`. Commit small, pull with rebase, push often (`docs/COORDINATION.md` §6).
- Use a PR for breaking contract changes, rule changes, or when you want a review. The reviewer is the owner of each touched path. Contract PRs also need a consumer owner.

## Escalation

1. Talk directly with the other owner.
2. If you're still blocked, the contracts/integration owner decides API questions and the product/demo owner decides scope.
3. Record the outcome in `docs/decisions/`.

No automated orchestration is needed. This is a 4-person, ~24h project.
