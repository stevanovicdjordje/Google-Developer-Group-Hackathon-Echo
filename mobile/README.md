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

Requirements: Flutter stable (3.47+), Chrome; for the backend + emulators see `../backend/README.md`.

```bash
mobile/scripts/dev_all.sh          # emulators + Go API + Flutter web in Chrome (http://localhost:5000)

cd mobile/app
flutter test
flutter analyze
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080   # app only
```

Build-time settings (`--dart-define`): `API_BASE_URL` (default `http://localhost:8080`), `USE_EMULATORS` (default `true`; a real Firebase project is not configured yet), `EMULATOR_HOST` (default `localhost`; use `10.0.2.2` on the Android emulator).

Layout: `lib/core/` (router, theme, Firebase init, API client, config), `lib/features/<feature>/` (`auth`, `dev`, later `map_viewer`, `map_editor`, `location`, `stats`), `lib/l10n/` (Serbian Latin `app_sr.arb` is the template, English `app_en.arb`).
