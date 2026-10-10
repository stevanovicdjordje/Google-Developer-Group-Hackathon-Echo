# backend — STATUS

> **Single writer:** the backend owner and their agent. Everyone else reads.
> Protocol: [`../docs/COORDINATION.md`](../docs/COORDINATION.md). Newest entries at the top of each log.

**Last updated:** 2026-10-10 · **Owner:** @Vertiglo · **Scopes held:** mobile, organizer-web, backend, contracts
<!-- Set by the agent on its first session: Owner = @github-handle of its human (docs/COORDINATION.md §2). -->

## Current state

Stack decided (Go + Firestore + Cloud Run). Phase 1 (skeleton: `/healthz`, config, slog, Dockerfile, Firebase emulators) in progress. Venue-map API next.

## Stack

Go (net/http, slog), Firebase Admin SDK, Firestore, Cloud Storage, Cloud Run. See [`backend-framework.md`](../docs/decisions/backend-framework.md), [`backend-persistence.md`](../docs/decisions/backend-persistence.md). Gemma hosting still open ([`backend-gemma-hosting.md`](../docs/decisions/backend-gemma-hosting.md)).

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Local base URL | Not available yet |
| How to start locally | Not available yet |
| Deployed demo URL | None |
| Dev auth (how a client gets a token) | Not decided (see `team-auth.md`) |
| Env vars a client needs | None yet |
| AI endpoints: expected latency / timeouts / limits | Unknown until the Gemma proof-of-concept |

## Contract coverage

| operationId | Status (`not started` / `in progress` / `implemented` / `verified e2e`) |
| --- | --- |
| — | No operations in the contract yet |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
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
