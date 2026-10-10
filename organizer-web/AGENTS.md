# organizer-web/AGENTS.md

Scoped rules for agents working on the organizer web app. These **add to** the root [`../AGENTS.md`](../AGENTS.md) and do not replace it.

## Scope

- **Default owned (writable) paths:** `organizer-web/**`
- **Read-only:** `../mobile/**`, `../backend/**`, `../contracts/**`, `../docs/**`, root files
- Do not edit the mobile app or the backend without explicit approval from their owner.

Start every session with: `My write scope is organizer-web/**`.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Organizer web | `organizer-web/**` | `mobile/**`, `backend/**`, `contracts/**`, `docs/**`, root |

## Module rules

1. **Framework is TBD.** Do not initialize a project or choose a framework unless the organizer-web owner asks you to in this session.
2. **Organizers have different privileges than attendees.** The backend must enforce auth and roles. Frontend route guards are UX, not security; never rely on them alone.
3. **Mock-first** against `../contracts/examples/` until the backend is ready.
4. **Contract changes are proposals** for the contract owner, not direct edits.
5. **Uploads:** show clear client-side limits and types, but assume the server is the real gatekeeper. Don't display attendee personal data unless the contract and privacy rules allow it (`../docs/DATA_PRIVACY.md`).
6. No provider keys or secrets in client code.
7. Stage with `git add -- organizer-web/`.
