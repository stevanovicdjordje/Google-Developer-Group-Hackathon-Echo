# organizer-web/AGENTS.md

Scoped rules for agents working on the organizer web app. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and [`../docs/COORDINATION.md`](../docs/COORDINATION.md) and never relax them.

## Scope

- **Writable:** `organizer-web/**` (including `organizer-web/STATUS.md`) and `docs/decisions/organizer-web-*.md`
- **Read-only:** everything else (`../mobile/**`, `../backend/**`, `../contracts/**`, `../docs/**`, root files)

First line of every session: `My write scope is organizer-web/** + docs/decisions/organizer-web-*.md`.

## What other modules expect from you (keep it current in `STATUS.md`)

- **Stack**, local dev URL, deployed demo URL.
- **Join QR / link format** you generate. It must match `contracts/deeplinks.md` once `team-event-join` is decided, because mobile depends on it.
- **Contract coverage:** operations consumed and whether you're on fixtures, the real API, or verified end-to-end.
- **Outbound requests** for upload/dashboard operations you need.

## What to watch at each sync

- `contracts/CHANGELOG.md` and `contracts/STATUS.md`.
- `backend/STATUS.md` → *How to consume*: base URL, dev auth, upload limits.
- Decisions: `team-import-formats`, `team-event-join`, `team-auth`, `product-hero-flow`.

## Module rules

1. **Framework is TBD** until `docs/decisions/organizer-web-framework.md` is `accepted`. Don't initialize a project unless the organizer-web owner asks in this session.
2. **Organizers have different privileges.** The backend enforces auth and roles. Frontend route guards are UX, not security.
3. **Mock-first** against `../contracts/examples/` until the backend is ready.
4. **Contract changes are requests** to the contracts owner, not direct edits.
5. **Uploads:** show clear client-side limits and types, but the server is the real gatekeeper. Don't display attendee personal data unless the contract and `../docs/DATA_PRIVACY.md` allow it.
6. No provider keys or secrets in client code.
7. Stage with `git add -- organizer-web/ docs/decisions/organizer-web-*.md`.
