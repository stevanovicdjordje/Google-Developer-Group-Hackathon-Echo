# mobile/AGENTS.md

Scoped rules for agents working on the attendee app. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and [`../docs/COORDINATION.md`](../docs/COORDINATION.md) and never relax them.

## Scope

- **Writable:** `mobile/**` (including `mobile/STATUS.md`) and `docs/decisions/mobile-*.md`
- **Read-only:** everything else (`../contracts/**`, `../docs/**`, `../backend/**`, `../organizer-web/**`, root files)

First line of every session: `My write scope is mobile/** + docs/decisions/mobile-*.md`.

## What other modules expect from you (keep it current in `STATUS.md`)

- **Stack** and how a teammate builds/installs a demo build.
- **Join link / deep-link** handling, once `team-event-join` is decided.
- **Contract coverage:** which operations you consume, and whether you're on fixtures, the real API, or verified end-to-end.
- **Outbound requests** for any endpoint/field you need (to `contracts`) or backend behavior (to `backend`).

## What to watch at each sync

- `contracts/CHANGELOG.md` and `contracts/STATUS.md`: new or changed operations you consume.
- `backend/STATUS.md` → *How to consume*: base URL, dev auth, AI latency/timeouts.
- `organizer-web/STATUS.md`: join QR/link format it generates.
- Decisions: `team-event-join`, `team-auth`, `product-hero-flow`, `contracts-realtime-transport`, `team-captions-and-stt`.

## Module rules

1. **Stack is TBD** until `docs/decisions/mobile-stack.md` is `accepted`. Don't initialize a project or pick a stack unless the mobile owner asks in this session. When they decide, record it there, update `STATUS.md` and push.
2. **Mock-first.** UI must run on fixtures (`../contracts/examples/`) or local mocks while the backend isn't ready. Don't block on the backend.
3. **The contract is the boundary.** Consume only what `../contracts/openapi.yaml` defines. Need more? Open an outbound request. Don't invent backend behavior.
4. **No direct AI provider calls and no provider keys in the app**, unless an accepted decision says otherwise.
5. **Privacy:** networking visibility is opt-in; no precise location; don't log personal data (`../docs/DATA_PRIVACY.md`).
6. Stage with `git add -- mobile/ docs/decisions/mobile-*.md`.
