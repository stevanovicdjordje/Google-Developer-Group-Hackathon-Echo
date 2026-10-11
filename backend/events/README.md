# Events service (`backend/events`)

Public event info and join, "My events", the published agenda, and the
organizer import: upload files → AI extracts a draft → review → publish.
Implements [`contracts/events/openapi.yaml`](../../contracts/events/openapi.yaml)
(0.1.0). Go, Firebase Auth ID tokens, Firestore, a Gemini model through the
Gemini API ([`feature-events-ai`](../../docs/decisions/feature-events-ai.md)).

Events are the venue map's `events/{eventId}` documents (`backend/maps`): an
agenda is published into the same ID (the demo event is `devfest`), so the join
link, the Map tab and the agenda share it.

## Run

The Firebase emulators and the demo event come from `backend/maps`
(`make dev`, `make seed` there).

```bash
cd backend/events
make dev        # API on :8084 (reads .env if present)
make seed       # the demo agenda (7 sessions, keynote = s1 for Echo) into devfest
make test       # go test ./...
```

| Var | Default | |
| --- | --- | --- |
| `PORT` | `8084` | |
| `FIREBASE_PROJECT_ID` | (required) | `demo-eho` locally |
| `ALLOWED_ORIGINS` | `http://localhost:*,http://127.0.0.1:*` | CORS; `:*` = any port |
| `GEMINI_API_KEY` | empty | empty = drafts only from spreadsheets/CSV (`model: offline`) |
| `AI_MODEL` | `gemini-3-flash-preview` | `gemma-*` also works |
| `AI_THINKING` | `low` (`minimal` for `gemma-*`) | |
| `EXTRACT_TIMEOUT_SECONDS` | `60` | one extraction, retries included |
| `LOG_LEVEL` | `info` | |

## Organizer import

`POST /v1/organizer/drafts` (multipart, field `files`): up to 10 files, 10 MiB
each, 20 MiB together; PDF, PNG, JPEG, WebP, XLSX, CSV, TXT, DOCX, recognised by
content. PDFs and images go to the model as inline data; XLSX, DOCX and text as
text. Without a key, or when the model fails, spreadsheets/CSV with a header row
(title + start or time; also stage/room/sala, end, day/date, speaker,
company/role, track, description, English or Serbian) are read directly.
Rate limit: 5 uploads per user, refilling 5/min.

Model output is untrusted (`AGENTS.md` rule 12): it must match the response
schema, then everything is cleaned (one line, length caps), times normalised to
`HH:mm`, dates checked, sessions without a title dropped, speakers deduplicated
and given IDs. The organizer reviews the draft (`PUT …/drafts/{id}`, strict
validation) and publishes (`POST …/publish {eventId?}`); nothing the model
returns is published without that step. Issues (missing stage/time/speaker,
overlaps on one stage) never block publishing. Sessions keep the ID of a
published session with the same title, so Echo and Q&A links survive.

## Data (Firestore, Admin SDK only; rules deny clients)

See `internal/store/store.go`: `events/{eventId}` (shared with the map),
`events/{eventId}/published/agenda`, `members/{uid}/events/{eventId}`
(`joinedAt`), `organizerDrafts/{draftId}`.

## Privacy

- Uploaded files are processed in memory and not stored; only the draft is.
  File names and content are never logged.
- "My events" stores only which events a user joined and when; `DELETE
  /v1/events/{id}/join` removes it.
- Speaker names and roles in an agenda are organizer content, published on purpose.

## Demo upload files

`demo/` holds fictional organizer files that match the app's demo data: `devfest-agenda-final-v3.pdf` (the
programme as a flyer; "Designing for crowded rooms" has no room, so the review flags it), `speakers.xlsx` and
`devfest-agenda.csv` (works without an AI key). Rebuild them with `python3 -I scripts/demo_files.py`.
Upload as the demo organizer and publish into `devfest`.

## Deploy

After `backend/maps` (`make deploy PROJECT=<id>`: rules, map API, web app): `make deploy PROJECT=<id>` here and in
`backend/find`. Each prints its Cloud Run URL; the app needs them as `EVENTS_API_BASE_URL` / `FIND_API_BASE_URL`.
`GEMINI_API_KEY` (from the environment or `.env`) is stored once in Secret Manager as `gemini-api-key`.
