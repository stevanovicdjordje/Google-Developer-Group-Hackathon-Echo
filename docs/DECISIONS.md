# Eho — Decisions

Decisions live in [`docs/decisions/`](decisions/), **one file per decision**. The folder itself is the index: there is no central list to keep in sync, and nobody has to edit a shared file to record a decision.

> No technology choice is **accepted** yet. TypeScript, Compose Multiplatform, Firebase, any hosting platform and any specific Gemma model are **candidates only**.

## See the current state

```bash
grep -H '^- \*\*Status' docs/decisions/*.md      # every decision and its status
grep -l 'Status:\*\* accepted' docs/decisions/*.md
```

## Who writes which file

The filename prefix names the only workstream allowed to write it (see `docs/COORDINATION.md` §1):

| Prefix | Writer |
| --- | --- |
| `mobile-` | Mobile owner |
| `backend-` | Backend owner |
| `organizer-web-` | Organizer-web owner |
| `contracts-` | Contracts holder (fallback: backend agent) |
| `product-` | Product holder (fallback: repo owner's agent) |
| `team-` | Integration holder (fallback: repo owner's agent), recording what the humans agreed |

Need a decision you can't write? Open a request to its writer (`docs/COORDINATION.md` §5).

## Lifecycle

`open` (question known, no proposal) → `proposed` (a recommendation exists) → `accepted` / `rejected` → possibly `superseded by <id>`.

When a decision becomes `accepted`:

1. Fill in **Decision** and **Decided** date.
2. Do the follow-ups listed in the file, using the change impact map (`docs/COORDINATION.md` §4).
3. If it affects other modules, add an announcement to your `STATUS.md` and push right away.

Never edit an accepted decision to mean something else. Supersede it with a new file.

## Template

Copy this to `docs/decisions/<prefix>-<topic>.md`:

```markdown
# <Title>

- **ID:** `<prefix>-<topic>`
- **Status:** open | proposed | accepted | rejected | superseded by `<id>`
- **Writer:** <workstream> · <handle>
- **Affects:** <modules>
- **Created:** YYYY-MM-DD · **Decided:** YYYY-MM-DD / —

## Context

Why is a decision needed?

## Options

- Option A — trade-offs
- Option B — trade-offs

## Decision

_Open — not decided._ (or: what we chose and why)

## Consequences / follow-ups

- What this makes easier/harder.
- What other modules must update, and where.
```
