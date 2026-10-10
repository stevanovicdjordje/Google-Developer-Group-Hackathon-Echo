# Hero flow / demo slice

- **ID:** `product-hero-flow`
- **Status:** accepted
- **Writer:** Product holder (fallback: repo owner's agent) · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

We can demo one end-to-end Gemma-powered flow well, not eight. See `docs/MVP.md` for the candidates and selection criteria.

## Options

- "Ask the talk": answers grounded in a session transcript/slides.
- Smart Q&A: clustering/summarizing audience questions.
- Other (from research).

## Decision

The demo is a **video of the happy path** across the whole app, not one flow. Feature set: `docs/PRODUCT.md` → *The app*. Video storyline and per-feature status (build / faked input / mock): `docs/MVP.md`.

Gemma (via the Gemini API) is used for real in five places: organizer file extraction, Echo translation, Ask the talk, talk summaries, and Find (recommendations + prompt search).

Agreed by the team (relayed by @Ilij4n), 2026-10-10. This also resolves request `mobile#1` (venue map is part of the demo).

## Consequences / follow-ups

- Drives the first contract operations, `docs/TASKS.md` and every module's first milestone.
- Each module builds what `docs/MVP.md` marks **Build**. Mocked parts stay mocked.
