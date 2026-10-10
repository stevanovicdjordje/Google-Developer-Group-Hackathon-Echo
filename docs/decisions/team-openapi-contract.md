# OpenAPI as the shared contract

- **ID:** `team-openapi-contract`
- **Status:** proposed
- **Writer:** Integration holder (fallback: repo owner's agent), recording what the humans agreed · handle TBD
- **Affects:** all
- **Created:** 2026-10-10 · **Decided:** —

## Context

Clients and the backend are built in parallel by different people and agents.

## Options

- `contracts/openapi.yaml` + JSON fixtures in `contracts/examples/`.
- Ad-hoc agreement in chat.
- GraphQL schema.
- Shared code library.

## Decision

Proposed: option 1.

## Consequences / follow-ups

- Enables mock-first clients.
- Real-time transport is not covered by OpenAPI. See `contracts-realtime-transport.md`.
