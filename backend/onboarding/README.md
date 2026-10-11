# backend/onboarding — Eho onboarding module

Server-rendered Go web app for the part of Eho that happens around an event:
organizer and participant registration, participant onboarding, event
management (wizard with venue map, zones and schedule), invitations,
participant panel, reviews and the post-event report ("ukupan utisak").

It is a **separate Go module** inside `backend/` (own `go.mod`, `cmd/`,
`internal/`). It does not import or modify the main backend API in
`backend/cmd/api` / `backend/internal`, and it does not implement anything from
`contracts/openapi.yaml` yet: it serves HTML, not JSON.

- Everything is Go: `net/http` (Go 1.22+ route patterns) + `html/template`.
- No JavaScript at all (the CSP is `script-src 'none'`). Interaction is plain
  HTML forms and links; charts and the floor plan are SVG generated on the server.
- One hand-written CSS file (`static/app.css`), no build step.
- UI text is Serbian (Latin script), kept in `internal/i18n/sr.go`.

## Run locally

Requirements: Go 1.26+ (the toolchain version comes from `go.mod`). No C compiler
needed: SQLite is `modernc.org/sqlite` (pure Go).

```bash
cd backend/onboarding
go run ./cmd/seed -reset       # optional: demo data (see below)
go run ./cmd/eho-web           # http://localhost:8080
```

The database (`./data/eho.db`) and uploaded floor plans (`./data/uploads/`)
are created on first start. Migrations run automatically. `data/` is git-ignored.

### Demo data

`go run ./cmd/seed -reset` deletes the local DB and uploads, then creates
clearly fake data:

| What | Details |
| --- | --- |
| Organizer | `organizator@eho.demo` / `demo-lozinka` |
| Participants | `ucesnik01@eho.demo` … `ucesnik20@eho.demo` / `demo-lozinka` (onboarding done) |
| Finished event | "Eho Dev Summit 2026", 10 days ago: 20 invited, 16 accepted, 13 reviews with comments and session ratings |
| Ongoing event | "AI meetup Beograd", started 2 hours ago |
| Upcoming event | "Startap vikend Novi Sad", in 14 days, two days of sessions |

Each event has a generated floor plan with 10 zones (3 halls, booths, food,
info desk, toilets, entrance) and a schedule. Without `-reset` the command
refuses to run on a database that already has the demo organizer.

Good demo path: log in as the organizer → list → "Izveštaj" on the finished
event. Then log in as `ucesnik01@eho.demo` → the ongoing event → click a hall
on the floor plan.

### Tests

```bash
go vet ./...
go test ./...
```

Unit tests cover event status transitions, session overlap detection and the
schedule grid, invitation status and response rules, review rules, report
computation, the statistical summarizer, CSV export (including formula
injection), validation and i18n key coverage. HTTP tests (`internal/app`) run
the full flow against a real SQLite file: registration, roles and ownership
isolation, CSRF, onboarding, event wizard incl. plan upload, invitations
(register-from-invite), publishing, review and report/CSV.

## Configuration (environment variables)

See `.env.example`. Nothing secret is committed.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8080` | HTTP port (Cloud Run sets it) |
| `EHO_DB_PATH` | `./data/eho.db` | SQLite file |
| `EHO_UPLOAD_DIR` | `./data/uploads` | Floor-plan images (served only to authorized users) |
| `EHO_COOKIE_SECURE` | `false` | Set `true` behind HTTPS so cookies get `Secure` |
| `EHO_BASE_URL` | `http://localhost:8080` | Used to build invitation links |
| `EHO_TIMEZONE` | `Europe/Belgrade` | Time zone for entering/showing event times (stored as UTC) |
| `GOOGLE_MAPS_API_KEY` | empty | Optional Maps **Embed** API key. Without it, pages show the address only. Restrict the key by HTTP referrer. |

## Docker / Cloud Run

```bash
docker build -t eho-onboarding backend/onboarding
docker run -p 8080:8080 -v eho-data:/data eho-onboarding
docker run --rm -v eho-data:/data --entrypoint /app/eho-seed eho-onboarding -reset
```

