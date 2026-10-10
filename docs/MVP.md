# Eho — MVP (proposal, not a decision)

> **Status: Proposal.** The team has **not** agreed on the MVP. This document lists candidates, one *proposed* demo slice, and the criteria for choosing. Update it when the team decides, and record the decision in `DECISIONS.md`.

## Selection criteria

Score each candidate feature on:

1. **True Gemma value:** does Gemma do something meaningful that a static app couldn't?
2. **Risk:** technical uncertainty (STT latency, hosting, data quality).
3. **Integration cost:** how many modules and contract changes it needs.
4. **Demonstrability:** can we show it *working live* (not a mockup) in the pitch?
5. **Time:** does it fit in ~24h alongside everything else?

Also check against the judging criteria in `PRODUCT.md`: working demo, one solved technical problem, research-driven changes.

## Unscoped candidate features

All Proposed / Unvalidated:

- Join event via QR / link
- Organizer onboarding + file import (agenda, speakers, map, slides)
- Attendee onboarding (interests, language, goal)
- Agenda with session details
- Interactive venue map (static SVG/image)
- Live transcription / captions (+ translation)
- Live Q&A with semantic question clustering
- "Ask the talk" (answers grounded in the transcript/slides)
- Natural-language networking search (opt-in)
- Organizer dashboard / insights

## Proposed demo slice

**For discussion. Not agreed.**

- **One conference** as the demo dataset (fake or properly permissioned data).
- **Organizer** uploads basic content (e.g. agenda + speakers) and gets a join link/QR.
- **Attendee** joins and sees the agenda.
- **One Gemma-powered use case**, end-to-end. Pick one, for example:
  - *"Ask the talk"*: questions answered from a session's transcript/slides, **or**
  - *smart Q&A*: clustering/summarizing audience questions for the speaker/organizer.
- **Minimal organizer view** showing the result of that use case.

Kept as **candidates that depend on prioritization**: venue map, networking, live captions/translation, attendee onboarding beyond the basics, rich dashboard.

## Not in initial scaffold

The bootstrap commit intentionally contains none of the following:

- Any application code, framework scaffold, `package.json`, Gradle project or web app.
- STT pipeline, Gemma integration, embeddings, onboarding, map, networking matchmaking or organizer UI.
- Agreed API endpoints (the OpenAPI spec is empty).
- Cloud projects, billing, deployments or secrets.

## Decision log for MVP

| Date | Decision | Status |
| --- | --- | --- |
| — | Hero flow / demo slice | Open |
| — | Which Gemma use case | Open |
| — | Live captions in or out | Open |
