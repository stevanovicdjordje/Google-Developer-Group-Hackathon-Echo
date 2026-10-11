# mobile/ — Eho attendee app

> **Stack:** Flutter (web + Android + iOS) in `app/`. It also contains the organizer role (venue-map editor, stats); see `docs/decisions/mobile-stack.md` and `organizer-web-framework.md`.

## Purpose

The attendee-facing client. It lets a visitor join an event and use Eho's attendee features. All features below are **candidates**, not commitments. See `docs/MVP.md` for what is proposed for the demo.

## Responsibilities (candidate)

- Join an event via QR code or link.
- Attendee onboarding: interests, language, reason for attending, optional opt-in networking profile.
- Agenda: sessions, times, rooms, speakers, session details.
- Venue map: floor plan with rooms/stands/POIs, search, routing from the backend, GPS dot with accuracy and QR/manual "you are here" fallback (in progress).
- Transcript / captions view for a session.
- Q&A: ask questions, "ask the talk" over a transcript.
- Networking: natural-language people search, opt-in only.

## Data and API it relies on

- The backend API, as defined in [`../contracts/openapi.yaml`](../contracts/openapi.yaml). That spec currently has **no agreed endpoints**.
- Until the backend is ready, use fixtures from [`../contracts/examples/`](../contracts/examples/) or local mocks.

## AI integrations

**Planned to go through the backend only.** The app should not call Gemma, STT or other model providers directly, and should not ship provider API keys, unless the team explicitly agrees otherwise (e.g. an on-device Gemma experiment). Record that decision in `docs/decisions/`.

## Open questions

- Stack: Kotlin / Compose Multiplatform (natural candidate), Android-only, Flutter, or web/PWA? The mobile owner decides.
- Android-first, or also iOS / web for the demo?
- How does a user authenticate? Anonymous join via event code, or an account?
- Is offline agenda access needed at the venue?
- How are captions delivered (polling, SSE, WebSocket)? This depends on the backend and STT decisions.
- If Firebase is chosen, should `google-services.json` stay out of git (the root `.gitignore` currently ignores it), and how is it shared?

## Setup

Requirements: Flutter stable (3.47+), Chrome; for the backend + emulators see `../backend/maps/README.md`.

```bash
mobile/scripts/dev_all.sh          # emulators + Go API + Flutter web in Chrome (http://localhost:5050)

cd mobile/app
flutter test
flutter analyze
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080   # app only
```

Build-time settings (`--dart-define`): `DEMO_EVENT_ID` (event ID used by the demo, default `devfest`; set it to the ID printed by `backend/maps` `make seed` so the Map tab shows the real venue), `API_BASE_URL` (default `http://localhost:8080`), `USE_EMULATORS` (default `true`: emulators and the `demo-eho` project), `EMULATOR_HOST` (default `localhost`; use `10.0.2.2` on the Android emulator), `DEMO_LOCATION` (pretend GPS, `<lat>,<lng>` or several separated by `;` to walk; values from `make seed` in `backend/maps`).

Real Firebase project (deploy): with `USE_EMULATORS=false` the app reads the project's web config from `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID` (required) and `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET` (optional) and connects to no emulator. These are public client config, but never commit real values. If a required one is missing, Firebase init fails with a message naming it and the app continues without Firebase.

```bash
cd mobile/app
flutter build web --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://<api-host> \
  --dart-define=FIREBASE_API_KEY=<web-api-key> \
  --dart-define=FIREBASE_APP_ID=<1:123:web:abc> \
  --dart-define=FIREBASE_PROJECT_ID=<project-id> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> \
  --dart-define=FIREBASE_AUTH_DOMAIN=<project-id>.firebaseapp.com \
  --dart-define=FIREBASE_STORAGE_BUCKET=<project-id>.firebasestorage.app
```

Layout: `lib/core/` (router, theme, Firebase init, API client, config), `lib/features/<feature>/` (`auth`, `dev`; the venue map in `maps/`), `lib/l10n/` (Serbian Latin `app_sr.arb` is the template, English `app_en.arb`).
