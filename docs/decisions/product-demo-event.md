# Demo event name

- **ID:** `product-demo-event`
- **Status:** accepted
- **Writer:** Product holder · @Ilij4n
- **Affects:** mobile, feature:maps, feature:echo
- **Created:** 2026-10-11 · **Decided:** 2026-10-11

## Context

The app's demo data said "DevSummit Belgrade 2026" while the venue-map and Echo seeds say "Eho Demo Expo". Both show up in the demo video, so they must match.

## Options

- "DevSummit Belgrade 2026"
- "Eho Demo Expo"
- "DevFest Belgrade 2026"

## Decision

**"DevFest Belgrade 2026"** everywhere the demo event appears (short form "DevFest"). Dates and venue stay as in the app's demo data (Oct 11–12, 2026 · Sava Centar, Belgrade). The event is fictional demo data.

## Consequences / follow-ups

- mobile: rename in `mobile/app/lib/data/demo_data.dart` and tests (board task M-17). The design in `mobile/docs/design/` is already updated.
- feature:maps: `backend/maps/cmd/seed` `demoEventName` → "DevFest Belgrade 2026" (+ its tests).
- feature:echo: `backend/echo/cmd/replay` `demoEventName` → same.
