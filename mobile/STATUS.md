# mobile — STATUS

> **Single writer:** the mobile owner and their agent. Everyone else reads.
> Protocol: [`../docs/COORDINATION.md`](../docs/COORDINATION.md). Newest entries at the top of each log.

**Last updated:** 2026-10-10 · **Owner:** @Vertiglo (temporary, venue map only) · **Scopes held:** mobile, backend, contracts
<!-- Set by the agent on its first session: Owner = @github-handle of its human (docs/COORDINATION.md §2). -->

## Current state

Stack decided (Flutter). @Vertiglo builds only the **venue map** (`mobile/maps/`, Flutter package `eho_maps`: attendee viewer, organizer editor, stats), mounted by the app in `mobile/app/`. Phase 1 done: Flutter app skeleton (Riverpod, go_router, l10n sr/en, light/dark theme, API client, Firebase emulators, anonymous sign-in). Phase 2 done on the server side; `mobile/maps` has the map data models. Now: phase 3 (attendee map viewer). Phases: [`../contracts/maps/PLAN.md`](../contracts/maps/PLAN.md).

## Stack

Flutter (web + Android + iOS), Riverpod, go_router, flutter_map (CrsSimple), geolocator, Firebase Auth/Firestore (read-only)/Storage. See [`docs/decisions/mobile-stack.md`](../docs/decisions/mobile-stack.md).

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Platforms targeted for the demo | Flutter web on phones (link/QR, no install); Android/iOS from the same code |
| How to build/install a demo build | `mobile/scripts/dev_all.sh` (local, everything). Hosted web build: not yet |
| Join link / deep-link scheme handled | Not decided (see `team-event-join.md`) |
| Backend base URL configuration | `--dart-define=API_BASE_URL=...` (default `http://localhost:8080`) |
| Mock/fixture mode | Firebase emulators (`demo-eho`) + local API; seed data in phase 2 |

## Contract coverage (operations consumed)

| operationId | Status (`not started` / `on fixtures` / `on real API` / `verified e2e`) |
| --- | --- |
| — | No operations in the contract yet |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-10 21:47 · INFO · for: all · New Flutter package `mobile/maps` (`eho_maps`) holds all venue-map client code; `mobile/app` depends on it via `path: ../maps`. Map plan moved to `contracts/maps/PLAN.md`.
- 2026-10-10 21:40 · ACTION · for: all · @Vertiglo works **only on the venue map**. Holds mobile/backend/contracts temporarily so the map can be built; anyone who takes one of these modules for their own work: register, and @Vertiglo releases it and keeps only the map paths (`mobile/maps/`, `backend/maps/`, `contracts/maps/`). Proposed rule change "feature scopes": [`mobile/docs/proposal-feature-scopes.md`](../mobile/docs/proposal-feature-scopes.md).
- 2026-10-10 21:25 · INFO · for: all · Flutter app skeleton in `mobile/app/` runs on web against the local API and Firebase emulators. Run: `mobile/scripts/dev_all.sh`.
- 2026-10-10 21:12 · INFO · for: all · @Vertiglo holds mobile, organizer-web, backend and contracts. Building the venue map (floor plan, stands/rooms, routing, GPS + QR "you are here", organizer stats). Stack: Flutter app in `mobile/app/` (also the organizer UI), Go backend on Cloud Run, Firestore. See decisions mobile-stack, organizer-web-framework, backend-framework, backend-persistence, contracts-realtime-transport.
- 2026-10-10 · INFO · for: all · STATUS file created. Nothing implemented yet.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| mobile#1 | product | Venue map is agreed by the team as an MVP feature (human @Vertiglo, 2026-10-10): floor plan image with rooms/stands/POIs, server-side routing, live GPS dot with accuracy circle and QR/manual "you are here" fallback, organizer stats (search, views, route targets, QR scans; never GPS coordinates). Please update `docs/MVP.md` / `docs/PRODUCT.md` (currently "candidate, no real-time indoor positioning") and add a location section to `docs/DATA_PRIVACY.md`: position is sent to the backend only to compute a route, never stored, logged or shown to others. | open | 2026-10-10 |
| mobile#2 | integration | Record `team-auth`: Firebase Auth. Organizers use email/password, attendees anonymous sign-in; clients send `Authorization: Bearer <Firebase ID token>`; backend verifies and checks `ownerUid` for organizer operations. (Agreed by @Vertiglo's team, 2026-10-10.) | open | 2026-10-10 |
| mobile#4 | integration | Adopt **feature scopes**: register for a feature (`feature:<name>`) instead of whole modules. Full text and exact hook/rules changes: [`mobile/docs/proposal-feature-scopes.md`](docs/proposal-feature-scopes.md). | open | 2026-10-10 |
| mobile#3 | integration | Record `team-event-join`: plain HTTPS link to the Flutter web app, `https://<host>/e/{eventId}`; optional `?at={markerId}` (QR "you are here" marker), `/e/{eventId}/stand/{standId}` for a stand. Same paths work as app deep links. | open | 2026-10-10 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| — | | | | |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
