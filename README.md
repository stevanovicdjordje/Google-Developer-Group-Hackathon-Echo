# Eho

> **Status: Draft / planned / undecided.** Nothing in this repository is implemented yet. This README describes intent, structure and team rules — not working features.

**Eho** is a hackathon project for the challenge **"Reimagine the Event Experience with Gemma"** (GDG Belgrade). The working idea is a multi-event platform for **attendees** and **organizers** with a contextual, Gemma-powered AI experience: joining an event, following the agenda and venue, following talks (transcripts/captions), asking questions and — optionally — opt-in networking.

> 🇷🇸 **Kratko:** Eho je hakaton projekat (tim od 4 osobe, ~24h razvoja). Ovaj repozitorijum je trenutno samo kostur i dokumentacija — ništa još nije implementirano. Svaki član radi isključivo u svom modulu; zajednički ugovor je u `contracts/`, a pravila za AI agente u `AGENTS.md`.

> **New teammate? Start with [`ONBOARDING.md`](ONBOARDING.md)**: a 2-minute setup. Your AI agent handles the rest.

Product scope, priorities and stack are **not locked**. See [`docs/PRODUCT.md`](docs/PRODUCT.md) and [`docs/MVP.md`](docs/MVP.md) for what is proposed and what is still open.

## Hackathon context

- **Challenge:** Reimagine the Event Experience with Gemma — how can AI improve events for attendees, speakers and organizers?
- **Expected:** meaningful use of Google **Gemma** models; other Google technologies where they genuinely help.
- **Constraints:** very short development window (~24h), team of 4.
- **Judging:** four areas — Problem, Technology, Business, Delivery. The exact questions are listed in [`docs/PRODUCT.md`](docs/PRODUCT.md#judging-criteria). Note especially: real user research, a **working demo (not a mockup)**, and at least one technical problem explained with how it was solved.

## What each part is (plain language)

Eho is planned as **two apps that share one server**, plus an agreed rulebook for how they talk:

```
  Attendee's phone             Organizer's laptop
 ┌──────────────┐             ┌────────────────┐
 │   mobile/    │             │ organizer-web/ │
 └──────┬───────┘             └───────┬────────┘
        │   both follow contracts/    │
        └──────────────┬──────────────┘
                ┌──────▼──────┐
                │  backend/   │──► Gemma (AI), speech-to-text, database
                └─────────────┘
```

| Part | What it is | Who uses it | What it does (planned, nothing is built yet) |
| --- | --- | --- | --- |
| **`mobile/`** | The **attendee app** | People attending the event | Join the event (QR/link), see the agenda and venue map, follow talks and ask questions, optionally meet other attendees |
| **`organizer-web/`** | The **organizer website** | The people running the event | Create the event, upload the agenda/speakers/map/slides, generate the join QR code, see questions and activity |
| **`backend/`** | The **server** both apps talk to | Nobody directly. The two apps use it. | Stores the event data, checks who's allowed to do what, and is the **only place that talks to the AI** (Gemma) and speech-to-text |
| **`contracts/`** | The **agreement between the apps and the server** | The agents building the three parts above | Lists exactly what the server offers (e.g. "give me the agenda for event X") and what the answer looks like, plus fake sample answers so the apps can be built before the server is ready. If an app needs something new, the change is agreed here first. |
| **`docs/`** | **Project knowledge** | Everyone, mostly the agents | What we're building and why, the demo plan, privacy rules, and a record of every decision (`docs/decisions/`) |

Each app folder also has a **`STATUS.md`**, that module's noticeboard: what works right now, how to use it, and messages for the other agents. The agents keep these up to date. Humans can read them but never have to.

## Repository layout

This is a deliberately simple monorepo: plain folders, no Nx/Turborepo, no submodules, no shared build system. Each module is opened and built independently in its owner's preferred IDE.

| Path | Purpose | Status |
| --- | --- | --- |
| [`mobile/`](mobile/) | Attendee app (join, agenda, map, transcript/Q&A, networking — candidates) | Not initialized — mobile owner decides stack |
| [`backend/`](backend/) | API, persistence, Gemma adapter, STT adapter, auth/roles | Not initialized — backend owner decides framework |
| [`organizer-web/`](organizer-web/) | Organizer setup, file import, dashboard | Not initialized — organizer-web owner decides framework |
| [`contracts/`](contracts/) | Shared OpenAPI contract, fixtures, CHANGELOG (the integration boundary) | Empty, valid OpenAPI skeleton — no endpoints agreed |
| [`docs/`](docs/) | Product, architecture, MVP, ownership, research, privacy, integration | Draft |
| [`docs/decisions/`](docs/decisions/) | One file per decision, each with status and writer | All open/proposed |
| `*/STATUS.md` | Each module's live state, interface, announcements and requests | Initialized, nothing implemented |
| [`docs/COORDINATION.md`](docs/COORDINATION.md) | How agents in different clones coordinate + change impact map | Active |
| `AGENTS.md`, `CLAUDE.md` | Rules for AI coding agents (READ GLOBAL, WRITE LOCAL) | Active |
| `.githooks/` | Optional pre-commit scope guard | Opt-in (see `ONBOARDING.md`) |

## Getting started (team members)

See **[`ONBOARDING.md`](ONBOARDING.md)**. In short: clone, start your AI agent (`claude` or `codex`) **from the repo root**, and paste the one-paragraph kickoff prompt naming your module. The agent sets itself up, coordinates with the other agents on its own, and only asks you about design direction and big architecture decisions.

## Central rules

- [`AGENTS.md`](AGENTS.md): rules for humans and AI agents (READ GLOBAL, WRITE LOCAL, session protocol).
- [`docs/COORDINATION.md`](docs/COORDINATION.md): `STATUS.md` files, decisions, requests, announcements, and the **change impact map** ("I changed X, what must I update?").
- [`docs/OWNERSHIP.md`](docs/OWNERSHIP.md): who owns which paths.
- [`contracts/`](contracts/): the shared API contract. Changes go through the contracts owner.

## Git workflow

- **Trunk-based on `main`.** Module paths don't overlap, so commit small, `git pull --rebase --autostash`, push often. Stage only your paths (`git add -- <your-module>/`).
- **Coordination updates** (`STATUS.md`, decisions, contracts) are committed separately and pushed **immediately**, so teammates' agents see them at their next sync.
- **Use a PR** (template in `.github/pull_request_template.md`) for breaking contract changes, rule changes, or anything you want reviewed.
- **Contract changes:** agents request them from the contracts holder via their module's `STATUS.md` (see `contracts/README.md`).
- No force-pushes, no `--no-verify`, no rebasing other people's pushed work.

## Open decisions (undecided)

One file per decision in [`docs/decisions/`](docs/decisions/) (how it works: [`docs/DECISIONS.md`](docs/DECISIONS.md)). Currently open, among others:

- Hero flow / demo slice — which single Gemma-powered use case we demo end-to-end.
- Mobile stack (Kotlin/Compose Multiplatform, Android-only, Flutter, web/PWA).
- Backend language/framework (TypeScript/Node.js is a candidate).
- Organizer web framework.
- Gemma model variant and where it runs (local, self-hosted GPU, Google-hosted endpoint).
- Speech-to-text provider, and whether live captions are in scope at all.
- Persistence / auth (Firebase or alternatives).
- Which organizer file formats are imported, and how they are validated.
- Owners for each workstream (agents register their humans automatically in `*/STATUS.md`).

## What this repo does **not** contain yet

No application code, no `package.json`, no Gradle project, no web framework scaffold, no deployed services and no secrets. Module owners initialize their own projects.
