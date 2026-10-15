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
make rules-test # Firestore + Storage security rules against the running emulators
curl localhost:8080/healthz
```

Emulators run as the demo project `demo-eho` (no real Firebase project or credentials needed). Emulator data is persisted in `firebase/.emulator-data/` (git-ignored). They listen on all interfaces, IPv4 and IPv6 (`"::"`), so phones on the same Wi-Fi (`<laptop-ip>:8081`) and over `adb reverse` (`::1`) reach them; the API listens on `:8080` too.

`make seed` publishes the demo event "DevFest Belgrade 2026" with the fixed ID **`devfest`** (`EVENT_ID=<id> make seed` for another, `EVENT_ID= ` for random); re-seeding replaces it and keeps the ID, so the app's `DEMO_EVENT_ID=devfest` never changes. Echo's `make replay` and Find's `make seed` find it by name.

Configuration is env-only; see `.env.example`. In production the server uses Application Default Credentials on Cloud Run.

### Layout

```
cmd/api/            entry point (config, slog, graceful shutdown)
internal/config/    env configuration
internal/httpapi/   router, handlers, middleware (CORS, logging, recover, ID-token auth)
internal/routing/   walking routes (A*, snapping, lifts/stairs), graph cache
internal/stats/     attendee stats: per-day counters, 10 s buffered flush, per-user rate limit
internal/rulestest/ security-rule tests (emulators only; loads the rule files from firebase/ first)
firebase/           firebase.json, Firestore + Storage security rules, emulator config;
                    firebase.hosting.json (web app hosting, separate so `make dev` doesn't start it)
scripts/dev.sh      one-command local run
scripts/deploy.sh   rules + Cloud Run + optional Hosting
cmd/seed            demo event
```

The Firestore rules here are the **project's** rules: Echo (`backend/echo`) stores its transcript under
`events/{id}/published/echo/**` and relies on them; `make rules-test` covers that path too.

## Deploy (Cloud Run + Firebase Hosting)

Not deployed yet. Needs a real Firebase project on the Blaze plan (Cloud Run needs billing), with Firestore
(native mode), Storage and Authentication (Email/Password + Anonymous) enabled in the console, and locally
`firebase login` + `gcloud auth login`. No key files: Cloud Run uses its service account.

```bash
cd backend/maps
make rules-test                                   # with `make dev` running
make deploy PROJECT=<project-id>                  # rules + API (europe-west1, 1 instance, min 1)
# with the web app (built by mobile against the real project and the API URL printed above):
WEB_BUILD=../../mobile/app/build/web make deploy PROJECT=<project-id>
```

- API env on Cloud Run: `FIREBASE_PROJECT_ID`, `STORAGE_BUCKET` (default `<project>.firebasestorage.app`;
  set `STORAGE_BUCKET=<project>.appspot.com` for older projects), `ALLOWED_ORIGINS` (the project's `web.app` and
  `firebaseapp.com` domains + `EXTRA_ORIGINS`).
- One instance on purpose: stats are buffered in memory for 10 s and the route cache is per instance. More
  instances would still be correct (counters are added in transactions), only the rate limit gets looser.
- Hosting serves the build with an SPA fallback (`/e/{id}?at=…` and `/o/...` open the app) and `no-cache`,
  because Flutter's file names aren't hashed. QR signs printed from the deployed app point to the deployed
  origin.
- `make seed` works only against the emulators. On a real project, sign up as an organizer in the app (`/o`)
  and create the event in the editor.

Logs never include request bodies or query strings (attendee positions must not be logged).
