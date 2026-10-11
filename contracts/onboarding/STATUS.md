# feature:onboarding — STATUS

> **Single writer:** the `feature:onboarding` holder and their agent. Everyone else reads.
> Protocol: [`../../docs/COORDINATION.md`](../../docs/COORDINATION.md) (§1a feature scopes). Newest entries at the top of each log.

**Last updated:** 2026-10-11 10:30 · **Owner:** @stevanovicdjordje · **Scopes held:** feature:onboarding

## Current state

Organizer web portal for **reviews and the post-event report** ("Overall impression"), plus registration, attendee onboarding, an event wizard and invitations. Server-rendered Go (`net/http` + `html/template`, no JavaScript), in `backend/onboarding/` (its own Go module). The report is in the demo video (`team-post-event-report`); the other pages are not part of the demo.

It runs on the **shared Firebase project** (Auth, Firestore, Storage; locally the `backend/maps` emulators):
- **Accounts:** Firebase Auth email/password (session cookie), role as custom claim `role: organizer | participant`; accounts without the claim follow `team-auth`.
- **Events:** the shared `events/{eventId}` docs (field-level updates; adds `description, startsAt, endsAt, lat, lng, listedAt`; creates `draft/map` for new events). Events from the map editor show up here.
- **Schedule:** `events/{id}/published/agenda` in the `feature:events` format.
- **Venue map:** read-only, drawn from the published map (`feature:maps`); edited only in the map editor.
- **Own data:** `invitations/*`, `organizers/{uid}`, `participants/{uid}`, `events/{id}/reviews/{uid}`; accepting an invitation writes `members/{uid}/events/{eventId}`. All Admin SDK; the project rules deny clients.
- **UI language:** English by default (`product-ui-language`, `EHO_LANG=en`), Serbian available (`EHO_LANG=sr`). Look follows `mobile/docs/design/` tokens.
- **Summary is statistical, not AI** (`StatSummarizer`: rating thresholds + word counts), and the page says so. A model can replace it behind `FeedbackSummarizer` later, labeled as such.

## How to consume / run (interface for teammates)

| Item | Value |
| --- | --- |
| Run locally | `cd backend/onboarding && make dev` (starts the `backend/maps` emulators + map API on :8080 if they aren't running, then this app on **http://localhost:8085**); `make seed` in a second terminal (runs the maps and events seeds, then this one) |
| Demo login | `organizer@eho.test` / `eho-demo-123` (the same demo organizer as the map editor) |
| **Report for the video** | Sign in → My events → *Past* → **DevFest Belgrade 2026** → *Report* = `http://localhost:8085/org/events/devfest-report/report` (print view: `?print=1`, CSV: `/report.csv`) |
| Demo data | `devfest-report`: finished copy of DevFest (yesterday), sessions = `backend/events/cmd/seed/agenda.json`, 20 invited / 17 accepted, 15 fake reviews with per-session ratings. Also: 20 attendees `ucesnik01..20@eho.test`, invitations to the live `devfest`, two more sample events |
| Port | 8085 (`PORT`) |
| Env | `backend/onboarding/.env.example` (`FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY` outside the emulator, `EHO_APP_URL`, `EHO_LANG`, …) |
| Tests | `make test` (in-memory), `make test-emulator` (main flow against the running emulators) |
| Docs | [`backend/onboarding/README.md`](../../backend/onboarding/README.md) |
| Contract | No HTTP API for other modules (HTML only); data sharing is the Firestore layout above |

## Announcements (newest first)

<!-- - YYYY-MM-DD HH:MM · BREAKING|ACTION|INFO · for: <modules> · <what changed> · <link> -->
- 2026-10-11 10:30 · ACTION · for: mobile, integration · `mobile#21` done: registered, port 8085, `devfest-report` seed (DevFest agenda + fake reviews), English report pages with the design tokens, summary labeled "not AI". Report URL in *How to consume*.
- 2026-10-11 10:30 · INFO · for: feature:maps, feature:events · Onboarding writes into shared Firestore paths (see *Current state*): extra fields on `events/{id}` (field-level), `published/agenda` (your format), `draft/map` on create, `members/{uid}/events/{id}` on accept. Nothing of yours is overwritten.

## Outbound requests (we need something from others)

| ID | To | What / why | Status | Updated |
| --- | --- | --- | --- | --- |
| onboarding#1 | feature:maps | Organizer check: please also accept/deny on the `role` custom claim (`organizer` / `participant`). Today every non-anonymous account counts as an organizer, so an attendee who signed up on the web portal (email/password, `role: participant`) could create events in the map editor. Accounts without the claim can keep today's rule. | open | 2026-10-11 |

## Inbound requests (others need something from us)

| ID | From | Response / resolution | Status | Updated |
| --- | --- | --- | --- | --- |
| mobile#21 | mobile (integration) | (a) registered here; (b) port **8085**; (c) `cmd/seed` adds **`devfest-report`**, a finished "DevFest Belgrade 2026" whose sessions are read from `backend/events/cmd/seed/agenda.json` (same IDs, titles, rooms, speakers), 15 fake reviews + per-session ratings; (d) English UI (`EHO_LANG=en` default; all pages, not only the report); (e) summary labeled "Statistical summary … (not AI)". Also: the module now reads events, agenda and map live from Firestore, so the "own SQLite / can't show devfest" gaps in `team-post-event-report` no longer apply. | done | 2026-10-11 |

## Acks (our responses to other modules' breaking proposals)

| Proposal | Response | Updated |
| --- | --- | --- |
