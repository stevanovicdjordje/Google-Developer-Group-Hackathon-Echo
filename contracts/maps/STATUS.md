# feature:maps — STATUS

> **Single writer:** the `feature:maps` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 00:20 · **Owner:** @Vertiglo · **Scopes held:** feature:maps

## Current state

The venue map: `mobile/maps/` (Flutter package `eho_maps`), `backend/maps/` (Go service), `contracts/maps/` (this folder).
Phases 1–4 done: API + publish, attendee viewer (`/e/{eventId}`), organizer editor (`/o`, `/o/e/{eventId}`).
Phase 5 (routing) done: the server computes walking routes (`getRoute`, contract 0.2.0) and the attendee viewer draws them ("Prikaži put", from the scanned QR marker or a picked start, multi-floor banner). Next: phase 6 (georeferencing, GPS dot). Details and the exact stop point: [`PLAN.md`](PLAN.md) → "Where we stopped".

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | `cd backend/maps && make dev` (emulators + API on `http://localhost:8080`), then `make seed` (prints the demo event's links) |
| Routes the app gets from `mapsRoutes()` | `/e/{eventId}` (`?at={markerId}`), `/e/{eventId}/stand/{featureId}` (any feature, rooms too), `/o`, `/o/e/{eventId}` |
| App integration | `MapsLocalizations.delegate` in the app; optional `mapsApiBaseUrlProvider` override (default `http://localhost:8080`) |
| Organizer demo login | `organizer@eho.test` / `eho-demo-123` (emulator only). On web with emulators every page load starts signed out |
| Contract | [`openapi.yaml`](openapi.yaml) 0.2.0, [`realtime.md`](realtime.md), [`CHANGELOG.md`](CHANGELOG.md) |

## Contract coverage

| Operation | Server (`backend/maps`) | App (`mobile/maps`) |
| --- | --- | --- |
| `listMyEvents`, `getEvent`, `createEvent`, `getDraftMap`, `publishEvent`, `createFloor`, `updateFloor`, `deleteFloor`, `putFloorGraph`, `createFeature`, `updateFeature`, `deleteFeature` | implemented (handler tests) | verified e2e (emulators, headless Chrome) |
| `putFloorGeoref`, `deleteFloorGeoref`, `updateEvent`, `deleteEvent`, `mapsHealthz` | implemented (handler tests) | not used yet |
| `getRoute` | implemented (A* tests vs Dijkstra, 0.5 ms on 5000 nodes, handler tests) | verified e2e (emulators, headless Chrome, inside the app's Map tab); widget tests incl. multi-floor |
| Published map in Firestore (`realtime.md`) | written by publish | verified e2e; a publish reaches an open viewer in ~0.6 s |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 00:20 · INFO · for: mobile · The map viewer (`MapViewerScreen`, in your Map tab) now has "Prikaži put": it calls the map API (`POST /v1/events/{id}/route`) with the signed-in (anonymous) user's ID token. No API change for the app; the base URL comes from `mapsApiBaseUrlProvider` (default `http://localhost:8080`), so maps#1 (b) now matters for attendees too.
- 2026-10-11 00:04 · INFO · for: all · Map contract 0.2.0: `getRoute` (walking route on the published map). Additive; see `CHANGELOG.md`.
- 2026-10-10 23:52 · INFO · for: mobile · Organizer map editor is in `eho_maps` (`/o`, `/o/e/{eventId}`, mounted through `mapsRoutes()`). `eho_maps` now depends on `file_picker` and `http`, so `flutter pub get` in `mobile/app` updates its `pubspec.lock`. See request maps#1.
- 2026-10-10 23:52 · INFO · for: all · `feature:maps` registered (@Vertiglo). `backend` and `contracts` released (Owner TBD); `mobile` is @Ilij4n's.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| maps#1 | mobile | (a) Commit the `mobile/app/pubspec.lock` update from `flutter pub get` (`eho_maps` added `file_picker`). (b) In `main.dart`, override `mapsApiBaseUrlProvider` with `AppConfig.apiBaseUrl` so `--dart-define=API_BASE_URL` also reaches the map editor. (c) Somewhere for organizers (e.g. Profile), a way into `/o` (map editor). Placement is your call. | open | 2026-10-10 |
| mobile#1–#4 | product, integration | Opened by @Vertiglo while holding mobile (map in the MVP, `team-auth`, `team-event-join`, feature scopes). All answered as `done` in `mobile/STATUS.md`. | closed | 2026-10-10 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| — | | | | |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
