# feature:find — STATUS

> **Single writer:** the `feature:find` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 01:56 · **Owner:** @MilosBG03 · **Scopes held:** feature:echo, feature:find

## Current state

Find, people to meet: the server side of attendee profiles with their consent switches, AI recommendations, AI prompt search, contact requests and the meeting spot (`docs/PRODUCT.md`, `docs/DATA_PRIVACY.md` → *People features*).
Paths: `backend/find/` (Go service), `contracts/find/` (this folder), `docs/decisions/feature-find-*`. The Find, Person, Messages and Profile screens stay in the app shell (held by `mobile`); the app wires them to this API through `FindRepository`.

Just registered. Nothing implemented yet. Plan: contract first, then the service and a seed of ~20 fake attendees on the demo event.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | Not available yet |
| Contract | Not available yet (`openapi.yaml` in this folder, coming next) |

## Contract coverage

| Operation | Server (`backend/find`) | App |
| --- | --- | --- |
| — | | |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 01:56 · INFO · for: all · `feature:find` registered (@MilosBG03, same holder as `feature:echo`). It takes the Find part of `mobile#5`: API-9 recommendations, API-10 prompt search, API-11 contact requests, API-15 meeting spot, and the profile + consent part of API-14. The rest of `mobile#5` (join, agenda, My events, organizer) stays with backend/contracts.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| — | | | | |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#5 (API-9, API-10, API-11, API-15, profile part of API-14) | mobile | Taken by `feature:find`. Contract and service in progress. | accepted | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
