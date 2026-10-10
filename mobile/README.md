# mobile/ — Eho attendee app

> **Setup status: Not initialized yet — the module owner will initialize it.** There is no project, build file or source code here yet.

## Purpose

The attendee-facing client. It lets a visitor join an event and use Eho's attendee features. All features below are **candidates**, not commitments. See `docs/MVP.md` for what is proposed for the demo.

## Responsibilities (candidate)

- Join an event via QR code or link.
- Attendee onboarding: interests, language, reason for attending, optional opt-in networking profile.
- Agenda: sessions, times, rooms, speakers, session details.
- Venue map (MVP candidate: static SVG/image with clickable rooms; **no** real-time indoor positioning).
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

`Not initialized yet — module owner will initialize.` When initialized, document here:

- the IDE to use (e.g. Android Studio) and the minimum SDK/toolchain,
- how to run against fixtures vs. a local/remote backend,
- how to configure the backend base URL (no secrets in git; use `.env.example` / `local.properties` templates).
