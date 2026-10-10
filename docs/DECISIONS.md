# Eho — Decisions (ADR-lite)

> No technology choice is **accepted** yet. The entries below are **proposed** and wait for team agreement. TypeScript, Compose Multiplatform, Firebase, any hosting platform and any specific Gemma model are **candidates only**.

## Template

```markdown
### ADR-NNN: <title>

- **Date:** YYYY-MM-DD
- **Status:** proposed | accepted | rejected | superseded by ADR-NNN
- **Owner:** @handle / TBD
- **Context:** Why is a decision needed?
- **Decision:** What we chose.
- **Alternatives:** What else was considered, and why not.
- **Consequences:** What this makes easier or harder.
```

---

### ADR-001: Single monorepo with independent modules

- **Date:** 2026-10-10
- **Status:** proposed
- **Owner:** TBD
- **Context:** 4 people, ~24h, three apps plus a shared contract. We need shared visibility without a shared build system.
- **Decision:** One Git repo with plain folders (`mobile/`, `backend/`, `organizer-web/`, `contracts/`, `docs/`). No Nx/Turborepo, submodules or package publishing. Each module is built independently.
- **Alternatives:** Multiple repos (harder to keep the contract in sync); monorepo tooling (setup cost not justified).
- **Consequences:** Simple. Boundaries rely on discipline (`AGENTS.md`) and PR review, not tooling.

### ADR-002: OpenAPI as the shared contract

- **Date:** 2026-10-10
- **Status:** proposed
- **Owner:** TBD
- **Context:** Clients and the backend are built in parallel by different people and agents.
- **Decision:** `contracts/openapi.yaml` is the single source of truth for the HTTP API, with JSON fixtures in `contracts/examples/`.
- **Alternatives:** Ad-hoc agreement in chat; GraphQL schema; shared code library.
- **Consequences:** Enables mock-first clients. Requires discipline about contract changes. Real-time transport (if needed) is not covered by OpenAPI and needs its own decision.

### ADR-003: Private GitHub repository

- **Date:** 2026-10-10
- **Status:** proposed
- **Owner:** TBD
- **Context:** Early-stage hackathon work; may contain draft research or event data.
- **Decision:** Keep the repo private. The repo owner invites collaborators manually.
- **Alternatives:** Public from the start.
- **Consequences:** Making it public later requires a review for secrets and personal data.

### ADR-004: Two primary roles — attendee and organizer

- **Date:** 2026-10-10
- **Status:** proposed
- **Owner:** TBD
- **Context:** The challenge mentions attendees, speakers and organizers.
- **Decision:** Model two app roles (attendee, organizer). Speakers are a stakeholder but not a separate role for now.
- **Alternatives:** A dedicated speaker role/app.
- **Consequences:** Speaker-facing features (if any) are delivered via the organizer view or a later role.

### ADR-005: Gemma is the core AI model

- **Date:** 2026-10-10
- **Status:** proposed
- **Owner:** TBD
- **Context:** The challenge requires meaningful use of Gemma.
- **Decision:** At least one user-visible AI feature in the demo is powered by a Gemma model, behind a backend adapter. **Which** Gemma model and **where** it runs are open (see below).
- **Alternatives:** Using only other LLMs (would not meet the challenge).
- **Consequences:** Hosting/latency/cost must be solved early. A Gemma proof-of-concept is a priority task.

---

## Open decisions (no proposal yet)

| Topic | Candidates | Who decides |
| --- | --- | --- |
| Hero flow / demo slice | See `MVP.md` | Whole team / product owner |
| Mobile stack | Kotlin/Compose Multiplatform, Android-only, Flutter, web/PWA | Mobile owner |
| Backend language/framework | TypeScript/Node.js (Fastify/NestJS/Express), other | Backend owner |
| Organizer web framework | TBD | Organizer-web owner |
| Gemma model + hosting | Local, self-hosted GPU, Cloud Run GPU + vLLM, Google-hosted endpoint | Backend owner + team |
| STT provider / captions in scope | Google Cloud STT, other, or out of scope | Backend owner + team |
| Persistence / auth | Firebase (Auth, Firestore), alternatives | Backend owner |
| Embeddings / retrieval store | EmbeddingGemma + TBD index | Backend owner |
| Organizer import formats | CSV, spreadsheet, PDF, manual entry | Organizer-web + backend owners |
| Real-time transport | Polling, SSE, WebSocket | Contracts owner |
