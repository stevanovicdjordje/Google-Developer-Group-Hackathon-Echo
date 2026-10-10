# contracts/examples/ — fixtures and mocks

> **Status: Empty.** No fixtures exist yet because no endpoints have been agreed.

## Purpose

Example JSON request/response payloads that:

- let `mobile/` and `organizer-web/` build UI **before** the backend exists (mock-first),
- give the backend concrete targets for its responses,
- can be validated against `../openapi.yaml` schemas in CI or locally.

## Conventions (proposal)

- One file per example: `<operationId>.<request|response>[.<variant>].json`, e.g. `getAgenda.response.json`, `joinEvent.response.invalid-code.json`.
- Fixtures must validate against the current schema and are updated in the same PR as the schema change.
- Use **clearly fake data** only: no real names, emails, photos or transcripts of real people.
- A fixture added for discussion, before its endpoint is approved, goes in an `illustrative/` subfolder and is not relied on by clients.

## Who changes this folder

Same policy as `contracts/`: the contract/integration owner, or an explicitly authorized member. Other modules may keep their own local mocks inside their module.
