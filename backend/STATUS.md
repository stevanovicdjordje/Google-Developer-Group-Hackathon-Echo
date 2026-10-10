# backend — STATUS

> **Single writer:** the backend owner and their agent. Everyone else reads.
> Protocol: [`../docs/COORDINATION.md`](../docs/COORDINATION.md). Newest entries at the top of each log.

**Last updated:** 2026-10-10 · **Owner:** @Vertiglo (temporary, venue map only) · **Scopes held:** mobile, backend, contracts
<!-- Set by the agent on its first session: Owner = @github-handle of its human (docs/COORDINATION.md §2). -->

## Current state

Stack decided (Go + Firestore + Cloud Run). Each feature is its own service in a subfolder. `backend/maps/` (venue map, @Vertiglo): phases 1–2 done: Firebase ID-token auth, map CRUD (events, floors, georef, graph, features), validation (polygons, bounds, graph), atomic publish, seed of a demo event (`make seed`). Next: routing (phase 5) after the app viewer/editor.

## Stack

Go (net/http, slog), Firebase Admin SDK, Firestore, Cloud Storage, Cloud Run. See [`backend-framework.md`](../docs/decisions/backend-framework.md), [`backend-persistence.md`](../docs/decisions/backend-persistence.md). Gemma hosting still open ([`backend-gemma-hosting.md`](../docs/decisions/backend-gemma-hosting.md)).

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Local base URL | `http://localhost:8080` |
| How to start locally | `cd backend/maps && make dev` (Firebase emulators: Auth 9099, Firestore 8081, Storage 9199, UI 4000; project `demo-eho`) + API |
| Deployed demo URL | None |
| Dev auth (how a client gets a token) | Firebase Auth emulator (anonymous or email/password); send `Authorization: Bearer <ID token>`. Demo organizer after `make seed`: `organizer@eho.test` / `eho-demo-123` (emulator only) |
| Env vars a client needs | None. Server env: see `backend/.env.example` |
| AI endpoints: expected latency / timeouts / limits | Unknown until the Gemma proof-of-concept |

## Contract coverage

| operationId | Status (`not started` / `in progress` / `implemented` / `verified e2e`) |
| --- | --- |
| `mapsHealthz` (maps) | implemented (handler tests + emulator run) |
| `listMyEvents` (maps) | implemented (handler tests + emulator run) |
| `createEvent` (maps) | implemented (handler tests + emulator run) |
| `getEvent` (maps) | implemented (handler tests + emulator run) |
| `updateEvent` (maps) | implemented (handler tests + emulator run) |
| `deleteEvent` (maps) | implemented (handler tests + emulator run) |
| `getDraftMap` (maps) | implemented (handler tests + emulator run) |
| `publishEvent` (maps) | implemented (handler tests + emulator run) |
| `createFloor` (maps) | implemented (handler tests + emulator run) |
| `updateFloor` (maps) | implemented (handler tests + emulator run) |
| `deleteFloor` (maps) | implemented (handler tests + emulator run) |
| `putFloorGeoref` (maps) | implemented (handler tests + emulator run) |
| `deleteFloorGeoref` (maps) | implemented (handler tests + emulator run) |
| `putFloorGraph` (maps) | implemented (handler tests + emulator run) |
| `createFeature` (maps) | implemented (handler tests + emulator run) |
| `updateFeature` (maps) | implemented (handler tests + emulator run) |
| `deleteFeature` (maps) | implemented (handler tests + emulator run) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-10 21:47 · ACTION · for: mobile · Venue map API (contracts/maps 0.1.0) implemented in `backend/maps`. `cd backend/maps && make dev`, then `make seed` publishes a demo event and prints its links.
- 2026-10-10 21:40 · ACTION · for: all · @Vertiglo works **only on the venue map**. Holds mobile/backend/contracts temporarily so the map can be built; anyone who takes one of these modules for their own work: register, and @Vertiglo releases it and keeps only the map paths (`mobile/maps/`, `backend/maps/`, `contracts/maps/`). Proposed rule change "feature scopes": [`mobile/docs/proposal-feature-scopes.md`](../mobile/docs/proposal-feature-scopes.md).
- 2026-10-10 21:25 · ACTION · for: all · Backend runs locally: `cd backend/maps && make dev` → API on `http://localhost:8080` with Firebase emulators. Errors use `{code, message, details}`.
- 2026-10-10 21:12 · INFO · for: all · Backend is Go + Firestore. Need an endpoint (Gemma, captions, Q&A…)? Open a request to `contracts`/`backend`; @Vertiglo's agent handles it.
- 2026-10-10 · INFO · for: all · STATUS file created. Nothing implemented yet.

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
