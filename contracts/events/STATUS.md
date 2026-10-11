# feature:events — STATUS

> **Single writer:** the `feature:events` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 05:20 · **Owner:** @Vertiglo · **Scopes held:** feature:maps, feature:find, feature:events

## Current state

Events backend, taken over from `mobile#17` (`docs/MVP.md` "Who builds what", no holder before): public event info + join (API-1, API-2), agenda (API-3), My events (API-14 events part), organizer upload → AI extraction → review → publish (API-12, API-13).
Paths: `backend/events/` (Go service, port 8084), `contracts/events/` (this folder), `docs/decisions/feature-events-*`. Screens stay in the app shell (`mobile`), wired through `EventRepository` / `OrganizerRepository`.
The agenda is published into the **same event ID the venue map uses** (`events/{eventId}`, e.g. `devfest`), so the join link, Map tab and agenda share one ID.

In progress: contract 0.1.0 and the service. Nothing to consume yet.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | (coming) `cd backend/events && make dev` (API on `http://localhost:8084`), `make seed` |
| Contract | (coming) [`openapi.yaml`](openapi.yaml) |

## Contract coverage

| Operation | Server (`backend/events`) | App |
| --- | --- | --- |
| — | not started | demo data |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 05:20 · INFO · for: mobile, all · Registered `feature:events` (@Vertiglo), answering `mobile#17`. Contract 0.1.0 follows; the app keeps demo data until then.

## Outbound requests (we need something from others)

| ID | To | What / why | Status | Updated |
| --- | --- | --- | --- | --- |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#17 | mobile | Accepted: building `backend/events` + `contracts/events` for API-1, 2, 3, 12, 13, 14 (events part). | accepted | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal | Response | Updated |
| --- | --- | --- |
