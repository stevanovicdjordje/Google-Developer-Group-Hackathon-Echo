# Authentication and roles

- **ID:** `team-auth`
- **Status:** open
- **Writer:** Integration owner, after team agreement · handle TBD
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** —

## Context

Attendees and organizers have different privileges; the backend enforces roles.

## Options

- Firebase Auth
- Anonymous join via event code for attendees + organizer accounts
- Other

## Decision

_Open — not decided._

## Consequences / follow-ups

- Add `securitySchemes` to the contract; document how to get a dev token in `backend/STATUS.md`.
