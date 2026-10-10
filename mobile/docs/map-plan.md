# Venue map module: plan and phases

Owner: @Vertiglo (works **only** on the venue map). Covers the map parts of `mobile/app/` (`lib/features/maps/`), `backend/maps/` and `contracts/features/maps/`.
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
| 2 | Backend CRUD + auth: OpenAPI spec, ID-token middleware, CRUD for event/floor/feature/graph, validation, publish, seed script (~3 rooms, ~15 stands, POIs, graph, 3 QR markers) | `go test ./...` passes, incl. handler tests with a fake store | 🔄 |
| 3 | Attendee map viewer: realtime read of the published seed event, zoom/pan, tap → details, search | Works on the seed event | ⏳ |
| 4 | Organizer editor: plan upload, drawing via API, publish | A published change is visible on another device in < 2 s | ⏳ |
| 5 | Routing: Go package (A*, snapping, multi-floor) + endpoint + cache; Flutter draws the route from a QR marker to a stand | Tests and benchmark pass (< 100 ms for a few thousand nodes) | ⏳ |
| 6 | Location: georeferencing (3 points, affine), GPS dot with accuracy, QR/manual fallback, tracking, re-routing, "Stigli ste" | Go and Dart transform tests pass on the same vectors (`contracts/features/maps/testdata/`) | ⏳ |
| 7 | Stats: batched events, daily aggregation, rate limit, organizer screen | | ⏳ |
| 8 | Polish + deploy: security-rule tests, QR print page, Cloud Run + Firebase Hosting, docs | | ⏳ |

Before reporting a phase as done: `go vet ./...`, `go test ./...`, `flutter analyze`, `flutter test`.

## Where things live

| What | Where |
| --- | --- |
| Flutter app | `mobile/app/lib/features/maps/` (`viewer/`, `editor/`, `location/`, `stats/`) |
| Go API | `backend/maps/` (own Go module: `cmd/api`, `internal/...`) |
| HTTP contract | `contracts/features/maps/openapi.yaml` |
| Firestore paths readable by clients | `contracts/features/maps/realtime.md` |
| Shared transform test vectors | `contracts/features/maps/testdata/` |
| Firebase rules + emulator config | `backend/maps/firebase/` |
| Indoor-GPS problem and solution (for the pitch) | `backend/maps/docs/implementation-notes.md` |
