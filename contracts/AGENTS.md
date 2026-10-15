# contracts/AGENTS.md

Scoped rules for agents touching the shared contract. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and [`../docs/COORDINATION.md`](../docs/COORDINATION.md) and never relax them.

## Scope

- **Writable only by the contracts holder:** whoever registered the `contracts` scope; if nobody did, **the backend agent** (`../docs/COORDINATION.md` §1). Scope: `contracts/**`, `docs/decisions/contracts-*.md`.
- **Every other agent:** `contracts/**` is **read-only**. To ask for a change, add an outbound request to *your own* `STATUS.md`, addressed to `contracts`.

If you hold it, include it in your scope line, e.g. `My write scope is backend/** + contracts/** + docs/decisions/{backend,contracts}-*.md`.

## The contract-change procedure (run it autonomously)

1. **Collect input.** At each sync, read requests addressed to `contracts` in other modules' `STATUS.md` and mirror them in `contracts/STATUS.md` → *Inbound requests*.
2. **Decide the shape yourself.** Contract details are agent territory (`COORDINATION.md` §0). Use the tie-break rules (§5). Ask a human only if the change implies a high-level decision (auth model, real-time approach, new personal data).
3. **Additive change?** Make it right away. **Breaking?** Post a proposal with `needs ack from: <modules>` and wait for their acks (§5). Prefer an additive alternative.
4. **Edit** `openapi.yaml` and update/add fixtures in `examples/` in the same commit. Bump `info.version`.
5. **Validate:** the spec lints (`npx @redocly/cli lint contracts/openapi.yaml` or `openapi-spec-validator`), and fixtures validate against their schemas.
6. **Record:** a `CHANGELOG.md` entry (impact, affected modules, request IDs, consumer action), *Approved operations* in `STATUS.md`, an announcement (`ACTION` or `BREAKING`), and mark the inbound requests `done`.
7. **Push immediately.**

## Rules

1. **The spec is a proposal until approved.** Draft operations carry `x-status: illustrative` and are never described as a working API.
2. **Every change records compatibility impact**: additive / breaking / fixture-only.
3. **Fixtures always validate** against the current schemas, and use clearly fake data.
4. **Don't invent.** Add operations because a module requested them or the agreed hero flow needs them, not speculatively. Auth schemes and upload formats follow their `team-` decisions.
5. **Non-HTTP contracts** (deep-link/QR format, real-time events) also live here as `contracts/*.md` once their decisions are accepted.
6. Don't edit application modules from a contracts session.
7. Stage with `git add -- contracts/ <other owned paths>`.
