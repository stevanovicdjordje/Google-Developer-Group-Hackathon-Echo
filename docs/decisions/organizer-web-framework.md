# Organizer web framework

- **ID:** `organizer-web-framework`
- **Status:** accepted
- **Writer:** Organizer-web owner · @Vertiglo
- **Affects:** organizer-web
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

The organizer client needs a framework. The organizer-web owner decides.

## Options

- Separate web framework in `organizer-web/`
- Organizer role inside the Flutter app (`mobile/app/`, web build)

## Decision

The organizer UI is **not a separate project**. It is the organizer role inside the Flutter app in `mobile/app/` (built for web), sharing the map rendering and coordinate code with the attendee view. `organizer-web/` holds no code for now.
Decided by the organizer-web owner (@Vertiglo) on 2026-10-10.

## Consequences / follow-ups

- Organizer dev URL = the Flutter web build of `mobile/app/`; see `mobile/STATUS.md`.
- If a separate organizer site is needed later, it goes here and consumes the same contract.
