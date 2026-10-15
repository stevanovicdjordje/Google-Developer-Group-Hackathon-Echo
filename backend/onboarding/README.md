# backend/onboarding — Echo onboarding module

Server-rendered Go web app for the part of Echo around an event: organizer and
participant registration, participant onboarding, the organizer's event list
and wizard, invitations, the participant panel, reviews and the post-event
report ("ukupan utisak").

It runs on the **same Firebase project as the rest of Echo** (Firebase Auth,
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
import the other services. Registered as `feature:onboarding`
([`contracts/onboarding/STATUS.md`](../../contracts/onboarding/STATUS.md)).
UI: `net/http` + `html/template`, one CSS file following the app design tokens
(`mobile/docs/design/`), **no JavaScript** (CSP `script-src 'none'`). UI texts
are in `internal/i18n/` — English by default (`EHO_LANG=en`), Serbian with
`EHO_LANG=sr`.

## Run locally

Requirements: Go 1.26+, Java 21 and the Firebase CLI (the emulators), as for
`backend/maps`. On macOS: `brew install firebase-cli openjdk@21` (the script
finds Homebrew's Java even if it isn't on `PATH`).

```bash
cd backend/onboarding
make dev     # emulators + map API (:8080) if not running, then this app on :8085
make seed    # in a second terminal: map + agenda (devfest) and onboarding demo data
```

Open **http://localhost:8085**. Emulator UI: http://localhost:4000.
Emulator data persists in `backend/maps/firebase/.emulator-data/`.

| Who | Login | Password |
| --- | --- | --- |
| Organizer (same as the map editor demo) | `organizer@eho.test` | `eho-demo-123` |
| Participants | `ucesnik01@eho.test` … `ucesnik20@eho.test` | `eho-demo-123` |

Demo events:
- **"DevFest Belgrade 2026" (`devfest-report`, finished yesterday)**: the report
  for the demo video, `http://localhost:8085/org/events/devfest-report/report`.
  Its sessions are read from `backend/events/cmd/seed/agenda.json`; 20 invited,
  17 accepted, 15 fake reviews with per-session ratings.
- "DevFest Belgrade 2026" (`devfest`, today, live): the map and agenda from
  `backend/maps` / `backend/events`; 14 participants invited.
- "Echo Dev Summit 2026" (finished 10 days ago, Serbian reviews) and "Startap
  vikend Novi Sad" (in 14 days).

`make seed` can be re-run; it replaces its own data.

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
rules, report computation, the statistical summarizer, the PDF export, validation, i18n key coverage. HTTP tests run the full flow with
in-memory implementations of the same interfaces (registration, roles,
ownership isolation, CSRF, onboarding, wizard, invitations, register-from-
invite, publishing, review, report, PDF download). `TestAgainstEmulators` repeats the
main flow against real Firebase emulators and also reads the `devfest` event,
its map and floor image.

## Configuration

See `.env.example`. Nothing secret is committed.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8085` | HTTP port (`backend/maps` uses 8080) |
| `EHO_BASE_URL` | `http://localhost:8085` | Builds invitation links |
| `EHO_APP_URL` | `http://localhost:5050` | Flutter app: map editor (`/organizer`) and event links (`/e/{id}`) |
| `EHO_COOKIE_SECURE` | `false` | `true` behind HTTPS |
| `EHO_TIMEZONE` | `Europe/Belgrade` | Entering/showing times; agenda days and clock times are local |
| `EHO_LANG` | `en` | UI language: `en` or `sr` |
| `FIREBASE_PROJECT_ID` | `demo-eho` | Shared Firebase project |
| `FIREBASE_API_KEY` | (any value with the emulator) | Web API key, for the email/password check |
| `STORAGE_BUCKET` | `<project>.appspot.com` | Floor-plan images (same default as `backend/maps`) |
| `FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`, `STORAGE_EMULATOR_HOST` | set by `scripts/dev.sh` | Emulators |
| `EHO_ECHO_URL` | `http://localhost:8082` | Echo service, for the AI summary and questions in talk reports |
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
  reports       event report + talk report, FeedbackSummarizer, PDF export (fpdf + DejaVu font)
  talks         talk-report catalog, test checkout (PaymentProvider), purchases, Echo client
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

### Paid talk reports (`/talks`)

Anyone signed in can buy the report of any talk that has ended: a PDF with
Echo's AI summary (takeaway, key points, problems → fixes), the audience
rating of that talk and the top five audience questions. €2.99 per talk;
organizers get their own talks free. Checkout is **test mode** (`TestProvider`):
use `4242 4242 4242 4242` (any future date, any CVC); `4000 0000 0000 0002` is
declined; real card numbers are refused. Only the card brand and last four
digits are stored (`purchases/*`). The portal calls Echo (`EHO_ECHO_URL`,
default `http://localhost:8082`) as a service user. Details:
`docs/decisions/feature-onboarding-talk-reports.md`.

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
  (editable); anonymous hides the author in the report and the PDF.
- **Access control** is server-side: role middleware and `ownerUid` checks;
  another organizer's event is a 404. Floor images are proxied only to the owner
  and to participants who accepted.
- **Security:** Firebase session cookie (HttpOnly, SameSite=Lax), CSRF token on
  every form + `Sec-Fetch-Site` check, CSP without scripts (styles/fonts only
  from self and Google Fonts), open-redirect protection.

### Extension points

| Interface | Now | Later |
| --- | --- | --- |
| `auth.Identity` | Firebase Auth | — |
| `*.Repository` | Firestore (+ in-memory for tests) | — |
| `talks.PaymentProvider` | `TestProvider` (Stripe test cards, no money) | Stripe Checkout |
| `mail.Sender` | `LogSender` (link in log + shown to the organizer) | real email |
| `reports.FeedbackSummarizer` | `StatSummarizer` (statistics, no AI; the page says so) | Gemma; output treated as untrusted text, only rendered escaped, labeled as AI |
| `i18n` catalogs | `en`, `sr` (same keys, tested) | more languages |

## Known limitations

- Sessions can be added and deleted here, not edited in place (or edit them via
  the import flow in `backend/events`).
- The map can't be edited here (by design: one map editor).
- `backend/maps` treats every non-anonymous account as an organizer; until it
  also checks the `role` claim, a participant account could create events in the
  map editor.
- No account deletion UI yet. Mail is not sent.
