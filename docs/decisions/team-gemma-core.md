# Gemma is the core AI model

- **ID:** `team-gemma-core`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-11

## Context

The challenge requires meaningful use of Gemma.

## Options

- At least one user-visible AI feature in the demo is powered by Gemma, behind a backend adapter.
- Using only other LLMs (would not meet the challenge).

## Decision

Gemma is used for real for translation (Echo, via the Gemini API). Other features may use other models; each feature records which model it uses in its STATUS/decision (`docs/MVP.md`).

## Consequences / follow-ups

- A Gemma proof-of-concept is an early priority (docs/TASKS.md 2.5).
