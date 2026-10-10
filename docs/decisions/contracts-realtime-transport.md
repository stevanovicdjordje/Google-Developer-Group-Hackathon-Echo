# Real-time transport

- **ID:** `contracts-realtime-transport`
- **Status:** accepted
- **Writer:** Contracts holder (fallback: backend agent) · @Vertiglo
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

Captions or live Q&A may need push updates. OpenAPI doesn't describe that.

## Options

- Polling
- Server-Sent Events
- WebSocket
- Firestore listeners

## Decision

**Firestore snapshot listeners** on published data. The backend does not run a WebSocket/SSE server. Clients read `events/{eventId}/published/**` directly (read-only, enforced by security rules); every write goes through the HTTP API.
Applies to venue-map data now. Captions/Q&A may pick another transport later via a new decision.
Decided by the contracts holder (@Vertiglo) on 2026-10-10.

## Consequences / follow-ups

- `contracts/realtime.md` documents the readable Firestore paths and document shapes.
