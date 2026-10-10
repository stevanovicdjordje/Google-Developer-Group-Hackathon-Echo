# Event join flow: QR / link / deep link

- **ID:** `team-event-join`
- **Status:** open
- **Writer:** Integration owner, after team agreement · handle TBD
- **Affects:** organizer-web, mobile, backend
- **Created:** 2026-10-10 · **Decided:** —

## Context

Organizer-web generates a join QR/link and mobile must handle it. That's a shared format outside HTTP.

## Options

- Plain HTTPS link with event code
- Custom URI scheme / app link
- Manual event code entry as fallback

## Decision

_Open — not decided._

## Consequences / follow-ups

- Contracts owner writes `contracts/deeplinks.md` once decided.
