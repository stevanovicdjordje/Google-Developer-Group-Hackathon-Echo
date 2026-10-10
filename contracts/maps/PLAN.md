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
| 3 | Attendee map viewer: realtime read of the published seed event, zoom/pan, tap → details, search | Works on the seed event | ✅ |
| 4 | Organizer editor: plan upload, drawing via API, publish | A published change is visible on another device in < 2 s | ✅ |
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

## Where we stopped (2026-10-10 23:48)

Phases 1–4 are done.

**Phase 4 (organizer editor)** is in `mobile/maps/lib/src/editor/`, routes `/o` (organizer sign-in + "My events" + new event)
and `/o/e/{eventId}` (editor). Tools: select, room (2 taps = rect, 3+ = polygon), stand (2 corners), place/POI, QR marker,
walkway (tap to add nodes, tap a node to connect; saved as one `PUT graph` 400 ms after the last tap). Add/rename/delete a floor
(the plan image goes to Storage, then `createFloor`). Properties panel per type, move, delete, "Nearest node" as route entrance
(new features get the nearest node automatically). Publish shows localized errors/warnings; tapping one selects that feature.
Verified in headless Chrome against the emulators: whole flow from a new event to publish, and an open attendee viewer showed a
moved stand **0.6 s** after "Objavi". `flutter analyze` clean; `flutter test` 33/33 (mobile/maps), 4/4 (mobile/app).

Known limits: no undo; moving a feature is "Move" + tap (no drag); node connectors between floors (lift/stairs) and georef are
not editable in the UI yet (phases 5/6).

**Next:** phase 5 (routing). Product note: the demo storyline has "Agenda → picks a talk → Map shows the stage", so the
agenda feature will need a link to a room on the map; `/e/{id}/stand/{featureId}` already opens any feature (rooms too).

How to run: `cd backend/maps && make dev`, `make seed`, `cd mobile/app && flutter build web`, serve `build/web` with SPA fallback
on :5000, open `/e/<eventId>` (attendee) or `/o` (organizer, emulator login `organizer@eho.test` / `eho-demo-123`).
