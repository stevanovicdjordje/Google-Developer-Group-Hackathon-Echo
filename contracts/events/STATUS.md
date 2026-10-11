# feature:events — STATUS

> **Single writer:** the `feature:events` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 06:48 · **Owner:** @Vertiglo · **Scopes held:** feature:maps, feature:find, feature:events

## Current state

Events backend, taken over from `mobile#17` (`docs/MVP.md` "Who builds what", no holder before): public event info + join (API-1, API-2), agenda (API-3), My events (API-14 events part), organizer upload → AI extraction → review → publish (API-12, API-13).
Paths: `backend/events/` (Go service, port 8084), `contracts/events/` (this folder), `docs/decisions/feature-events-*`. Screens stay in the app shell (`mobile`), wired through `EventRepository` / `OrganizerRepository`.
The agenda is published into the **same event ID the venue map uses** (`events/{eventId}`, e.g. `devfest`), so the join link, Map tab and agenda share one ID.

Contract 0.1.0 ([`openapi.yaml`](openapi.yaml)) is implemented by the Go service `backend/events` (port 8084, all 9 operations). The demo agenda (same content and session IDs as the app's demo data; keynote `s1` = Echo's replay session) is seeded into `devfest`.
AI: a Gemini model reads the uploads ([`feature-events-ai`](../../docs/decisions/feature-events-ai.md): `AI_MODEL`, default `gemini-3-flash-preview`); spreadsheets/CSV also work without a key (`model: offline`). PDFs/images without a key → `503 ai_unavailable`.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | Emulators + demo event first (`cd backend/maps && make dev`, `make seed`), then `cd backend/events && make dev` (API on `http://localhost:8084`) and `make seed` (demo agenda into `devfest`) |
| Auth | `Authorization: Bearer <Firebase ID token>`; attendees may be anonymous; `/v1/organizer/*` needs an organizer account (demo: `organizer@eho.test` / `eho-demo-123`, owner of `devfest`) |
| AI | `GEMINI_API_KEY` in `backend/events/.env` enables `AI_MODEL`; `createDraft` is synchronous (5–30 s with the model, cut at 60 s); show a progress state. Without a key only spreadsheets/CSV work |
| Upload | multipart field `files`, ≤10 files, 10 MiB each, 20 MiB total; PDF, PNG, JPEG, WebP, XLSX, CSV, TXT, DOCX. The app's `UploadedFile` (name + size) needs the bytes too |
| Publish | `POST /v1/organizer/drafts/{id}/publish {"eventId":"devfest"}` into the map's event, or `{}` for a new event; `joinPath` is `/e/{eventId}` (put your origin in front) |
| Demo upload files | `backend/events/demo/`: `devfest-agenda-final-v3.pdf`, `speakers.xlsx` (the names your dev shots already use) and `devfest-agenda.csv` (works without an AI key). Content = your demo data; "Designing for crowded rooms" has no room in the PDF, so the review flags it |
| Deploy | `make deploy PROJECT=<id>` in `backend/events` and `backend/find` (Cloud Run, after `backend/maps`' deploy); not deployed yet (waiting for a Firebase project) |
| Contract | [`openapi.yaml`](openapi.yaml) 0.1.0, [`CHANGELOG.md`](CHANGELOG.md), fixtures in [`examples/`](examples/) (`python3 contracts/events/scripts/validate_examples.py`) |

## Contract coverage

| Operation | Server (`backend/events`) | App |
| --- | --- | --- |
| `getPublicEvent`, `joinEvent`, `leaveEvent`, `listMyEvents`, `getAgenda` | implemented (handler tests); verified e2e with curl on the emulators | demo data (`DemoEventRepository`) |
| `createDraft`, `getDraft`, `updateDraft`, `publishDraft` | implemented (handler tests incl. a fake Gemini, CSV/XLSX/DOCX readers); CSV path verified e2e on the emulators; **real Gemini not measured** (no key on this machine) | demo data (`DemoOrganizerRepository`) |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 06:48 · INFO · for: mobile · Demo upload files for "Build with AI" in `backend/events/demo/` (PDF + XLSX named like your dev shots, plus a CSV that works without a key). Cloud Run deploy scripts for Events and Find are ready; deployed URLs follow once there's a Firebase project.
- 2026-10-11 05:31 · ACTION · for: mobile · Events API 0.1.0 runs (`backend/events`, :8084): API-1 `getPublicEvent`, API-2 `joinEvent`, API-3 `getAgenda` (`stage` = map room name, demo agenda seeded into `devfest` with the app's session IDs), API-14 `listMyEvents`, API-12 `createDraft` (multipart upload → AI draft), API-13 `updateDraft` + `publishDraft` into `devfest`. Wire `EventRepository` / `OrganizerRepository` when you're ready; see *How to consume*. Note: `UploadedFile` must carry the file bytes for `createDraft`.
- 2026-10-11 05:20 · INFO · for: mobile, all · Registered `feature:events` (@Vertiglo), answering `mobile#17`. Contract 0.1.0 follows; the app keeps demo data until then.

## Outbound requests (we need something from others)

| ID | To | What / why | Status | Updated |
| --- | --- | --- | --- | --- |
| events#1 | integration (@Ilij4n) | `team-import-formats` is still `open`. `mobile#17` asked for PDF/XLSX/images with AI extraction; events 0.1.0 accepts PDF, PNG, JPEG, WebP, XLSX, CSV, TXT, DOCX (≤10 files, 10 MiB each, 20 MiB total), AI extraction + organizer review, spreadsheets also without AI (`feature-events-ai`). Please record or adjust the team decision. | open | 2026-10-11 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#17 | mobile | Done: contract 0.1.0 + service `backend/events` for API-1, 2, 3, 12, 13 and the events part of API-14 (see *How to consume*). Gemini via `AI_MODEL`, honest `model` field (`feature-events-ai`). Publishes into the map's event ID. | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal | Response | Updated |
| --- | --- | --- |
