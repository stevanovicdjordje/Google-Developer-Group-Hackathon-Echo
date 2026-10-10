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
| 5 | Routing: Go package (A*, snapping, multi-floor) + endpoint + cache; Flutter draws the route from a QR marker to a stand | Tests and benchmark pass (< 100 ms for a few thousand nodes) | ✅ |
| 6 | Location: georeferencing (3 points, affine), GPS dot with accuracy, QR/manual fallback, tracking, re-routing, "Stigli ste" | Go and Dart transform tests pass on the same vectors (`contracts/maps/testdata/`) | ✅ |
| 7 | Stats: batched events, daily aggregation, rate limit, organizer screen | Organizer sees attendee searches/views/routes/QR scans per day; no positions | ✅ |
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

## Where we stopped (2026-10-11 01:15)

Phases 1–7 are done (viewer `/e/{id}`, editor `/o`, `/o/e/{id}`, routing, location, stats; details in git history and `STATUS.md`).

**Phase 7 (stats) ✅.** Contract 0.3.0: `recordStats`, `getStats`.
- Server (`backend/maps/internal/stats`, `httpapi/stats.go`): attendees send batches (≤ 50) of `search` (query + result count),
  `feature_view`, `route` (target), `qr_scan` (marker). Features not on the published map (or markers as views) are dropped, queries
  are lowercased and cut to 60 chars. Per-user token bucket (120 at once, 120/min) → `429` + `Retry-After`. Counts are buffered in
  memory and added every 10 s (and on shutdown, and before an owner read) to one doc per event and UTC day
  `events/{id}/stats/{yyyy-mm-dd}` in a transaction (map keys ≤ 500 each). No user IDs, no times of day, never positions.
- `getStats` (owner): every day of the range + top lists (searches, searches without results, opened, route targets, QR scans) with
  names from the current published map (removed features → empty name). Default range: last 30 days.
- App: `stats/stats_reporter.dart` (batches every 10 s / 20 events / on close, failures dropped, QR once, same search not twice in a
  row). The viewer reports QR on open with `?at=`, a search after 1.5 s without typing or when a result is opened, opened details,
  route targets. Organizer: chart icon in the editor (published events) → `/o/e/{id}/stats` (`stats/stats_screen.dart`): range
  (event dates / today / 7 / 30 days), tiles, activity per day, "Traže, a ne nalaze", top lists, privacy note.
- Tests: `go test ./...` + `go vet` pass, incl. `TestFirestoreStats` against the emulator (keys with `.`, `/`, backticks);
  `flutter test` 72/72, `flutter analyze` clean (`mobile/maps`, `mobile/app`). E2E on the emulators (API from this branch on :8090):
  API script (record → 202 5/1 dropped, attendee read 403, organizer totals, 429 after 120 events, doc holds only counters) and
  headless Chrome in the app (QR link → search without results → search + open Kvant → route; all arrived; organizer login →
  editor → stats screen shows them). Test stats were deleted from the demo event afterwards.
- A running `make dev` from before this phase has no stats endpoints: restart it.

**Phase 6 (location) ✅.**
- Shared vectors `contracts/maps/testdata/georef.json` (5 cases + 1 degenerate), generated and checked by
  `backend/maps/internal/geo/vectors_test.go` (`go test ./internal/geo -run TestSharedVectors -update` rewrites them) and checked by
  `mobile/maps/test/location/georef_vectors_test.dart` against `lib/src/location/georef.dart` (mirror of `geo/affine.go`).
- Editor: floor menu "Podesi GPS (georeferenciranje)" → `editor/georef_screen.dart`: tap 3 spots, paste "lat, lng" from Google Maps;
  live scale / error estimate (warning above 5 m, collinear points refused); `putFloorGeoref` / `deleteFloorGeoref`.
- Viewer: "Moja lokacija" (only if a floor is georeferenced) → `location/location_source.dart` (geolocator, same version the app
  locks). Dot + accuracy circle on the floor being viewed (GPS has no floor). Usable fix = inside the plan and ±25 m or better; then it
  is "Vi ste ovde" and the route start. Otherwise a hint (searching / imprecise / outside / floor without GPS / denied) and the QR or
  "tap on the map" fallback. Following (`location/tracking.dart`): > max(15 m, 1.5 × accuracy) off the route → new route (at most every
  8 s, camera kept); within ~6 m of the end → "Stigli ste: …" and the route closes. A lost signal keeps listening ("Tražim GPS
  signal…"); denied / location off stop GPS with an explanation. Positions are never stored or logged (`DATA_PRIVACY.md`).
- Tests: `go test ./...` + `go vet` pass; `flutter test` 63/63, `flutter analyze` clean (`mobile/maps`, `mobile/app`). Headless Chrome
  with an emulated position on the demo event (seed floor is georeferenced): dot + circle, route from GPS 46 m (same as the API),
  ~18 m off → re-routed (35 m), at the end → "Stigli ste: Glavna sala". The editor GPS screen is covered by widget tests (fake server),
  not run against the real API.
- Native builds: location permissions were added by mobile (maps#2 done, `3cee092`).
- Open: `contracts/maps/KAKO-RADI.md` §9 (routing) and a new section on GPS are for @Vertiglo (asked not to commit that file again).
- Testing tip: CDP clicks into Flutter web need a `mouseMoved` first; an emulated position is lost when the CDP session closes.

**Next: phase 8** (polish + deploy: security-rule tests, QR print page, Cloud Run + Firebase Hosting, docs). Deploying needs a
real Firebase/GCP project and billing: ask @Vertiglo first.

How to run: `cd backend/maps && make dev`, `make seed`, `cd mobile/app && flutter build web`, serve `build/web` with SPA fallback
on :5000, open `/e/<eventId>` (attendee) or `/o` (organizer, emulator login `organizer@eho.test` / `eho-demo-123`).
