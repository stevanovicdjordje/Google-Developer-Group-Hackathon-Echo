# mobile/AGENTS.md

Scoped rules for agents working on the attendee app. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and do not replace it.

## Scope

- **Default owned (writable) paths:** `mobile/**`
- **Read-only:** `../contracts/**`, `../docs/**`, root files, `../backend/**`, `../organizer-web/**`
- Do not edit shared files or the backend unless the user explicitly assigns them for this session.

Start every session with: `My write scope is mobile/**`.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Mobile | `mobile/**` | `backend/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |

## Module rules

1. **Stack is TBD.** Android / Compose Multiplatform / Flutter / web is the mobile owner's decision. Do not initialize a project or choose a stack unless the mobile owner asks you to in this session.
2. **Mock-first.** UI must work against contract fixtures (`../contracts/examples/`) or local mocks while the backend is not ready. Do not block on the backend.
3. **The contract is the boundary.** Consume the API as described in `../contracts/openapi.yaml`. If you need a field or endpoint that doesn't exist, write a proposal for the contract owner. Do not edit the contract or invent backend behavior.
4. **No direct AI provider calls / no keys in the app** unless explicitly agreed and recorded in `docs/DECISIONS.md`.
5. **Privacy:** networking visibility is opt-in; do not collect precise location; do not log personal data. See `../docs/DATA_PRIVACY.md`.
6. Stage with `git add -- mobile/`.
