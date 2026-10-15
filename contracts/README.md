# contracts/ — shared API contract

**In plain words:** this folder is the agreement between the apps (`mobile/`, `organizer-web/`) and the server (`backend/`). It lists exactly what the server offers (e.g. "give me the agenda for event X") and what each answer looks like, plus fake sample answers so the apps can be built before the server exists. Nobody changes it unilaterally: the change is agreed here first, then everyone builds to it.

> **Status: Draft.** `openapi.yaml` is a valid but **empty** OpenAPI skeleton. No endpoint, field name, response shape, auth scheme or upload format has been agreed yet. These are defined together with the workstream owners.

## Why this folder exists

`contracts/` is the integration boundary between `mobile/`, `organizer-web/` and `backend/`. Clients build against the contract and its fixtures, and the backend implements it. That lets the team work in parallel without waiting on each other.

## Policy

- **Who changes it:** only the **contracts holder**: whoever registered the `contracts` scope, otherwise the backend agent (`docs/COORDINATION.md` §1).
- **How to ask for a change:** add an outbound request addressed to `contracts` in **your own** module's `STATUS.md` (`docs/COORDINATION.md` §5), with what you need, why, and when it blocks you.
- **How changes land:** the procedure in [`AGENTS.md`](AGENTS.md): agree, edit spec + fixtures, validate, then write a [`CHANGELOG.md`](CHANGELOG.md) entry with **compatibility impact** (additive / breaking / fixture-only) and affected consumers, then announce in [`STATUS.md`](STATUS.md). Breaking changes go via a PR.
- **Agree first:** server and client owners agree on a change *before* anyone implements against it. Breaking changes need explicit sign-off from every affected consumer.
- **Status:** until it is marked approved, an endpoint in the spec is a *proposal*. It is not a working API.
- **Fixtures follow the spec:** every approved endpoint should have example request/response JSON in `examples/` that validates against the schema.

## Files

| File | Purpose |
| --- | --- |
| `openapi.yaml` | The HTTP API contract |
| `examples/` | Fixtures / mocks that validate against the spec |
| `CHANGELOG.md` | Every contract change, with impact |
| `STATUS.md` | Approved operations, proposals under discussion, announcements, requests |
| `deeplinks.md`, `realtime.md` | *Not yet created.* Non-HTTP contracts, added once `team-event-join` / `contracts-realtime-transport` are decided |

## Candidate API areas (illustrative — NOT agreed)

These are topics the contract will probably need to cover. They are listed for discussion only:

- Event join (QR / link / code)
- Agenda: sessions, rooms, speakers
- Room / session details
- Organizer event setup and file upload
- Transcripts / captions
- Q&A (submit, list, cluster/summarize)
- Networking profiles and search (opt-in)
- Organizer dashboard data

## Versioning (proposal)

- `info.version` uses semver: minor bump for additive, major bump for breaking. While below `1.0.0`, breaking changes bump the minor version and are flagged **BREAKING** in `CHANGELOG.md`.
- No URL versioning is decided yet.

## Validation

Lint the spec before merging a contract PR, e.g.:

```bash
npx @redocly/cli lint contracts/openapi.yaml
```

(No tooling is installed in the repo; any OpenAPI linter is fine.)
