# Persistence, embeddings and retrieval store

- **ID:** `backend-persistence`
- **Status:** accepted
- **Writer:** Backend owner · @Vertiglo
- **Affects:** backend (others only if the contract changes)
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

Event content, Q&A and possibly embeddings need storage.

## Options

- Firestore
- Postgres (+ pgvector)
- SQLite/in-memory for the demo
- EmbeddingGemma + TBD index

## Decision

**Firestore** for event data and the venue map, **Cloud Storage for Firebase** for floor-plan images. Writes go only through the backend (Admin SDK). Clients read published data directly (see `contracts-realtime-transport.md`). Security rules live in `backend/firebase/`.
Embeddings / retrieval store remain **open** (not needed for the map).
Decided by the backend owner (@Vertiglo) on 2026-10-10.

## Consequences / follow-ups

- Layout: `events/{eventId}` + `draft/` and `published/` subcollections + `stats/{yyyy-mm-dd}`; documented in `backend/README.md`.
- Local development uses the Firebase emulators.
