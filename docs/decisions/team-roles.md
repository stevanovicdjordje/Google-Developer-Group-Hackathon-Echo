# Two primary roles: attendee and organizer

- **ID:** `team-roles`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-11

## Context

The challenge mentions attendees, speakers and organizers.

## Options

- Two app roles (attendee, organizer); speakers are a stakeholder, not a role yet.
- A dedicated speaker role/app.

## Decision

Two app roles: attendee and organizer (same Flutter app; organizer screens under `/organizer`, map editor `/o`). Speakers are not a role yet.

## Consequences / follow-ups

- Speaker-facing features, if any, go through the organizer view or a later role.
