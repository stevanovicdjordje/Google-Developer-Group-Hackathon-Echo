# Venue map module: plan and phases

Owner: @Vertiglo (works **only** on the venue map). The map lives in `mobile/maps/` (Flutter package), `backend/maps/` (Go service) and `contracts/maps/` (API contract, this plan).
No Gemma/LLM in this module. Other Eho features (captions, Q&A, networking) are out of scope here.

## Goal

1. Organizer uploads a floor plan and marks rooms, stands, POIs, walkways (routing graph) and "you are here" QR markers.
2. Attendee opens a link/QR, sees the plan, finds a stand/room and gets a **route** (computed by the backend), with a live **GPS dot**.
3. Organizer changes are visible to attendees right after **publish** (Firestore realtime).
4. Organizer sees **stats**: searches (incl. ones with no results), viewed stands, route targets, QR scans. Never GPS coordinates.

## Phases

Status: ✅ done · 🔄 in progress · ⏳ not started

| # | Phase | Done when | Status |
| --- | --- | --- | --- |
| 1 | Setup: Flutter app, Go skeleton (`/healthz`, config, slog, Dockerfile), Firebase emulators, one-command local run | App and backend run locally against the emulators | ✅ |
| 2 | Backend CRUD + auth: OpenAPI spec, ID-token middleware, CRUD for event/floor/feature/graph, validation, publish, seed script (~3 rooms, ~15 stands, POIs, graph, 3 QR markers) | `go test ./...` passes, incl. handler tests with a fake store | ✅ |
| 3 | Attendee map viewer: realtime read of the published seed event, zoom/pan, tap → details, search | Works on the seed event | 🔄 |
| 4 | Organizer editor: plan upload, drawing via API, publish | A published change is visible on another device in < 2 s | ⏳ |
| 5 | Routing: Go package (A*, snapping, multi-floor) + endpoint + cache; Flutter draws the route from a QR marker to a stand | Tests and benchmark pass (< 100 ms for a few thousand nodes) | ⏳ |
| 6 | Location: georeferencing (3 points, affine), GPS dot with accuracy, QR/manual fallback, tracking, re-routing, "Stigli ste" | Go and Dart transform tests pass on the same vectors (`contracts/maps/testdata/`) | ⏳ |
| 7 | Stats: batched events, daily aggregation, rate limit, organizer screen | | ⏳ |
| 8 | Polish + deploy: security-rule tests, QR print page, Cloud Run + Firebase Hosting, docs | | ⏳ |

Before reporting a phase as done: `go vet ./...`, `go test ./...`, `flutter analyze`, `flutter test`.

## Where things live

| What | Where |
| --- | --- |
| Flutter feature package | `mobile/maps/` (`eho_maps`: model, viewer, editor, location, stats); the app shell `mobile/app/` mounts it |
| Go API | `backend/maps/` (own Go module: `cmd/api`, `internal/...`) |
| HTTP contract | `contracts/maps/openapi.yaml` |
| Firestore paths readable by clients | `contracts/maps/realtime.md` |
| Shared transform test vectors | `contracts/maps/testdata/` |
| Firebase rules + emulator config | `backend/maps/firebase/` |
| Indoor-GPS problem and solution (for the pitch) | `contracts/maps/implementation-notes.md` |

## Where we stopped (2026-10-10 ~22:30)

Phase 3 (attendee viewer) is built in `mobile/maps/lib/src/viewer/` and mounted at `/e/{eventId}` in `mobile/app`:
realtime Firestore read, zoom/pan without rotation, rooms/stands/POIs/labels, gold sponsors highlighted, tap → details sheet,
diacritic-tolerant search ("cacak" finds "Čačak Dev") with kind/category filters, floor switcher, legend, deep link `/e/{id}/stand/{id}`.
`flutter analyze` clean, `flutter test` 16/16 in mobile/maps, 4/4 in mobile/app. Verified in Chrome against the emulators (plan, search).

**Open bug (next step):** in headless Chrome about every second page load stays on "Učitavam plan…": `mapsSignedInProvider`
(`mobile/maps/lib/src/viewer/providers.dart`) fails and Riverpod 3 auto-retries it forever. Temporary `debugPrint('[maps] …')`
logs are in that file to find the sign-in error. Fix: find the error, then put a timeout / no-retry on the sign-in so the UI shows
"Server nije dostupan" + retry instead of spinning; then remove the debug prints and mark phase 3 ✅.

How to reproduce: `cd backend/maps && make dev`, `make seed`, `cd mobile/app && flutter build web`, serve `build/web` with SPA fallback on :5000, open `/e/<eventId>`.
