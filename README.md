# Eho

> **Status: Draft / planned / undecided.** Nothing in this repository is implemented yet. This README describes intent, structure and team rules — not working features.

**Eho** is a hackathon project for the challenge **"Reimagine the Event Experience with Gemma"** (GDG Belgrade). The working idea is a multi-event platform for **attendees** and **organizers** with a contextual, Gemma-powered AI experience: joining an event, following the agenda and venue, following talks (transcripts/captions), asking questions and — optionally — opt-in networking.

> 🇷🇸 **Kratko:** Eho je hakaton projekat (tim od 4 osobe, ~24h razvoja). Ovaj repozitorijum je trenutno samo kostur i dokumentacija — ništa još nije implementirano. Svaki član radi isključivo u svom modulu; zajednički ugovor je u `contracts/`, a pravila za AI agente u `AGENTS.md`.

Product scope, priorities and stack are **not locked**. See [`docs/PRODUCT.md`](docs/PRODUCT.md) and [`docs/MVP.md`](docs/MVP.md) for what is proposed and what is still open.

## Hackathon context

- **Challenge:** Reimagine the Event Experience with Gemma — how can AI improve events for attendees, speakers and organizers?
- **Expected:** meaningful use of Google **Gemma** models; other Google technologies where they genuinely help.
- **Constraints:** very short development window (~24h), team of 4.
- **Judging:** four areas — Problem, Technology, Business, Delivery. The exact questions are listed in [`docs/PRODUCT.md`](docs/PRODUCT.md#judging-criteria). Note especially: real user research, a **working demo (not a mockup)**, and at least one technical problem explained with how it was solved.

## Repository layout

This is a deliberately simple monorepo: plain folders, no Nx/Turborepo, no submodules, no shared build system. Each module is opened and built independently in its owner's preferred IDE.

| Path | Purpose | Status |
| --- | --- | --- |
| [`mobile/`](mobile/) | Attendee app (join, agenda, map, transcript/Q&A, networking — candidates) | Not initialized — mobile owner decides stack |
| [`backend/`](backend/) | API, persistence, Gemma adapter, STT adapter, auth/roles | Not initialized — backend owner decides framework |
| [`organizer-web/`](organizer-web/) | Organizer setup, file import, dashboard | Not initialized — organizer-web owner decides framework |
| [`contracts/`](contracts/) | Shared OpenAPI contract + example fixtures (the integration boundary) | Empty, valid OpenAPI skeleton — no endpoints agreed |
| [`docs/`](docs/) | Product, architecture, MVP, ownership, decisions, tasks, research, privacy, integration | Draft |
| `AGENTS.md`, `CLAUDE.md` | Rules for AI coding agents (READ GLOBAL, WRITE LOCAL) | Active |

## Getting started (team members)

```bash
git clone git@github.com:Ilij4n/eho.git
cd eho
git switch -c <module>/<short-description>    # e.g. backend/health-endpoint
```

1. Find your workstream and owned paths in [`docs/OWNERSHIP.md`](docs/OWNERSHIP.md).
2. Work **only inside your own module**. Read everything else for context.
3. Open only your module in your IDE:
   - `mobile/` → Android Studio / Fleet (once the mobile owner initializes it)
   - `backend/` → WebStorm / VS Code (once initialized)
   - `organizer-web/` → your web IDE of choice (once initialized)
4. Until an API is agreed and implemented, build UI against fixtures in `contracts/examples/`.
5. Stage only your paths: `git add -- <your-module>/` (avoid `git add .` from the root).

## Central rules

- [`AGENTS.md`](AGENTS.md) — rules for humans and AI agents. **Read before any AI-assisted session.**
- [`docs/OWNERSHIP.md`](docs/OWNERSHIP.md) — who owns which paths.
- [`contracts/`](contracts/) — the shared API contract. Changes go through the contract/integration owner.
- [`docs/INTEGRATION.md`](docs/INTEGRATION.md) — contract-first workflow, parallel agents, testing.

## Branches, PRs and contract changes

- `main` should stay in a demo-able state. Work in short-lived branches named `<module>/<topic>`.
- Open a PR using the template in `.github/pull_request_template.md`. Keep each PR inside one module where possible.
- **Contract changes** (`contracts/**`): open a separate PR, tag the contract/integration owner, and describe the impact on mobile, organizer-web and backend. Do not change a contract and a consumer in one unreviewed step.
- Shared docs/root files: ask the integration/docs owner (see `docs/OWNERSHIP.md`).
- No force-pushes, no rebasing other people's branches.

## Open decisions (undecided)

Tracked in [`docs/DECISIONS.md`](docs/DECISIONS.md). Currently open, among others:

- Hero flow / demo slice — which single Gemma-powered use case we demo end-to-end.
- Mobile stack (Kotlin/Compose Multiplatform, Android-only, Flutter, web/PWA).
- Backend language/framework (TypeScript/Node.js is a candidate).
- Organizer web framework.
- Gemma model variant and where it runs (local, self-hosted GPU, Google-hosted endpoint).
- Speech-to-text provider, and whether live captions are in scope at all.
- Persistence / auth (Firebase or alternatives).
- Which organizer file formats are imported, and how they are validated.
- Owners for each workstream.

## What this repo does **not** contain yet

No application code, no `package.json`, no Gradle project, no web framework scaffold, no deployed services and no secrets. Module owners initialize their own projects.
