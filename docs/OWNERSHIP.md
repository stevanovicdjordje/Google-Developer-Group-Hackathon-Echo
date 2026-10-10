# Eho — Ownership

> **Status: Owners TBD.** Fill in GitHub handles when the team assigns roles. There are 4 people and 5 workstreams, so one person can hold several roles. Once handles are known, a `.github/CODEOWNERS` file can be added. It is intentionally absent until then, so no identities are invented.

## Workstreams

| Workstream | Owner GitHub handle | Owned paths | Dependencies | Status |
| --- | --- | --- | --- | --- |
| Mobile (attendee app) | TBD | `mobile/**` | `contracts/`, backend API | Not initialized |
| Backend (API, AI adapters) | TBD | `backend/**` | `contracts/`, Gemma/STT providers (TBD) | Not initialized |
| Organizer web | TBD | `organizer-web/**` | `contracts/`, backend API | Not initialized |
| Contracts / integration | TBD | `contracts/**`, `.github/`, root `AGENTS.md`/`CLAUDE.md`/`README.md` | All modules | Skeleton only |
| Product / demo | TBD | `docs/**` | Everyone; user research | Draft |

## Rules for shared changes

1. You write only in your owned paths. Everything else is read-only for you (and your AI agents).
2. Changes to `contracts/**` go through the contract/integration owner: separate PR, compatibility impact stated, affected owners agree.
3. Changes to `docs/**` or root files go through the product/demo or integration owner. Small typo fixes are fine via PR with their approval.
4. If you need something from another module, ask its owner (chat/issue/PR comment). Don't edit it yourself.

## PR flow

1. Branch: `<module>/<topic>`.
2. Keep the PR inside one module when possible. Fill in the PR template.
3. Reviewer: the owner of each touched path. Contract PRs also need a consumer owner.
4. Merge to `main` when it's reviewed and doesn't break the demo path.

## Escalation

1. Talk directly with the other owner.
2. If you're still blocked, the contracts/integration owner decides on API questions, and the product/demo owner decides on scope.
3. Record anything non-trivial in `DECISIONS.md`.

No automated orchestration is needed. This is a 4-person, ~24h project.
