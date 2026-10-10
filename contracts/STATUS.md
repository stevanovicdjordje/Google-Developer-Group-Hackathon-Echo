# contracts — STATUS

> **Single writer:** the contracts holder (whoever registered the `contracts` scope; fallback: the backend agent). Everyone else reads.
> Protocol: [`../docs/COORDINATION.md`](../docs/COORDINATION.md). Newest entries at the top of each log.

**Last updated:** 2026-10-10 · **Owner:** @Vertiglo (temporary, venue map only) · **Scopes held:** mobile, backend, contracts
<!-- Set by the agent on its first session: Owner = @github-handle of its human (docs/COORDINATION.md §2). -->

## Current state

- Root `openapi.yaml` version **0.0.0**: valid skeleton, **no operations** (for features other than the map).
- **Venue map contract** in [`maps/`](maps/): `openapi.yaml` 0.1.0 (events, floors, georef, graph, features, publish), `realtime.md` (Firestore paths), `CHANGELOG.md`, `PLAN.md`. Lint: redocly OK (warnings only); fixtures validate (`python3 contracts/maps/scripts/validate_examples.py`).

## Approved operations

| operationId | Method + path | Since version | Fixtures |
| --- | --- | --- | --- |
| `mapsHealthz` | `GET /healthz` | maps 0.1.0 | `maps/examples/` |
| `listMyEvents` | `GET /v1/events` | maps 0.1.0 | `maps/examples/` |
| `createEvent` | `POST /v1/events` | maps 0.1.0 | `maps/examples/` |
| `getEvent` | `GET /v1/events/{eventId}` | maps 0.1.0 | `maps/examples/` |
| `updateEvent` | `PATCH /v1/events/{eventId}` | maps 0.1.0 | `maps/examples/` |
| `deleteEvent` | `DELETE /v1/events/{eventId}` | maps 0.1.0 | `maps/examples/` |
| `getDraftMap` | `GET /v1/events/{eventId}/draft` | maps 0.1.0 | `maps/examples/` |
| `publishEvent` | `POST /v1/events/{eventId}/publish` | maps 0.1.0 | `maps/examples/` |
| `createFloor` | `POST /v1/events/{eventId}/floors` | maps 0.1.0 | `maps/examples/` |
| `updateFloor` | `PATCH /v1/events/{eventId}/floors/{floorId}` | maps 0.1.0 | `maps/examples/` |
| `deleteFloor` | `DELETE /v1/events/{eventId}/floors/{floorId}` | maps 0.1.0 | `maps/examples/` |
| `putFloorGeoref` | `PUT …/floors/{floorId}/georef` | maps 0.1.0 | `maps/examples/` |
| `deleteFloorGeoref` | `DELETE …/floors/{floorId}/georef` | maps 0.1.0 | `maps/examples/` |
| `putFloorGraph` | `PUT …/floors/{floorId}/graph` | maps 0.1.0 | `maps/examples/` |
| `createFeature` | `POST /v1/events/{eventId}/features` | maps 0.1.0 | `maps/examples/` |
| `updateFeature` | `PATCH …/features/{featureId}` | maps 0.1.0 | `maps/examples/` |
| `deleteFeature` | `DELETE …/features/{featureId}` | maps 0.1.0 | `maps/examples/` |

## Proposed / under discussion

| Topic | Requested by | Status |
| --- | --- | --- |
| — | | |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-10 21:47 · ACTION · for: backend/maps, mobile/maps · Venue map contract 0.1.0 in `contracts/maps/openapi.yaml` (+ `realtime.md`). Implemented by `backend/maps`. See `contracts/maps/CHANGELOG.md`.
- 2026-10-10 21:40 · ACTION · for: all · @Vertiglo works **only on the venue map**. Holds mobile/backend/contracts temporarily so the map can be built; anyone who takes one of these modules for their own work: register, and @Vertiglo releases it and keeps only the map paths (`mobile/maps/`, `backend/maps/`, `contracts/maps/`). Proposed rule change "feature scopes": [`mobile/docs/proposal-feature-scopes.md`](../mobile/docs/proposal-feature-scopes.md).
- 2026-10-10 21:12 · INFO · for: all · Real-time = Firestore snapshot listeners on published data; all writes through the HTTP API (`contracts-realtime-transport` accepted). Venue-map operations coming in 0.1.0.
- 2026-10-10 · ACTION · for: all · Coordination protocol in place (`docs/COORDINATION.md`). Agents set themselves up on first session (§2) and collaborate autonomously; humans are asked only for design direction and high-level architecture (§0).
- 2026-10-10 · INFO · for: all · Contract skeleton 0.0.0 published. No endpoints agreed.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| — | | | | |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| — | | | | |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
