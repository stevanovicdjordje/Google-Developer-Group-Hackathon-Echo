# backend/AGENTS.md

Scoped rules for agents working on the backend. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and do not replace it.

## Scope

- **Default owned (writable) paths:** `backend/**`
- **Read-only:** `../mobile/**`, `../organizer-web/**`, `../contracts/**`, `../docs/**`, root files
- Do not change mobile, organizer-web or shared specs/docs without explicit approval from their owner.

Start every session with: `My write scope is backend/**`.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Backend | `backend/**` | `mobile/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |

## Module rules

1. **Implement the approved contract.** Build against `../contracts/openapi.yaml`. If an endpoint or field is missing, write a proposal for the contract owner. Do not silently diverge from the contract.
2. **Validate every request and response** against the contract schemas.
3. **Isolate providers.** Gemma (LLM), STT and embeddings each sit behind their own adapter interface. STT is separate from Gemma processing.
4. **Untrusted AI output.** Validate and constrain model output. No model-generated SQL, no model-triggered privileged actions, no unauthenticated DB access.
5. **Auth and roles are enforced here.** Organizer-only operations must be checked server-side.
6. **Uploads:** never process or expose uploaded files without type, size and access checks. Don't make uploaded files publicly readable by default.
7. **Secrets** come from environment variables. Commit only a `.env.example` with placeholders. Do not provision cloud resources or billing from an agent session.
8. Stage with `git add -- backend/`.
