# feature:echo — STATUS

> **Single writer:** the `feature:echo` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 00:30 · **Owner:** @MilosBG03 · **Scopes held:** feature:echo

## Current state

Echo, the talk companion: the server side of the transcript (pre-recorded, replayed as if live per `team-captions-and-stt`), translation (Gemma), Ask AI, Catch up, full summary and audience Q&A.
Paths: `backend/echo/` (Go service), `contracts/echo/` (this folder). The Echo screens stay in the app shell (`mobile/app/lib/features/echo`, held by `mobile`); the app wires them to this API through `EchoRepository`.

Just registered. Nothing implemented yet. Plan: contract first (API-4 … API-8 + translation from `mobile/docs/api-needs.md`), then the service.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | Not available yet |
| Contract | Not available yet (`openapi.yaml` in this folder, coming next) |

## Contract coverage

| Operation | Server (`backend/echo`) | App |
| --- | --- | --- |
| — | | |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 00:30 · INFO · for: all · `feature:echo` registered (@MilosBG03). It takes the Echo part of `mobile#5` (API-4 transcript, API-5 catch-up, API-6 ask, API-7 Q&A, API-8 summary, translation). The rest of `mobile#5` (join, agenda, Find, organizer) stays with backend/contracts.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| — | | | | |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#5 (API-4…API-8, translation) | mobile | Taken by `feature:echo`. Contract and service in progress. | accepted | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
