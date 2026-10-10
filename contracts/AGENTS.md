# contracts/AGENTS.md

Scoped rules for agents touching the shared contract. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and [`../docs/COORDINATION.md`](../docs/COORDINATION.md) and never relax them.

## Scope

- **Writable only by:** the contracts/integration owner, or a member they explicitly authorize for this session (see `../docs/OWNERSHIP.md`). Their scope: `contracts/**`, `docs/decisions/contracts-*.md`, `docs/decisions/team-*.md` (after team agreement), and the integration-owned rules files listed in the root `AGENTS.md`.
- **Every other agent:** `contracts/**` is **read-only**. To ask for a change, add an outbound request to *your own* `STATUS.md`, addressed to `contracts`.

If authorized, first line of the session: `My write scope is contracts/** + <any other integration files you were given>`.

## The contract-change procedure

1. **Collect input.** Read inbound requests (other modules' `STATUS.md` → *Outbound requests* addressed to `contracts`) and mirror them in `contracts/STATUS.md` → *Inbound requests*.
2. **Agree first.** Client and server owners agree before anything lands. A breaking change needs sign-off from every affected consumer, recorded in the request rows or a PR.
3. **Edit** `openapi.yaml` and update/add fixtures in `examples/` in the same commit. Bump `info.version`.
4. **Validate:** the spec lints (`npx @redocly/cli lint contracts/openapi.yaml` or `openapi-spec-validator`), and fixtures validate against their schemas.
5. **Record:** a `CHANGELOG.md` entry (impact, affected modules, request IDs, consumer action), *Approved operations* in `STATUS.md`, an announcement (`ACTION` or `BREAKING`), and mark the inbound requests `done`.
6. **Push immediately.** Breaking changes go via a PR.

## Rules

1. **The spec is a proposal until approved.** Draft operations carry `x-status: illustrative` and are never described as a working API.
2. **Every change records compatibility impact**: additive / breaking / fixture-only.
3. **Fixtures always validate** against the current schemas, and use clearly fake data.
4. **Don't invent.** No speculative endpoints, auth schemes or upload formats without the owners' input.
5. **Non-HTTP contracts** (deep-link/QR format, real-time events) also live here as `contracts/*.md` once their decisions are accepted.
6. Don't edit application modules from a contracts session.
7. Stage with `git add -- contracts/ <other owned paths>`.
