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
| 5 | Routing: Go package (A*, snapping, multi-floor) + endpoint + cache; Flutter draws the route from a QR marker to a stand | Tests and benchmark pass (< 100 ms for a few thousand nodes) | 🔄 |
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

## Where we stopped (2026-10-11 00:04)

Phases 1–4 are done (viewer `/e/{id}`, editor `/o`, `/o/e/{id}`; details in git history and `STATUS.md`).

**Phase 5 (routing): server side done, app side next.**
- Done: `backend/maps/internal/routing/` (graph over all floors, lifts/stairs via `Node.connector`, A* by walking time,
  snapping of points onto walkways, straight runs merged, LRU cache per published version), endpoint `POST /v1/events/{id}/route`
  (`internal/httpapi/route.go`), contract 0.2.0 (`getRoute`, fixtures). Tests: A* equals Dijkstra on random grids,
  0.5 ms per route on 5000 nodes (target < 100 ms), handler tests incl. cache refresh after a new publish. Verified against the
  emulators on the demo event (Ulaz (QR) → Glavna sala: 52 m, 43 s, 2.8 ms per request).
- **Next (app, `mobile/maps`):**
  1. `MapsApi.getRoute` + `Route` model (Dart) and a provider; the viewer needs `mapsApiBaseUrlProvider` (already exported).
  2. Viewer: "Prikaži put" button in the feature details sheet. Start = the `?at=` QR marker if present, else a picker
     (QR markers + entrances, or "tap on the map").
  3. Draw the route (polyline per floor, start/end dots), a summary card (distance, minutes, "procena" when estimated, close),
     and for multi-floor routes a banner "Idite liftom/stepenicama na sprat X" that switches the floor.
  4. Show the "Vi ste ovde" dot for `?at=`; widget tests with a fake API; check in headless Chrome.
  5. Update `contracts/maps/KAKO-RADI.md` §9 (routing) — @Vertiglo asked not to commit that file again; leave it for them.
- Then phase 5 is ✅; phase 6 (georeferencing + GPS dot) follows.

How to run: `cd backend/maps && make dev`, `make seed`, `cd mobile/app && flutter build web`, serve `build/web` with SPA fallback
on :5000, open `/e/<eventId>` (attendee) or `/o` (organizer, emulator login `organizer@eho.test` / `eho-demo-123`).
