# What the app needs from the backend

**For:** whoever builds the AI/event backend (and the contracts holder).
**From:** `mobile` (@Ilij4n's agent), 2026-10-11. Tracked as request `mobile#5` in `mobile/STATUS.md`.

The app skeleton in `mobile/app/` already runs the whole demo flow (`docs/MVP.md`) on **hardcoded demo data**. Each item below is one place where a demo implementation should be replaced by a real endpoint. The app side is ready: every item is one method on an interface in [`mobile/app/lib/data/repositories.dart`](../app/lib/data/repositories.dart), and the screens don't change when the provider switches from the demo to an HTTP implementation.

Paths and shapes below are **suggestions** (`x-status: illustrative`) for the contracts holder to turn into `contracts/…/openapi.yaml`. Anything that already exists in `contracts/maps/` (events, publish) should be reused, not duplicated.

Auth for all of them: `Authorization: Bearer <Firebase ID token>` (`team-auth`). Attendees are anonymous users; organizer operations check `ownerUid`.

## Priority for the video

| Priority | IDs | Why |
| --- | --- | --- |
| 1 | API-6, API-8, API-9, API-10, API-12 | The AI moments in the video |
| 2 | API-1, API-2, API-3, API-13 | Real event join and agenda |
| 3 | API-4, API-5, API-7, API-11 | Echo live data, contact. Fine to keep on demo data for the video. |

## Endpoints

> **Wired (M-18):** API-4 … API-8 and translation use `contracts/echo` 0.3.0 (`backend/echo`, port 8082) through `EchoApiRepository` (`mobile/app/lib/data/echo_api_repository.dart`). The suggested shapes below for those rows are superseded by that contract. The app falls back to demo data when the Echo service or Firebase isn't available.
> **0.3.0 (M-21, mobile#9):** the summary page renders the structured `summary` (takeaway, key points, trade-offs with `atSeconds` links back into the transcript; falls back to splitting `text` when absent), the Q&A sheet shows `mergedCount` and handles `200 merged: true` from `submitQuestion`, and catch-up / ask / summary send `language=sr` while Echo's translate toggle is on.

| ID | Screen | Interface method | Suggested endpoint | Request → response |
| --- | --- | --- | --- | --- |
| API-1 | Join (`/e/{eventId}`) | `EventRepository.getEvent` | `GET /v1/events/{eventId}/public` | → `{id, name, dates, venue}` (published events only) |
| API-2 | Join | `EventRepository.join` | `POST /v1/events/{eventId}/attendees/me` | → `204`. Also feeds My events (API-14). |
| API-3 | Agenda, Session | `EventRepository.agenda` | `GET /v1/events/{eventId}/sessions` | → `[{id, title, stage, start, end, track, description, isBreak, speakers:[{id,name,title}]}]`. `stage` must equal a room name on the venue map (the app links them by name). |
| API-4 | Echo | `EchoRepository.transcript` | Firestore listener on `events/{eventId}/sessions/{sessionId}/transcript` (same pattern as `contracts/maps/realtime.md`) | ordered lines `{atSeconds, text}`. **For the demo:** a pre-recorded transcript written line by line by a small replay script. |
| API-5 | Echo → Catch up | `EchoRepository.catchUp` | `GET /v1/events/{e}/sessions/{s}/catch-up` | → `{text}`: short summary of the transcript so far (AI) |
| API-6 | Echo → Ask AI | `EchoRepository.ask` | `POST /v1/events/{e}/sessions/{s}/ask` | `{question, language?}` → `{answer}`: answer grounded in the transcript so far (AI) |
| API-7 | Echo → Q&A | `questions` / `submitQuestion` | `GET` / `POST /v1/events/{e}/sessions/{s}/questions`, `POST …/questions/{q}/vote` | `{text}` → `{id, text, votes, mine}` |
| API-8 | Echo → Full summary (premium) | `EchoRepository.fullSummary` | `GET /v1/events/{e}/sessions/{s}/summary` | → `{text}` (AI). Paywall is mocked in the app; no payment check needed. |
| API-9 | Find → Recommended | `FindRepository.recommendations` | `GET /v1/events/{e}/people/recommendations` | → `[{person:{id,name,headline,interests,lookingFor}, why}]` ranked by AI from the caller's profile. Only people with **Visible in Find** on (`docs/DATA_PRIVACY.md`). |
| API-10 | Find → prompt search | `FindRepository.search` | `POST /v1/events/{e}/people/search` | `{prompt}` → same shape as API-9 |
| API-11 | Person → Contact | `FindRepository.requestContact` | `POST /v1/events/{e}/contacts` | `{personId}` → `{state: requested}`. For the video the app auto-accepts after 2 s. |
| API-12 | Organizer → Build with AI | `OrganizerRepository.extract` | `POST /v1/organizer/drafts` (multipart files) | → `{name, dates, venue, stages[], sessions[], speakers[]}` extracted by AI from unstructured files (PDF, DOCX, XLSX, images). Precomputing the result for the demo files is OK if the model is slow. |
| API-13 | Organizer → Publish | `OrganizerRepository.publish` | `POST /v1/organizer/drafts/{id}/publish` | → `{eventId, url}`. Should create/publish the event in the same place `contracts/maps` publishes the venue, so the join link and the Map tab use one `eventId`. |
| API-14 | My events, Profile | (client state today) | `GET /v1/me/events`, `PUT /v1/me/profile` | Joined events; profile + consent switches `{name, headline, interests, lookingFor, visibleInFind, allowContact, shareMeetingSpot}` |
| API-15 | Messages → meeting spot | (client state today) | `PUT /v1/events/{e}/contacts/{personId}/meeting-spot` | `{place}` (a feature name from the venue map). Messages themselves stay **mocked** (`docs/MVP.md`). |

## AI notes

- Models are chosen per feature (`docs/MVP.md`): Gemma (Gemini API) for translation, others where they work better. Keep each model behind a backend adapter.
- Translation (Echo 🌐 button): **wired** to `POST …/sessions/{s}/translate {language, fromIndex}` (`contracts/echo`). The demo transcript's precomputed Serbian text is only used on demo data.
- Every AI response is untrusted input: validate shapes before returning (`AGENTS.md` rule 12).

## How to hook an endpoint into the app

1. Implement the interface in `mobile/app/lib/data/` with `ApiClient` (`core/api/api_client.dart`).
2. Point the provider (`eventRepositoryProvider`, `echoRepositoryProvider`, …) at it.

That's a `mobile` change: post the endpoint in your STATUS (*How to consume* + announcement) and the mobile agent wires it.
