# backend/onboarding — Eho onboarding module

Server-rendered Go web app for the part of Eho around an event: organizer and
participant registration, participant onboarding, the organizer's event list
and wizard, invitations, the participant panel, reviews and the post-event
report ("ukupan utisak").

It runs on the **same Firebase project as the rest of Eho** (Firebase Auth,
Firestore, Storage; locally the emulators from `backend/maps`):

- **Same accounts** as the Flutter app and the other services. Organizers and
  participants sign in with email/password; the role is a custom claim
  (`role: organizer | participant`). Accounts without the claim follow the
  team rule (`team-auth`): anonymous = attendee, email/password = organizer.
- **Same events.** An event here is the shared `events/{eventId}` document
  (`backend/maps`, `backend/events`): events created in the map editor show up
  in the organizer's list, and events created here can be opened in the map
  editor (a `draft/map` is created with them).
- **Same agenda.** The schedule step edits `events/{id}/published/agenda` in
  the `backend/events` format, so sessions appear in the app, Echo and Q&A.
- **Same venue map.** The map is made in the Flutter map editor; this module
  draws the published map (floors from Storage, rooms, stands, POIs) as SVG and
  offers its rooms as halls for sessions.

It is a separate Go module (own `go.mod`, `cmd/`, `internal/`) and doesn't
import the other services. UI: `net/http` + `html/template`, one CSS file,
**no JavaScript** (CSP `script-src 'none'`); texts in Serbian (Latin),
in `internal/i18n/sr.go`.

## Run locally

Requirements: Go 1.26+, Java 21 and the Firebase CLI (the emulators), as for
`backend/maps`. On macOS: `brew install firebase-cli openjdk@21` (the script
finds Homebrew's Java even if it isn't on `PATH`).

```bash
cd backend/onboarding
make dev     # emulators + map API (:8080) if not running, then this app on :8090
make seed    # in a second terminal: map + agenda (devfest) and onboarding demo data
```

Open **http://localhost:8090**. Emulator UI: http://localhost:4000.
Emulator data persists in `backend/maps/firebase/.emulator-data/`.

| Who | Login | Password |
| --- | --- | --- |
| Organizer (same as the map editor demo) | `organizer@eho.test` | `eho-demo-123` |
| Participants | `ucesnik01@eho.test` … `ucesnik20@eho.test` | `eho-demo-123` |

Demo events: "DevFest Belgrade 2026" (`devfest`, today, with the map and agenda
from `backend/maps` / `backend/events`; 14 participants invited), "Eho Dev
Summit 2026" (finished 10 days ago, 13 reviews: open its report) and "Startap
vikend Novi Sad" (in 14 days). `make seed` can be re-run; it replaces its own data.

To see the attendee side in the Flutter app as well: `mobile/scripts/dev_all.sh`
(needs Flutter). Event links in this app point to `EHO_APP_URL`.

### Tests

```bash
make test            # unit + HTTP tests, in memory (no emulators needed)
make test-emulator   # the main HTTP flow against the running emulators
make vet
```

Unit tests: event status, overlap detection and the schedule grid, agenda
conversion, the SVG map view, invitation status and response rules, review
rules, report computation, the statistical summarizer, CSV export (formula
injection), validation, i18n key coverage. HTTP tests run the full flow with
in-memory implementations of the same interfaces (registration, roles,
ownership isolation, CSRF, onboarding, wizard, invitations, register-from-
invite, publishing, review, report, CSV). `TestAgainstEmulators` repeats the
main flow against real Firebase emulators and also reads the `devfest` event,
its map and floor image.

## Configuration

See `.env.example`. Nothing secret is committed.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8090` | HTTP port (`backend/maps` uses 8080) |
| `EHO_BASE_URL` | `http://localhost:8090` | Builds invitation links |
| `EHO_APP_URL` | `http://localhost:5000` | Flutter app: map editor (`/organizer`) and event links (`/e/{id}`) |
| `EHO_COOKIE_SECURE` | `false` | `true` behind HTTPS |
| `EHO_TIMEZONE` | `Europe/Belgrade` | Entering/showing times; agenda days and clock times are local |
| `FIREBASE_PROJECT_ID` | `demo-eho` | Shared Firebase project |
| `FIREBASE_API_KEY` | (any value with the emulator) | Web API key, for the email/password check |
| `STORAGE_BUCKET` | `<project>.appspot.com` | Floor-plan images (same default as `backend/maps`) |
| `FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`, `STORAGE_EMULATOR_HOST` | set by `scripts/dev.sh` | Emulators |
| `GOOGLE_MAPS_API_KEY` | empty | Optional Maps Embed key; without it only the address is shown |