The image is static (distroless, non-root) and reads `PORT`. Caveat for Cloud
Run: the container file system is ephemeral, so SQLite and uploads don't
survive restarts or scale-out. That's fine for a demo instance with
`max-instances=1`; for real use, add a Firestore/Cloud Storage implementation
behind the existing repository interfaces (see below). The Dockerfile has not
been built in CI yet.

## Architecture

```
cmd/eho-web     HTTP server (graceful shutdown)
cmd/seed        demo data
internal/
  app           wiring: repositories → handlers → middleware chain
  config        env vars
  db            SQLite open + embedded migrations (db/migrations/*.sql)
  httpx         principal in context, CSRF, role guards, security headers, renderer
  i18n          UI text catalog (sr); templates reference keys only
  id            random IDs and tokens
  auth          registration, login, sessions, bcrypt
  users         users, organizations, participant profile + onboarding, profile settings
  events        events, status, venue map + zones, schedule + overlap check, organizer wizard
  invitations   invitations, public /i/{token} flow, participant panel
  mail          Sender interface; LogSender logs links
  reviews       reviews + per-session ratings
  reports       report computation, FeedbackSummarizer, CSV export
templates/      html/template pages + partials
static/         app.css
```

### Data model

`users` (role: organizer / participant; `admin` reserved), `organizations`,
`participant_profiles` (caption language, goal, networking visibility opt-in,
onboarding progress), `participant_interests` (one row per topic, flag for
free-text topics), `consents` (GDPR, versioned), `auth_sessions`, `events`,
`venue_maps`, `zones` (rectangles in % of the plan), `sessions`,
`session_tags`, `invitations`, `reviews`, `session_ratings`.

Interests, session tags, goals and the visibility opt-in are stored as
separate structured rows so that AI matching (Gemma / EmbeddingGemma) can use
them later without a schema change. Only participants who opted in may ever
be matched.

### Rules worth knowing

- **Event status:** `draft` until published; then `published` (upcoming) /
  `ongoing` / `finished` are computed from the dates, never stored. Finished
  events are read-only; their page redirects to the report.
- **Invitations:** `sent` / `accepted` / `declined` are stored; `expired` is
  derived (30-day TTL or event finished). Accepting needs a participant account;
  registering from an invitation link binds and accepts it automatically. Once
  bound to an account, only that account can change the answer. Declining works
  without an account.
- **Reviews:** only participants with an accepted invitation, only after the
  event ends, one per participant per event (editable). "Anonymous" hides the
  author from the organizer in the report and the CSV.
- **Access control** is server-side: role middleware (organizer vs.
  participant routes) plus ownership checks on every event route; another
  organizer's event returns 404. Floor plans are served only to the owner and
  to participants who accepted.
- **Security:** bcrypt passwords, opaque session token in an HttpOnly
  SameSite=Lax cookie (only its SHA-256 is stored), double-submit CSRF token on
  every form plus `Sec-Fetch-Site` check, CSP without scripts, open-redirect
  protection, upload type sniffing + size limit, CSV formula-injection guard.

### Extension points

| Interface | Now | Later |
| --- | --- | --- |
| `users.Repository`, `events.Repository`, `invitations.Repository`, `reviews.Repository` | SQLite | Firestore |
| `mail.Sender` | `LogSender` (link in log + shown to the organizer) | real email provider |
| `reports.FeedbackSummarizer` | `StatSummarizer` (statistics + keyword counts, no AI) | Gemma-backed summary; its output is treated as untrusted text and only rendered escaped |
| `i18n` catalogs | `sr` | add `en` and a locale switch |

## Known limitations

- Sessions and zones can be added and deleted, not edited in place.
- No account deletion UI yet (privacy rules ask for it).
- Auth is local to this module; it is not yet reconciled with the team's
  Firebase Auth plan (`docs/decisions/team-auth.md`).
- Mail is not sent; links are logged and shown to the organizer.
