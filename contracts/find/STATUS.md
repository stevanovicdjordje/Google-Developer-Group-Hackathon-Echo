# feature:find — STATUS

> **Single writer:** the `feature:find` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 04:05 · **Owner:** @Vertiglo · **Scopes held:** feature:maps, feature:find

## Current state

Find, people to meet: the server side of attendee profiles with their consent switches, AI recommendations, AI prompt search, contact requests and the meeting spot (`docs/PRODUCT.md`, `docs/DATA_PRIVACY.md` → *People features*).
Paths: `backend/find/` (Go service), `contracts/find/` (this folder), `docs/decisions/feature-find-*`. The Find, Person, Messages and Profile screens stay in the app shell (held by `mobile`); the app wires them to this API through `FindRepository`.

Taken over by @Vertiglo from @MilosBG03 (`docs/decisions/team-find-holder.md`). Contract 0.1.0 is up ([`openapi.yaml`](openapi.yaml)); the Go service (`backend/find`, port 8083) and a seed of ~20 fake attendees on the demo event are being built.
AI: Gemma through the Gemini API (`team-gemma-core`), same key/env as Echo (`GEMINI_API_KEY`, `GEMMA_MODEL`); without a key the service ranks offline (interest/word overlap), so the demo runs without one. Only `headline`, `interests`, `lookingFor` of visible candidates go to the model, never names or user IDs.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | Not available yet (service in progress; will be `cd backend/find && make dev` on `http://localhost:8083`) |
| Contract | [`openapi.yaml`](openapi.yaml) 0.1.0, [`CHANGELOG.md`](CHANGELOG.md), fixtures in [`examples/`](examples/) (`python3 contracts/find/scripts/validate_examples.py`) |

## Contract coverage

| Operation | Server (`backend/find`) | App |
| --- | --- | --- |
| profile, presence, recommendations, search, person, contacts, meeting spot (14 ops) | in progress | demo data (`DemoFindRepository`) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 04:05 · ACTION · for: mobile · Find contract 0.1.0 (`contracts/find/openapi.yaml`, see `CHANGELOG.md` for the differences from `api-needs.md`). You can wire `FindRepository` against it now; the service follows (announced here when it runs). Profile + consents (`/v1/me/profile`), `joinFind` per event, recommendations from the saved profile, prompt search, person, contacts (seeded demo people accept at once), meeting spot = a feature name on the published map.
- 2026-10-11 03:45 · INFO · for: all · `feature:find` now held by @Vertiglo (`docs/decisions/team-find-holder.md`, mobile#12). `feature:echo` stays with @MilosBG03. Contract (`contracts/find/openapi.yaml`) comes first.
- 2026-10-11 01:56 · INFO · for: all · `feature:find` registered (@MilosBG03, same holder as `feature:echo`). It takes the Find part of `mobile#5`: API-9 recommendations, API-10 prompt search, API-11 contact requests, API-15 meeting spot, and the profile + consent part of API-14. The rest of `mobile#5` (join, agenda, My events, organizer) stays with backend/contracts.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| — | | | | |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#5 (API-9, API-10, API-11, API-15, profile part of API-14) | mobile | Contract 0.1.0 up; service in progress. | accepted | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
