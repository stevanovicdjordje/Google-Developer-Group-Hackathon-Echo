# contracts/AGENTS.md

Scoped rules for agents touching the shared API contract. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and do not replace it.

## Scope

- **Writable only by:** the contract/integration owner, or a member they explicitly authorize for this session (see `../docs/OWNERSHIP.md`).
- **Every other agent:** `contracts/**` is **read-only**. Write a proposal (in a PR description or an issue) instead of editing.

If you are authorized, start the session with: `My write scope is contracts/**`.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Contracts owner | `contracts/**` | application modules |

## Rules

1. **The OpenAPI spec is a proposal until approved.** Do not describe draft endpoints as a working API anywhere: code comments, docs or commit messages.
2. **Every change records its compatibility impact**: additive, breaking or fixture-only, plus the affected consumers.
3. **Agree first.** Client and server owners agree on a change before it lands. Breaking changes need sign-off from every affected consumer.
4. **Keep fixtures valid.** Examples in `examples/` must validate against the current schemas. Update them in the same PR as the schema.
5. **Don't invent.** No speculative endpoints, auth schemes or upload formats without the owners' input. If you add something for discussion, mark it `illustrative` (e.g. `x-status: illustrative`).
6. Don't edit application modules from a contracts session.
7. Stage with `git add -- contracts/`.
