# backend/AGENTS.md

Scoped rules for agents working on the backend. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and [`../docs/COORDINATION.md`](../docs/COORDINATION.md) and never relax them.

## Scope

- **Writable:** `backend/**` (including `backend/STATUS.md`) and `docs/decisions/backend-*.md`
- **Read-only:** everything else (`../mobile/**`, `../organizer-web/**`, `../contracts/**`, `../docs/**`, root files)

First line of every session: `My write scope is backend/** + docs/decisions/backend-*.md`.

## What other modules expect from you (keep it current in `STATUS.md`)

Both clients depend on the backend, so `backend/STATUS.md` → **How to consume** is the most-read section in the repo. Update it and post an `ACTION` announcement whenever any of these change:

- local base URL, port, how to start the server, deployed demo URL,
- how a client gets a dev token (once `team-auth` is decided),
- env vars a client needs,
- AI endpoint behavior: expected latency, timeouts, rate limits, failure modes,
- **contract coverage:** which operations are implemented and which are verified end-to-end.

## What to watch at each sync

- `contracts/CHANGELOG.md` and `contracts/STATUS.md`: operations you must implement.
- Inbound requests in your `STATUS.md` from mobile/organizer-web.
- Decisions: `team-auth`, `team-import-formats`, `team-captions-and-stt`, `contracts-realtime-transport`, `product-hero-flow`.

## Module rules

1. **Implement the approved contract.** Build against `../contracts/openapi.yaml`. If something is missing, open an outbound request to `contracts`. Don't silently diverge.
2. **Validate every request and response** against the contract schemas.
3. **Isolate providers.** Gemma (LLM), STT and embeddings each sit behind their own adapter. STT is separate from Gemma processing. Hosting choices go in `docs/decisions/backend-gemma-hosting.md`.
4. **Untrusted AI output.** Validate and constrain model output. No model-generated SQL, no model-triggered privileged actions, no unauthenticated DB access.
5. **Auth and roles are enforced here.** Organizer-only operations are checked server-side.
6. **Uploads:** type, size and access checks before processing or exposing any file; private by default.
7. **Secrets** come from env vars. Commit only `backend/.env.example` with placeholders. Don't provision cloud resources or billing from an agent session.
8. Stage with `git add -- backend/ docs/decisions/backend-*.md`.