## Deploy (Cloud Run)

`Dockerfile` builds a static distroless image. On Cloud Run set
`FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `EHO_BASE_URL`, `EHO_APP_URL` and
`EHO_COOKIE_SECURE=true`; credentials come from the service account (needs
Firebase Auth admin, Firestore and Storage read access). Not deployed yet; the
image has not been built in CI.

## Architecture

```
cmd/eho-web     HTTP server
cmd/seed        demo data (emulators only)
scripts/        dev.sh (emulators + app), seed.sh (all seeds)
internal/
  app           wiring: Deps (Firebase or in-memory) → handlers → middleware
  fb            Firebase clients (Auth, Firestore, Storage)
  config        env vars
  httpx         principal, CSRF, role guards, security headers, renderer
  i18n          UI text catalog (sr)
  auth          Identity (Firebase / in-memory), registration, login, session cookies
  users         organizer organizations, participant profile + onboarding
  events        shared events, agenda, published map view, wizard
  invitations   invitations, public /i/{token} flow, participant panel
  mail          Sender interface; LogSender logs the links
  reviews       reviews + per-session ratings
  reports       report, FeedbackSummarizer, CSV export
templates/, static/
```

### Firestore data

| Path | Written by | Contents |
| --- | --- | --- |
| `events/{eventId}` | shared | `name, startDate, endDate, address, ownerUid, publishedVersion, createdAt, updatedAt`; this module adds `description, startsAt, endsAt, lat, lng, listedAt` (field-level updates, so nobody overwrites the others' fields) |
| `events/{id}/published/agenda` | shared with `backend/events` | stages, speakers, sessions (`day`, `start`, `end`, `stage`, …) |
| `events/{id}/published/map/*` | `backend/maps` (read here) | floors, features |
| `events/{id}/reviews/{uid}` | this module | rating, comment, anonymous, sessionRatings, author |
| `invitations/{eventId}_{hash(email)}` | this module | eventId, email, token, status, userId, expiresAt, … |
| `members/{uid}/events/{eventId}` | shared with `backend/events` | added when an invitation is accepted ("My events" in the app) |
| `organizers/{uid}`, `participants/{uid}` | this module | organization; onboarding profile, interests, goal, visibility opt-in, consents |

All writes use the Admin SDK. The project rules (`backend/maps/firebase`)
deny clients everything not listed there, so reviews, invitations and profiles
are not readable from the app.

### Rules worth knowing

- **Event status:** draft until published here (`listedAt`) or until its map
  is published in the editor (`publishedVersion > 0`); then upcoming / ongoing /
  finished from the times. Events created in the app only have dates and span
  whole days. Finished events are read-only (the page opens the report).
- **Invitations:** `sent / accepted / declined` stored, `expired` derived (30
  days or event over). Registering from an invitation link accepts it. Once
  bound to an account only that account can change the answer; declining works
  without an account.
- **Reviews:** accepted invitation + event finished; one per participant
  (editable); anonymous hides the author in the report and CSV.
- **Access control** is server-side: role middleware and `ownerUid` checks;
  another organizer's event is a 404. Floor images are proxied only to the owner
  and to participants who accepted.
- **Security:** Firebase session cookie (HttpOnly, SameSite=Lax), CSRF token on
  every form + `Sec-Fetch-Site` check, CSP without scripts, open-redirect
  protection, CSV formula-injection guard.

### Extension points

| Interface | Now | Later |
| --- | --- | --- |
| `auth.Identity` | Firebase Auth | — |
| `*.Repository` | Firestore (+ in-memory for tests) | — |
| `mail.Sender` | `LogSender` (link in log + shown to the organizer) | real email |
| `reports.FeedbackSummarizer` | `StatSummarizer` (statistics, no AI) | Gemma; output treated as untrusted text, only rendered escaped |
| `i18n` catalogs | `sr` | `en` + locale switch |

## Known limitations

- Sessions can be added and deleted here, not edited in place (or edit them via
  the import flow in `backend/events`).
- The map can't be edited here (by design: one map editor).
- `backend/maps` treats every non-anonymous account as an organizer; until it
  also checks the `role` claim, a participant account could create events in the
  map editor.
- No account deletion UI yet. Mail is not sent.
