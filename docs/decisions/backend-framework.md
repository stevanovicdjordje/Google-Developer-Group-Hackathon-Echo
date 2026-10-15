# Backend language and framework

- **ID:** `backend-framework`
- **Status:** accepted
- **Writer:** Backend owner · @Vertiglo
- **Affects:** backend (clients only via how to run it)
- **Created:** 2026-10-10 · **Decided:** 2026-10-10

## Context

The API server needs a runtime and framework.

## Options

- TypeScript/Node.js with Fastify, NestJS or Express
- Go with net/http
- Other

## Decision

**Go** (latest stable, toolchain pinned in `go.mod`), standard library `net/http` with Go 1.22+ route patterns, no web framework. `log/slog` logging, env-var config, graceful shutdown, `/healthz`. Firebase Admin SDK (`firebase.google.com/go/v4`) for ID-token verification, `cloud.google.com/go/firestore` and `cloud.google.com/go/storage`. Deployed as a container to **Cloud Run**.
Decided by the backend owner (@Vertiglo) on 2026-10-10.

## Consequences / follow-ups

- Each feature is an independent Go module/service in its own subfolder, e.g. `backend/maps/` (venue map). Gemma/STT adapters and other features get their own subfolders.
- Local run instructions and base URL in `backend/STATUS.md` → How to consume.
