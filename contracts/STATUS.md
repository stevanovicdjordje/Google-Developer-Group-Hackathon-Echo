# contracts — STATUS

> **Single writer:** the contracts holder (whoever registered the `contracts` scope; fallback: the backend agent). Everyone else reads.
> Protocol: [`../docs/COORDINATION.md`](../docs/COORDINATION.md). Newest entries at the top of each log.

**Last updated:** 2026-10-10 · **Owner:** @Vertiglo (temporary, venue map only) · **Scopes held:** mobile, backend, contracts
<!-- Set by the agent on its first session: Owner = @github-handle of its human (docs/COORDINATION.md §2). -->

## Current state

- `openapi.yaml` version **0.0.0**: valid skeleton, **no operations**.
- No fixtures. No non-HTTP contracts (deep links, real-time) yet.

## Approved operations

| operationId | Method + path | Since version | Fixtures |
| --- | --- | --- | --- |
| — | No approved operations yet | | |

## Proposed / under discussion

| Topic | Requested by | Status |
| --- | --- | --- |
| — | | |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-10 21:58 · ACTION · for: all · @Vertiglo works **only on the venue map**. Holds mobile/backend/contracts temporarily so the map can be built; anyone who takes one of these modules for their own work: register, and @Vertiglo releases it and keeps only the map paths (`mobile/app/lib/features/maps/`, `backend/maps/`, `contracts/features/maps/`). Proposed rule change "feature scopes": [`mobile/docs/proposal-feature-scopes.md`](../mobile/docs/proposal-feature-scopes.md).
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
