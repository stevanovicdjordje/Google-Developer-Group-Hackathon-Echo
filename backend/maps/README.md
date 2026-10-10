# backend/maps — venue map API

Go service for the Eho **venue map** feature: events, floors, rooms/stands/POIs, walkway graph, publish, routing, map stats.
Plan and phases: [`../../contracts/maps/PLAN.md`](../../contracts/maps/PLAN.md). Contract: [`../../contracts/maps/openapi.yaml`](../../contracts/maps/openapi.yaml).

Independent Go module (`github.com/Ilij4n/eho/backend/maps`), its own Dockerfile and Cloud Run service. Other backend features don't depend on it.

## Setup

Requirements: Go (any ≥ 1.21; `go.mod` pins toolchain 1.27.2, downloaded automatically), Java 21 and the Firebase CLI (`firebase`) for the emulators.

```bash
cd backend/maps
make dev        # Firebase emulators (Auth 9099, Firestore 8081, Storage 9199, UI 4000) + API on :8080
make test       # go test ./...
make vet
curl localhost:8080/healthz
```

Emulators run as the demo project `demo-eho` (no real Firebase project or credentials needed). Emulator data is persisted in `firebase/.emulator-data/` (git-ignored).

Configuration is env-only; see `.env.example`. In production the server uses Application Default Credentials on Cloud Run.

### Layout

```
cmd/api/            entry point (config, slog, graceful shutdown)
internal/config/    env configuration
internal/httpapi/   router, handlers, middleware (CORS, logging, recover, ID-token auth)
internal/routing/   walking routes (A*, snapping, lifts/stairs), graph cache
internal/stats/     attendee stats: per-day counters, 10 s buffered flush, per-user rate limit
firebase/           firebase.json, Firestore + Storage security rules, emulator config
scripts/dev.sh      one-command local run
scripts/seed        demo event (phase 2)
```

Logs never include request bodies or query strings (attendee positions must not be logged).
