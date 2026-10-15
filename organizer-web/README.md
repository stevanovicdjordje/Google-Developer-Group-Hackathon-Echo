# organizer-web/ — Eho organizer app

> **Setup status: Not initialized yet — the module owner will initialize it.** There is no framework, `package.json` or source code here yet.

## Purpose

The organizer-facing web client: setting up an event and seeing what happens during it. All features below are **candidates**.

## Responsibilities (candidate)

- Organizer onboarding and event creation/configuration.
- **File import** for event setup: agenda, speaker list, venue map, slides, other material. Formats, validation and parsing are TBD. This is distinct from *attendee onboarding*.
- Rooms, sessions and speaker assignment.
- Generate an event join QR code / link.
- Dashboard: sessions, incoming questions, per-room content, possibly metrics/reports.
- Possibly caption/Q&A moderation.

## Data and API it relies on

- The backend API defined in [`../contracts/openapi.yaml`](../contracts/openapi.yaml) (no agreed endpoints yet).
- Fixtures from [`../contracts/examples/`](../contracts/examples/) while the backend isn't ready.

## AI integrations

Through the backend only. The organizer web app should not call Gemma or other providers directly, and should never hold provider keys.

## Open questions

- Framework (TBD) and hosting (Firebase Hosting is a candidate).
- Which import formats are supported for the demo (CSV? PDF? spreadsheet? manual entry as a fallback?).
- What does the organizer actually need to see live, versus after the event?
- Organizer authentication and multi-organizer events.

## Setup

`Not initialized yet — module owner will initialize.` When initialized, document the IDE, the install/run commands, how to point at fixtures vs. the backend, and the `.env.example` variables.
