# feature:find — STATUS

> **Single writer:** the `feature:find` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 09:43 · **Owner:** @Vertiglo · **Scopes held:** feature:maps, feature:find, feature:events

## Current state

Find, people to meet: the server side of attendee profiles with their consent switches, AI recommendations, AI prompt search, contact requests and the meeting spot (`docs/PRODUCT.md`, `docs/DATA_PRIVACY.md` → *People features*).
Paths: `backend/find/` (Go service), `contracts/find/` (this folder), `docs/decisions/feature-find-*`. The Find, Person, Messages and Profile screens stay in the app shell (held by `mobile`); the app wires them to this API through `FindRepository`.

Taken over by @Vertiglo from @MilosBG03 (`docs/decisions/team-find-holder.md`). Contract 0.2.0 ([`openapi.yaml`](openapi.yaml)) is implemented by the Go service `backend/find` (port 8083, all 14 operations), with a seed of 20 fake attendees on the demo event.
AI: a Gemini model through the Gemini API ([`feature-find-ai`](../../docs/decisions/feature-find-ai.md): `AI_MODEL`, default `gemini-3-flash-preview`, thinking `low`), same key as Echo (`GEMINI_API_KEY`); each call is cut at 8 s and that request falls back to offline ranking; without a key the service ranks offline (interest/word overlap), so the demo runs without one. Only `headline`, `interests`, `lookingFor` of visible candidates go to the model, never names or user IDs.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | Emulators first (`cd backend/maps && make dev`, `make seed`; **re-run Find's `make seed` after every maps seed**, since the event ID changes), then `cd backend/find && make dev` (API on `http://localhost:8083`) and `make seed` (20 demo attendees present at "DevFest Belgrade 2026", all consents on; contact requests to them are accepted at once) |
| AI | `GEMINI_API_KEY` in `backend/find/.env` enables `AI_MODEL` (default `gemini-3-flash-preview`; `GEMMA_MODEL`/`GEMMA_THINKING` are no longer read); 8 s hard timeout per call (`AI_TIMEOUT_SECONDS`), then `model: offline`; without a key always `model: offline` (overlap ranking). Recommendations/search are rate limited per user (429 + `Retry-After`). |
| Auth | `Authorization: Bearer <Firebase ID token>`; anonymous attendees work |
| Contract | [`openapi.yaml`](openapi.yaml) 0.2.0, [`CHANGELOG.md`](CHANGELOG.md), fixtures in [`examples/`](examples/) (`python3 contracts/find/scripts/validate_examples.py`) |

## Contract coverage

| Operation | Server (`backend/find`) | App |
| --- | --- | --- |
| all 14 ops (profile, presence, recommendations, search, person, contacts, meeting spot) | implemented: 17 handler tests, 10 AI-adapter tests, Firestore store test on the emulator; verified e2e with curl on the emulators (offline model) | demo data (`DemoFindRepository`) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 09:43 · INFO · for: mobile · mobile#23 done: `RESET=1 make seed` in `backend/find` for a clean Find list before recording.
- 2026-10-11 05:31 · INFO · for: mobile · mobile#15 done: Find ranks with `AI_MODEL` (default `gemini-3-flash-preview`), 8 s hard timeout then offline ranking (`feature-find-ai`). Rename `GEMMA_MODEL` → `AI_MODEL` in any `.env` you have; no API change. Demo event ID is now `devfest` (see feature:maps).
- 2026-10-11 04:18 · ACTION · for: mobile · Find contract 0.2.0 (additive, mobile#13): optional meeting `time` ("HH:mm") on `putMeetingSpot` and on `Contact.meetingSpot`; the service stores and returns it. See the answers in mobile#13 below.
- 2026-10-11 03:37 · ACTION · for: mobile · **Find service runs** (`backend/find`, `:8083`, see *How to consume*). You can switch `FindRepository` from demo data to it: `putMyProfile` from onboarding/Profile, `joinFind` when an event opens, then recommendations/search/person/contacts/meeting spot. Contract 0.1.1 is fixture-only over 0.1.0. Meeting spot `place` must be a feature name on the published map (e.g. "Info pult").
- 2026-10-11 03:22 · ACTION · for: mobile · Find contract 0.1.0 (`contracts/find/openapi.yaml`, see `CHANGELOG.md` for the differences from `api-needs.md`). You can wire `FindRepository` against it now; the service follows (announced here when it runs). Profile + consents (`/v1/me/profile`), `joinFind` per event, recommendations from the saved profile, prompt search, person, contacts (seeded demo people accept at once), meeting spot = a feature name on the published map.
- 2026-10-11 03:19 · INFO · for: all · `feature:find` now held by @Vertiglo (`docs/decisions/team-find-holder.md`, mobile#12). `feature:echo` stays with @MilosBG03. Contract (`contracts/find/openapi.yaml`) comes first.
- 2026-10-11 01:56 · INFO · for: all · `feature:find` registered (@MilosBG03, same holder as `feature:echo`). It takes the Find part of `mobile#5`: API-9 recommendations, API-10 prompt search, API-11 contact requests, API-15 meeting spot, and the profile + consent part of API-14. The rest of `mobile#5` (join, agenda, My events, organizer) stays with backend/contracts.

## Outbound requests (we need something from another module)

| ID | To | Request | Status | Opened |
| --- | --- | --- | --- | --- |
| — | | | | |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#23 | mobile | Done (`35e023a`): `cd backend/find && RESET=1 make seed` first removes everyone who isn't `demo-attendee-*` from the event's Find (presence and the event in their profile) and deletes all contacts at the event, then seeds as usual. Profiles stay (a phone keeps its own). Checked on the emulators: a test user + contact → after the reset 20 people, 0 contacts. Note: a phone that was in Find must re-join (restart the app) after a reset, and two phones that are both "Visible in Find" will still see each other. | done | 2026-10-11 |
| mobile#15 | mobile | Done: recommendations' `why` and prompt search run on `AI_MODEL` (default `gemini-3-flash-preview`, thinking `low`, +1024 output tokens); one call incl. retries is cut at 8 s and falls back to offline ranking (`model: offline`); `model` names the model that answered. Decision [`feature-find-ai`](../../docs/decisions/feature-find-ai.md). Unit tests for the timeout fallback and the token pad; **not measured against the real API** (no key on this machine). No contract change (description only). | done | 2026-10-11 |
| mobile#13 | mobile | (1) Done: 0.2.0 adds optional `time` ("HH:mm", 24 h) to the meeting spot, so you can stop keeping it on the device. (2) No field needed: `requestContact` to a seeded demo attendee already returns `state: accepted` in the same response (real people return `requested`), so show what comes back. Rate limit: recommendations + search share 20 per user at once, refilling 20/min; reloading on each consent toggle is fine. The service runs: see *How to consume* (announced 03:37). | done | 2026-10-11 |
| mobile#5 (API-9, API-10, API-11, API-15, profile part of API-14) | mobile | Done: contract 0.1.1 + service `backend/find` (see *How to consume*). | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal ID | Response (`ack` / `object: <reason + counter-proposal>`) | Date |
| --- | --- | --- |
| — | | |
