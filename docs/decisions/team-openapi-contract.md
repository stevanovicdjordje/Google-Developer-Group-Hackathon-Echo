# OpenAPI as the shared contract

- **ID:** `team-openapi-contract`
- **Status:** accepted
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · @Ilij4n
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** 2026-10-11

## Context

Clients and the backend are built in parallel by different people and agents.

## Options

- `contracts/openapi.yaml` + JSON fixtures in `contracts/examples/`.
- Ad-hoc agreement in chat.
- GraphQL schema.
- Shared code library.

## Decision

OpenAPI per contract folder (`contracts/openapi.yaml`, `contracts/maps/`, `contracts/echo/`) with fixtures and CHANGELOG. Real-time data via Firestore listeners (`contracts-realtime-transport`).

## Consequences / follow-ups

- Enables mock-first clients.
- Real-time transport is not covered by OpenAPI. See `contracts-realtime-transport.md`.
