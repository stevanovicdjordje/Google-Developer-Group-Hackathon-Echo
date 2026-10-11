# Find: AI model and how it is called

- **ID:** `feature-find-ai`
- **Status:** accepted
- **Writer:** `feature:find` holder · @Vertiglo
- **Affects:** feature:find (backend/find); clients only through latency and the `model` field
- **Created:** 2026-10-11 · **Decided:** 2026-10-11 (requested by mobile in `mobile#15`, following `feature-echo-ai`)

## Context

Find uses a model for two things: the one-line "why" of each recommendation and prompt search ("someone who
shipped on-device ML"). Both rank anonymised profiles (headline, interests, lookingFor, labelled `c1`, `c2`…).
Find translates nothing. The first version ran everything on Gemma (`gemma-4-26b-a4b-it`). Echo moved its
reasoning features to a Gemini model the same morning (`feature-echo-ai`) because Gemini 3 Flash answered faster
and better.

## Options

- Gemma for both (as before)
- A Gemini model for both, Gemma only if Find ever translates (as Echo does)

## Decision

**A Gemini model for recommendations and prompt search**, configured by `AI_MODEL` (default
`gemini-3-flash-preview`, thinking `low`, +1024 output tokens for thinking). A `gemma-*` name in `AI_MODEL` still
works (thinking then defaults to `minimal`). The API's `model` field names the model that actually answered.

- **Hard timeout:** one model call, retries included, is cut at 8 s (`AI_TIMEOUT_SECONDS`); then that request
  gets the offline overlap ranking and reports `model: offline`. The demo never hangs on the model.
- At 04:30 `gemini-3.8-flash` and `3.7-flash` timed out on every call while 3 Flash answered in ~2.6 s (Echo's
  measurement), so 3 Flash is the default.
- Model output stays untrusted (`AGENTS.md` rule 12): only known candidate indices, deduplicated, plain-text
  `why` ≤ 240 characters; the profile text is fenced as data in the prompt. Names and user IDs never reach it.
- Without `GEMINI_API_KEY` the service ranks offline.

## Consequences / follow-ups

- Uses the same Gemini API key as Echo (`backend/find/.env` locally, the deploy env later).
- Latency with the real key is not measured on Find yet (no key on @Vertiglo's machine); the timeout bounds it.
