# Eho — Cross-instance coordination protocol

Every teammate runs their own AI agent (Claude Code, Codex, …) in their **own clone** of this repo. Agents cannot talk to each other. **The only channel between them is git: what is pushed to `origin/main`.** This file defines:

1. where each kind of shared information lives, with exactly one writer per file,
2. what you must update when you change something (the **change impact map**),
3. how to sync at the start of a session, publish during it, and wrap up at the end.

Every agent reads this file at the start of every session. It is part of the rules in `AGENTS.md`.

---

## 1. Channels — one writer per file

| File | Writer | What it holds | Read by |
| --- | --- | --- | --- |
| `<module>/STATUS.md` (`mobile`, `backend`, `organizer-web`, `contracts`) | That module's owner/agent | Current state, how others consume/run it, **announcements**, **outbound/inbound requests** | Everyone, every session |
| `docs/decisions/<prefix>-<topic>.md` | The workstream named by the prefix (see below) | One decision each: `open` → `proposed` → `accepted` / `rejected` / `superseded` | Everyone |
| `contracts/openapi.yaml`, `contracts/examples/**`, other `contracts/*.md` | Contracts owner | Interfaces between modules (HTTP API, fixtures, and later QR/deep-link format, real-time events) | Everyone |
| `contracts/CHANGELOG.md` | Contracts owner | Every contract change, with compatibility impact | Everyone |
| `docs/MVP.md`, `docs/PRODUCT.md`, `docs/DATA_PRIVACY.md`, `docs/USER_RESEARCH.md`, `docs/TASKS.md` | Product/demo owner | Scope, priorities, privacy, research | Everyone |
| Root files (`AGENTS.md`, `CLAUDE.md`, `README.md`, `ONBOARDING.md`, `.gitignore`, `.editorconfig`), `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `docs/INTEGRATION.md`, `docs/DECISIONS.md`, `.githooks/`, `.github/` | Integration owner (same workstream as contracts) | Rules and process | Everyone |

**Why one writer per file:** with disjoint writers, parallel pushes don't conflict, and every fact has exactly one authoritative place.

**Decision file prefixes → who may write them**

| Prefix | Writer | Use for |
| --- | --- | --- |
| `mobile-` | Mobile owner | Decisions that live inside `mobile/` (stack, libraries, min SDK) |
| `backend-` | Backend owner | Decisions inside `backend/` (framework, persistence, Gemma hosting, STT provider) |
| `organizer-web-` | Organizer-web owner | Decisions inside `organizer-web/` |
| `contracts-` | Contracts owner | API style, versioning, real-time transport, error format |
| `product-` | Product/demo owner | Hero flow, scope, demo dataset |
| `team-` | Integration owner, **after the team agrees** | Cross-cutting decisions (auth, join flow, import formats, captions in/out) |

If you need a decision you can't write, open a **request** (§4) to its writer.

---

## 2. Session start — sync (mandatory)

Run this before any work, before starting each new task, and at least every ~2 hours in a long session. Never rely on what you remember about another module from an earlier session. Re-read it.

```bash
git status --short                      # 1. note local changes; never touch ones you didn't make
git fetch origin                        # 2. get teammates' pushes
git log --oneline HEAD..origin/main     # 3. what's new
git log --oneline HEAD..origin/main -- contracts docs '*/STATUS.md'   # 4. coordination-relevant
git diff HEAD...origin/main -- contracts docs '*/STATUS.md'           # 5. read the actual changes
git pull --rebase --autostash           # 6. update (rebases only YOUR unpushed commits)
```

Then read:

- `docs/COORDINATION.md` (this file; it may have changed),
- every `*/STATUS.md`, focusing on **Announcements** since your last sync and **Inbound/Outbound requests** that mention your module,
- `contracts/CHANGELOG.md` and any contract you consume or implement,
- the status line of every file in `docs/decisions/` (`grep -H '^- \*\*Status' docs/decisions/*.md`).

**Report to your human** (keep it short):

```
Sync report — <module> — <time>
New since last sync: <n commits; who/what in one line each, coordination-relevant only>
Affects us: <BREAKING/ACTION announcements, contract changes, accepted decisions that touch our module>
Requests for us: <inbound IDs + one line>        Our open requests: <IDs + their status>
Proposed next step: <one line>
```

If step 6 reports a conflict in a file **you don't own**: run `git rebase --abort`, stop, and tell your human. Do not resolve someone else's file.

---

## 3. Change impact map — "I changed X; what must I update?"

**Rule of thumb:** a change is **cross-module** if another module *calls, parses, generates, displays, deploys against, or assumes* it. A cross-module change must be (a) recorded in its source of truth below and (b) **announced** in your `STATUS.md`. Purely internal changes (refactors, internal libraries, a DB schema behind an unchanged API) only need your STATUS "Current state" kept honest.

| # | You change… | Source of truth (record it here) | Also update | Who must act | Typical tag |
| --- | --- | --- | --- | --- | --- |
| 1 | Your module's language / framework / build tool / min SDK | `docs/decisions/<module>-stack.md` (or `-framework`) → `accepted` | Your `STATUS.md` → *Stack* + announcement; your module `README.md` → *Setup* | Nobody, unless it changes how others run your module | INFO |
| 2 | An HTTP endpoint, field, type, error format or status code | `contracts/openapi.yaml` + `contracts/examples/` (contracts owner only) | `contracts/CHANGELOG.md`; `contracts/STATUS.md` announcement; backend and clients update *Contract coverage* in their STATUS | Backend + every consumer | additive → ACTION, breaking → BREAKING |
| 3 | You *need* an endpoint or field that doesn't exist | Outbound request in **your** `STATUS.md` → `contracts` | — | Contracts owner | — |
| 4 | Auth method, token format, roles, how an attendee/organizer signs in | `docs/decisions/team-auth.md` + `securitySchemes` in `openapi.yaml` | `backend/STATUS.md` → *How to consume* (how to get a dev token) | All | BREAKING / ACTION |
| 5 | Real-time transport (captions, live Q&A): polling / SSE / WebSocket, event shapes | `docs/decisions/contracts-realtime-transport.md` + a `contracts/realtime.md` (contracts owner) | `contracts/CHANGELOG.md` | All | ACTION |
| 6 | QR / join link / deep-link format, event join code | `docs/decisions/team-event-join.md` + a `contracts/deeplinks.md` (contracts owner) | Organizer-web (generates) and mobile (handles) STATUS coverage | organizer-web, mobile, backend | ACTION |
| 7 | Shared IDs, enums, naming (event/session IDs, language codes, session states) | Schemas in `contracts/openapi.yaml` | `contracts/CHANGELOG.md` | All | ACTION / BREAKING |
| 8 | How to run the backend locally, base URL, port, deployed demo URL, env vars clients need | `backend/STATUS.md` → *How to consume* | Announcement | mobile, organizer-web | ACTION |
| 9 | Gemma model, hosting, expected latency or limits | `docs/decisions/backend-gemma-hosting.md` | `backend/STATUS.md` → *How to consume* (latency, timeouts, rate limits) | Clients (loading/timeout UX), product (demo plan) | INFO / ACTION |
| 10 | STT provider, or live captions in/out of scope | `docs/decisions/team-captions-and-stt.md` | `docs/MVP.md` (product owner) | All | ACTION |
| 11 | Persistence, embeddings or retrieval store | `docs/decisions/backend-persistence.md` | `backend/STATUS.md` | Backend only, if the contract is unchanged | INFO |
| 12 | Organizer upload formats, size limits, parsing behavior | `docs/decisions/team-import-formats.md` + upload operation in `openapi.yaml` | `contracts/CHANGELOG.md` | organizer-web, backend | ACTION |
| 13 | MVP scope / hero flow / demo dataset | `docs/decisions/product-hero-flow.md`, `docs/MVP.md` (product owner) | `docs/TASKS.md` | All | ACTION |
| 14 | Collecting new personal data, retention, networking visibility | `docs/DATA_PRIVACY.md` (product owner) + the relevant contract | Note it in the commit/PR | All touching that data | ACTION |
| 15 | A new env var or secret your module needs | `<module>/.env.example` (placeholder only, never the value) | `STATUS.md` → *How to consume / run* | Whoever runs your module | INFO |
| 16 | Repo rules, ownership, hooks, CI | `AGENTS.md`, `docs/OWNERSHIP.md`, `docs/COORDINATION.md`, `.githooks/` (integration owner) | `contracts/STATUS.md` announcement | All | ACTION |

**A decision made outside the repo** (in chat, at the table) doesn't exist for other agents until it's written down. When your human tells you something was decided, ask whether it should be recorded. Then either write the decision file (if your workstream owns that prefix) or open a request to its owner.

**Never** "fix" another module to match your change. Announce it and let its owner adapt.

---

## 4. Requests — when you need something from another module

Requests live in **two** files, each edited only by its owner:

- The **requester** adds a row to *Outbound requests* in its own `STATUS.md`.
- The **recipient** sees it at sync and adds a matching row to *Inbound requests* in its own `STATUS.md`.

**ID format:** `<requester>#<n>`, numbered per module (`mobile#1`, `mobile#2`, `backend#1`). IDs never collide because each module numbers its own.

Lifecycle:

| Who | Where | Status values |
| --- | --- | --- |
| Requester | Outbound table | `open` → `closed` (when satisfied) or `withdrawn` |
| Recipient | Inbound table | `seen` → `accepted` / `declined` (with reason) → `done` (with a link to the commit, contract version or decision) |

A request should say **what** you need, **why** (which feature/flow), and **by when** it blocks you. For contract changes, include a sketch of the shape you'd like. It's input to the owner, not an instruction.

---

## 5. Announcements

The newest entry goes at the top of the *Announcements* list in your `STATUS.md`:

```
- 2026-10-11 14:20 · BREAKING · for: mobile, organizer-web · `GET /events/{id}/agenda` now returns `sessions[]` grouped by room. See contracts/CHANGELOG.md 0.3.0.
```

| Tag | Meaning |
| --- | --- |
| `BREAKING` | Others' code will break until they adapt. Needs prior agreement (an accepted request or decision), except in emergencies. |
| `ACTION` | Others should do something (switch URL, adopt a new field, re-run setup). |
| `INFO` | Good to know. Nobody needs to change anything. |

For `BREAKING` and `ACTION`, also **tell your human to ping the affected teammates in chat**. Git is pull-based, so others only see the announcement at their next sync.

---

## 6. Publishing coordination changes

Coordination is useless while it sits in your local clone.

- Commit coordination updates (STATUS, decision files, contract changes) **separately** from feature code, with a `coord(<scope>): …` or `contract: …` message.
- **Push them immediately**: `git pull --rebase --autostash && git push`.
- Day-to-day work is **trunk-based on `main`**, since module paths don't overlap. Commit small, pull often, push often. Never `--force`. If a push is rejected, pull with `--rebase` again and retry.
- Use a PR (instead of pushing to `main`) for: **breaking** contract changes, changes to rules files (`AGENTS.md`, this file), and anything your human wants reviewed.

Commit message convention (not enforced): `<type>(<scope>): <summary>`, where type is one of `feat`, `fix`, `chore`, `docs`, `test`, `coord`, `contract`, e.g. `feat(mobile): agenda list on fixtures`, `coord(backend): announce local dev URL`.

---

## 7. Session end

1. Update your `STATUS.md`: *Last updated*, *Current state*, *Contract coverage*, any announcements, and request statuses.
2. Record any decision made during the session (§3).
3. Commit your module work and the coordination update. Stage only your paths (`git add -- <your paths>`).
4. `git pull --rebase --autostash && git push`.
5. Tell your human: changed files, the **real** test status (what ran and the results; never claim unrun tests passed), and any BREAKING/ACTION items to ping teammates about.
