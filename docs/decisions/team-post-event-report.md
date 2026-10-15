# Post-event report comes from backend/onboarding

- **ID:** `team-post-event-report`
- **Status:** accepted
- **Writer:** Integration holder · @Ilij4n
- **Affects:** backend/onboarding (@stevanovicdjordje), feature:events, product, the demo video
- **Created:** 2026-10-11 · **Decided:** 2026-10-11 (by @Ilij4n)

## Context

@stevanovicdjordje pushed `backend/onboarding` (2026-10-11 08:44): a separate, server-rendered Go web app with its own SQLite DB and cookie auth. It covers registration, onboarding, an event wizard, invitations, reviews and a **post-event report**. Most of it overlaps work that is already built (`feature:events`, `feature:maps`, the Flutter app, `team-auth`). Reviews and the report are new: nothing else in Eho does them.

An evaluation on 2026-10-11 (`go vet` clean, `go test` green, seeded demo run) found the report demo-ready:
- overall score with liked / disliked / recommendations,
- invite funnel (invited, accepted, declined, response rate),
- star distribution, ratings per session, comments,
- print view and CSV export.

Gaps:
- It reads only its own SQLite events, never the Events service, so it can't show `devfest` today.
- The UI is Serbian only.
- The summary is **statistical** (`StatSummarizer`: thresholds and keyword counts), not a model.

## Decision

1. **We use `backend/onboarding` for the post-event statistics of our event** in the demo. It's an organizer web page shown after the app part of the video.
2. **Cheapest path for the demo:** its seed creates a **finished "DevFest Belgrade 2026"** event whose sessions match the `devfest` agenda (`backend/events/cmd/seed/agenda.json`: titles, rooms, speakers), with fake reviews and per-session ratings. No live link to the Events API is needed for the video.
3. **Truthful labels:** the report summary is not AI. It must not be presented as Gemma/Gemini output in the app, the video or the docs. Plugging a model in behind `FeedbackSummarizer` later is fine, if it's labeled then.
4. Its other features (registration, wizard, floor plan, invitations) are **not part of the demo**. They stay in the module.

## Consequences / follow-ups

- @stevanovicdjordje (`mobile#21`):
  - register a scope,
  - move off port 8080 (use 8085),
  - add the `devfest` seed,
  - show the report in English (`product-ui-language`); at least the organizer report pages.
- Product: `docs/MVP.md` gets a "Post-event report" row.
- Reading events live from `feature:events` (an API adapter plus review storage) is a post-hackathon option. It isn't required.
