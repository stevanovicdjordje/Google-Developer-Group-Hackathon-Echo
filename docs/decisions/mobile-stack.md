# Mobile stack

- **ID:** `mobile-stack`
- **Status:** accepted
- **Writer:** Mobile owner · @Vertiglo
- **Affects:** mobile (others only via how to run the demo build)
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

The attendee client needs a stack. The mobile owner decides.

## Options

- Kotlin / Compose Multiplatform
- Android-only (Kotlin/Compose)
- Flutter
- Web / PWA

## Decision

**Flutter** (stable), one codebase built for **web + Android + iOS**. The demo runs as Flutter web in the phone browser (link/QR, no install); the same code builds as a native app.
State: Riverpod. Routing: go_router (deep links `/e/{eventId}`, `/e/{eventId}/stand/{standId}`). Venue map: `flutter_map` with `CrsSimple` (floor plan image in pixel coordinates, no tile server). GPS: `geolocator`. Firebase: Auth, Firestore (read-only), Storage.
The same app also contains the **organizer role** (map editor, stats), shown after organizer login. See `organizer-web-framework.md`.
Decided by the mobile owner (@Vertiglo) on 2026-10-10.

## Consequences / follow-ups

- Project lives in `mobile/app/`. Feature folders under `lib/features/` so other features (captions, Q&A, networking) can be added next to `map_viewer/`, `map_editor/`, `location/`, `stats/`, `auth/`.
- How to build/run is recorded in `mobile/STATUS.md`.
