# feature:find — STATUS

> **Single writer:** the `feature:find` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 05:00 · **Owner:** @Vertiglo · **Scopes held:** feature:maps, feature:find

## Current state

Find, people to meet: the server side of attendee profiles with their consent switches, AI recommendations, AI prompt search, contact requests and the meeting spot (`docs/PRODUCT.md`, `docs/DATA_PRIVACY.md` → *People features*).
Paths: `backend/find/` (Go service), `contracts/find/` (this folder), `docs/decisions/feature-find-*`. The Find, Person, Messages and Profile screens stay in the app shell (held by `mobile`); the app wires them to this API through `FindRepository`.

Taken over by @Vertiglo from @MilosBG03 (`docs/decisions/team-find-holder.md`). Contract 0.1.1 ([`openapi.yaml`](openapi.yaml)) is implemented by the Go service `backend/find` (port 8083, all 14 operations), with a seed of 20 fake attendees on the demo event.
AI: Gemma through the Gemini API (`team-gemma-core`), same key/env as Echo (`GEMINI_API_KEY`, `GEMMA_MODEL`); without a key the service ranks offline (interest/word overlap), so the demo runs without one. Only `headline`, `interests`, `lookingFor` of visible candidates go to the model, never names or user IDs.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | Emulators first (`cd backend/maps && make dev`, `make seed`), then `cd backend/find && make dev` (API on `http://localhost:8083`) and `make seed` (20 demo attendees present at "DevFest Belgrade 2026", all consents on; contact requests to them are accepted at once) |
| AI | `GEMINI_API_KEY` in `backend/find/.env` enables Gemma (`GEMMA_MODEL`, same defaults as Echo); without it `model: offline` (overlap ranking). Recommendations/search are rate limited per user (429 + `Retry-After`). |
| Auth | `Authorization: Bearer <Firebase ID token>`; anonymous attendees work |
| Contract | [`openapi.yaml`](openapi.yaml) 0.1.1, [`CHANGELOG.md`](CHANGELOG.md), fixtures in [`examples/`](examples/) (`python3 contracts/find/scripts/validate_examples.py`) |

## Contract coverage

| Operation | Server (`backend/find`) | App |
| --- | --- | --- |
| all 14 ops (profile, presence, recommendations, search, person, contacts, meeting spot) | implemented: 17 handler tests, 10 AI-adapter tests, Firestore store test on the emulator; verified e2e with curl on the emulators (offline model) | demo data (`DemoFindRepository`) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 05:00 · ACTION · for: mobile · **Find service runs** (`backend/find`, `:8083`, see *How to consume*). You can switch `FindRepository` from demo data to it: `putMyProfile` from onboarding/Profile, `joinFind` when an event opens, then recommendations/search/person/contacts/meeting spot. Contract 0.1.1 is fixture-only over 0.1.0. Meeting spot `place` must be a feature name on the published map (e.g. "Info pult").
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
| mobile#5 (API-9, API-10, API-11, API-15, profile part of API-14) | mobile | Done: contract 0.1.1 + service `backend/find` (see *How to consume*). | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
