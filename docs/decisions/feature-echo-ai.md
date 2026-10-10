# Echo: AI model and how it is called

- **ID:** `feature-echo-ai`
- **Status:** accepted
- **Writer:** `feature:echo` holder · @MilosBG03
- **Affects:** feature:echo (backend/echo); clients only through latency and the `model` field
- **Created:** 2026-10-11 · **Decided:** 2026-10-11

## Context

Echo has four AI moments in the demo video: Ask the talk, Catch up, Summary and Translation (`docs/MVP.md`).
`docs/MVP.md` already fixes **Gemma via the Gemini API for translation** and allows a model per feature behind a
backend adapter. `backend-gemma-hosting` (open, backend prefix) is about the backend as a whole; this decision only
covers Echo.

## Options

- Gemma via the Gemini API for all four
- Gemma for translation, another Gemini model for Ask/Summary
- Self-hosted Gemma (GPU), local model

## Decision

**Gemma via the Gemini API for all four Echo features**, default model `gemma-4-26b-a4b-it` with thinking off
(`GEMMA_MODEL`, `GEMMA_THINKING=minimal`, so another Gemma can be swapped in without code changes). One adapter (`backend/echo/internal/assist`, `Model` interface)
so the model or provider can change later. It makes Echo the clearest "meaningful use of Gemma" in the demo, needs no
hosting, and the transcript is short enough for Gemma's context.

- Measured 2026-10-11 on the demo keynote: `gemma-4-26b-a4b-it` with thinking `minimal` answers in 1–4 s; with its
  default thinking it takes 7–13 s and can spend the whole token budget thinking. `gemma-4-31b-it` took 40–85 s and
  returned HTTP 500 with thinking off, so it is not used. (`gemma-3-*` is not offered to our key.)
- Gemma on the Gemini API has no system instruction and no JSON mode: instructions go in the user turn,
  translations are requested as a JSON array and validated, with a per-line fallback.
- Model output is untrusted (`AGENTS.md` rule 12): cleaned to plain text, length-capped, shape-checked; transcript
  and question are fenced as data in the prompt.
- Answers are cached per session/language/revealed line count, so each one is generated once for everyone and the
  video can be recorded with warm answers while the real call path stays in place.
- Without `GEMINI_API_KEY` the service runs an offline extractive assistant (`model: "offline"`) for development.

## Consequences / follow-ups

- Someone has to create a Gemini API key (AI Studio) and put it in `backend/echo/.env` locally / the deploy env.
- If `backend-gemma-hosting` is later decided differently, Echo follows it by swapping the adapter.
