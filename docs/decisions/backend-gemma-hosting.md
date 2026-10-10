# Gemma model and hosting

- **ID:** `backend-gemma-hosting`
- **Status:** open
- **Writer:** Backend owner · handle TBD
- **Affects:** backend; clients (latency/timeouts); product (demo plan)
- **Created:** 2026-10-10 · **Decided:** —

## Context

Gemma must power at least one feature. Self-hosted GPU availability, cost and latency are unknown.

## Options

- Local machine (demo laptop)
- Self-hosted GPU (e.g. Cloud Run GPU + vLLM)
- Google-hosted Gemma endpoint
- Model size/variant: TBD

## Decision

_Open — not decided._

## Consequences / follow-ups

- Publish expected latency, timeouts and limits in `backend/STATUS.md` → How to consume.
