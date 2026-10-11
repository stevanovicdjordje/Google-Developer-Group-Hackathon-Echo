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
| 8 | Polish + deploy: security-rule tests, QR print page, Cloud Run + Firebase Hosting, docs | Rule tests pass on the emulators; QR signs print from the editor; the map is live on a real URL and opens on a phone from a printed QR | 🔄 code done, deploy waits for a real project |

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

## Where we stopped (2026-10-11 02:50)

Phases 1–7 done; phase 8 code done (per-phase details: git history and `STATUS.md`).

**Phase 8 so far.**
- Security rules: `backend/maps/internal/rulestest` checks the Firestore and Storage rules on the emulators
  (`make rules-test` with `make dev` running; skipped by plain `go test` without the emulators).
- QR signs: editor (published events) → `/o/e/{id}/qr` (`editor/qr_screen.dart`, `qr_print.dart`): one sign per "you are here"
  marker pointing to `/e/{id}?at={markerId}`, plus an A4 print sheet (web).
- Deploy: `make deploy PROJECT=<id>` (`scripts/deploy.sh`: rules + API on Cloud Run, optional Hosting with `WEB_BUILD=...`),
  `firebase/firebase.hosting.json` (SPA fallback); guide in `backend/maps/README.md` → "Deploy".
- Tests (after merge to `main`): `go vet` + `go test ./...` pass, `make rules-test` passes on the emulators; `flutter test` 77/77,
  `flutter analyze` clean (`mobile/maps`, `mobile/app`).

**Next:** the real deploy. It needs a Firebase project on the Blaze plan (billing) from @Vertiglo; then print the QR signs from
the deployed app so they point to the real URL. Open for @Vertiglo: `contracts/maps/KAKO-RADI.md` §9 (routing) and a GPS
section (not committed by the agent unless asked).

How to run: `cd backend/maps && make dev`, `make seed`, `cd mobile/app && flutter build web`, serve `build/web` with SPA fallback
on :5000, open `/e/<eventId>` (attendee) or `/o` (organizer, emulator login `organizer@eho.test` / `eho-demo-123`).
