# Persistence, embeddings and retrieval store

- **ID:** `backend-persistence`
- **Status:** open
- **Writer:** Backend owner · handle TBD
- **Affects:** backend (others only if the contract changes)
- **Created:** 2026-10-10 · **Decided:** —

## Context

Event content, Q&A and possibly embeddings need storage.

## Options

- Firestore
- Postgres (+ pgvector)
- SQLite/in-memory for the demo
- EmbeddingGemma + TBD index

## Decision

_Open — not decided._

## Consequences / follow-ups

- Internal to backend as long as the contract is unchanged.
