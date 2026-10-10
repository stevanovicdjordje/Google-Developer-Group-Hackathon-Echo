# Authentication and roles

- **ID:** `team-auth`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

Attendees and organizers have different privileges; the backend enforces roles.

## Options

- Firebase Auth
- Anonymous join via event code for attendees + organizer accounts
- Other

## Decision

**Firebase Auth.** Organizers sign in with email/password; attendees use anonymous sign-in (upgradeable later). Clients send `Authorization: Bearer <Firebase ID token>`; each backend service verifies it and checks `ownerUid` for organizer operations.

Requested by @Vertiglo (`mobile#2`), accepted by @Ilij4n, 2026-10-10. Already implemented in `backend/maps`.

## Consequences / follow-ups

- Add `securitySchemes` to the contract; document how to get a dev token in `backend/STATUS.md`.
- Every backend feature service uses the same token verification. Dev tokens come from the Firebase Auth emulator (see `backend/maps/README.md`).
