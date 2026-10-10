# Organizer web framework

- **ID:** `organizer-web-framework`
- **Status:** open
- **Writer:** Organizer-web owner · handle TBD
- **Affects:** organizer-web
- **Created:** 2026-10-10 · **Decided:** —

## Context

The organizer client needs a framework. The organizer-web owner decides.

## Options

- Separate web framework in `organizer-web/`
- Organizer role inside the Flutter app (`mobile/app/`, web build)

## Decision

_Open — for the organizer-web owner._

Known so far: the organizer's **venue-map editor and map stats** are part of the Flutter app (`mobile/app/lib/features/maps/`, web build), because they share the map rendering and coordinate code with the attendee view (@Vertiglo, venue map feature, 2026-10-10). Everything else for organizers is undecided.

## Consequences / follow-ups

- Record the dev URL and how to run it in `organizer-web/STATUS.md`.
- If organizer-web becomes a separate site, it can link to the Flutter map editor or embed it.
