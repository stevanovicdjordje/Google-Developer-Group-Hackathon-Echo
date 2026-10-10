# Event join flow: QR / link / deep link

- **ID:** `team-event-join`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** organizer-web, mobile, backend
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

Organizer-web generates a join QR/link and mobile must handle it. That's a shared format outside HTTP.

## Options

- Plain HTTPS link with event code
- Custom URI scheme / app link
- Manual event code entry as fallback

## Decision

**Plain HTTPS links to the Flutter web app**, which also open in the browser when the app isn't installed:
- `https://<host>/e/{eventId}`: join/open the event; optional `?at={markerId}` (QR "you are here" marker)
- `https://<host>/e/{eventId}/stand/{standId}`: a stand on the map

The same paths work as in-app routes (go_router) and, later, as Android App Links / iOS Universal Links.

Requested by @Vertiglo (`mobile#3`), accepted by @Ilij4n, 2026-10-10.

## Consequences / follow-ups

- Contracts owner writes `contracts/deeplinks.md` once decided.
- New features add their own sub-paths under `/e/{eventId}/...` (e.g. `/e/{eventId}/session/{sessionId}`) and document them in their contract folder.
