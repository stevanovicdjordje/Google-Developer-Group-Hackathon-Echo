# Eho — Agent coordination protocol

**Audience: AI agents.** Humans don't need to read or learn this. Every teammate runs their own agent in their **own clone**. Agents cannot talk to each other; **the only channel is git, meaning what's pushed to `origin/main`.** Agents run this protocol themselves and collaborate with each other **autonomously**. Humans give design direction and make the high-level calls listed in §0.

Read this file at the start of every session. It is part of the rules in `AGENTS.md`.

---

## 0. Autonomy: what you decide vs. what you ask your human

**Decide and act on your own, without asking:**
- anything inside your module: code structure, libraries within the chosen stack, tests, internal design,
- contract details: endpoint names, payload shapes, fields, error format, fixtures. Agree them with the other agents via requests/proposals (§5),
- handling other agents' requests, acknowledging proposals, updating your `STATUS.md`, recording decisions in your own prefix that follow from direction your human already gave,
- additive, non-breaking changes of any kind,
- resolving a disagreement with another agent using the tie-break rules in §5.

**Ask your human. These are the only reasons:**
1. **Design direction:** what the product does, the hero flow, UX/visual design, tone, which features to cut.
2. **High-level architecture:** the stack for your module, Gemma model/hosting, auth model, real-time approach, persistence choice, anything that is hard to reverse.
3. **Money, accounts, secrets, physical actions:** cloud projects, billing, API keys, signing in to services, installing on a device, recording audio.
4. **Privacy-relevant data:** collecting new personal data, retention, networking visibility.
5. **A deadlock:** a disagreement with another agent that §5's tie-break rules don't resolve, or a breaking change nobody acknowledged in time.

When you're unsure whether something is "high-level", ask yourself: would a teammate be surprised or upset to learn an agent decided this? If yes, ask.

### How to talk to your human

Your human doesn't know this protocol and shouldn't have to. **Never explain the mechanism** (STATUS files, requests, sync) unless asked. Tell them only what they need to do, in plain language, using these formats. Batch them; don't drip-feed.

**A decision only they can make:**
```
🧭 Decision needed: <one-line question>
   A) <option> — <consequence>
   B) <option> — <consequence>
   I recommend A because <reason>. Reply A or B (or tell me something else).
```

**A message for a teammate** (only when it's urgent or blocking; normally the other agent picks things up on its own at its next sync):
```
📣 Please send this to <name/@handle> (<their module>):
   "<short, self-contained message they can paste to their own agent or act on>"
```

**Something physical or account-related they must do:**
```
🙋 I need you to: <concrete action> — <why, one line>
```

**Routine:** after a sync, if nothing needs the human, say one line ("Synced: nothing needs you. Backend added the agenda endpoint; switching to it."). Don't dump the sync details.

---

## 1. Channels — one writer per file

| File | Writer | What it holds |
| --- | --- | --- |
| `<module>/STATUS.md` (`mobile`, `backend`, `organizer-web`, `contracts`) | That module's holder | **Owner and scopes held**, current state, how others consume/run it, announcements, requests, acks |
| `docs/decisions/<prefix>-<topic>.md` | Holder of the prefix's workstream | One decision each: `open` → `proposed` → `accepted` / `rejected` / `superseded` |
| `contracts/openapi.yaml`, `contracts/examples/**`, other `contracts/*.md`, `contracts/CHANGELOG.md` | Contracts holder | Interfaces between modules: HTTP API, fixtures, and later QR/deep-link format and real-time events |
| `docs/MVP.md`, `docs/PRODUCT.md`, `docs/DATA_PRIVACY.md`, `docs/USER_RESEARCH.md`, `docs/TASKS.md`, `docs/ARCHITECTURE.md` | Product holder | Scope, priorities, privacy, research |
| Root files (`AGENTS.md`, `CLAUDE.md`, `README.md`, `ONBOARDING.md`, `.gitignore`, `.editorconfig`), `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `docs/INTEGRATION.md`, `docs/DECISIONS.md`, `.githooks/`, `.github/`, `.claude/agents/` (shared subagent definitions; name them `<scope>-*.md`) | Integration holder | Rules and process |

One writer per file means parallel pushes don't conflict, and every fact has one authoritative place.

### Workstreams, prefixes and fallback holders

| Workstream | Decision prefix | Default holder if nobody registered for it |
| --- | --- | --- |
| mobile | `mobile-` | — (whoever the human says) |
| backend | `backend-` | — |
| organizer-web | `organizer-web-` | — |
| contracts | `contracts-` | **The backend agent.** It implements the contract, so it also curates it. |
| integration | `team-` | **The repo owner's agent** (`Ilij4n`) |
| product | `product-` | **The repo owner's agent** (`Ilij4n`) |

**Who holds what:** every agent registers its human and scopes on the `Owner` line of its primary module's `STATUS.md` (§2). To find who holds a workstream, run `grep -H '^\*\*Last updated' */STATUS.md`. If no one registered it, the fallback above applies. If you need something from a workstream, its holder's agent is who you address in requests, and its human is who you name in a 📣 message.

`team-` decisions are high-level by definition. They're made by humans (§0), and the integration holder only records them.

### 1a. Feature scopes

A feature that spans the app, the server and the contract (e.g. the venue map) can be held as **`feature:<name>`** (lowercase) instead of whole modules. A feature owns the folder `<name>/` in every module, and only that:

| Area | Feature paths |
| --- | --- |
| App | `mobile/<name>/**` (a Flutter package the app shell depends on) |
| Organizer web | `organizer-web/<name>/**` |
| Backend | `backend/<name>/**` (its own service/module) |
| Contract + feature home | `contracts/<name>/**`: the feature's `openapi.yaml`, fixtures, `CHANGELOG.md`, **`STATUS.md`**, `PLAN.md` |
| Decisions | `docs/decisions/feature-<name>-*.md` |

1. **Registering** a feature = creating `contracts/<name>/STATUS.md` (same format as module STATUS files) with `**Owner:** @<handle> · **Scopes held:** feature:<name>`. From then on, `<module>/<name>/` folders belong to that feature, and module holders don't write there (the scope guard enforces it).
2. **Module shells stay with the module holder:** everything outside feature folders (e.g. `mobile/app/` with `pubspec.yaml`, router, `main.dart`; root `contracts/openapi.yaml`; shared backend code). The feature holder asks via a request in its feature STATUS.
3. **Unheld module → don't block:** if a module has no registered holder, the feature holder may make the **minimal additive** change it needs in the module shell (add the package dependency, mount a route) and announces it as `ACTION`.
4. **Features never edit each other's folders.** Shared code is a request to the module holder.
5. The feature holder acts as contracts holder **for `contracts/<name>/` only**, following `contracts/AGENTS.md`.
6. Feature names must not collide with existing module subfolders (`app`, `docs`, `examples`, `scripts`).

---

## 2. First session in a new clone — set yourself up

Do this once per clone, without bothering your human except to learn which module they're working on (if the kickoff prompt didn't say).

1. **Identify your human:** `gh api user -q .login` (or `git config user.name`).
2. **Work out your scopes:** the module **or feature** (`feature:<name>`, §1a) your human named, plus any fallback workstreams from §1 that apply to you and that nobody else registered (check `grep -H '^\*\*Last updated' */STATUS.md`).
3. **Register:** in your primary module's `STATUS.md` (or, for a feature, create `contracts/<name>/STATUS.md`), set `**Owner:** @<handle> · **Scopes held:** <list>`. If you hold contracts, also set the Owner line in `contracts/STATUS.md`. Commit with `coord(<module>): register owner` and push.
4. **Turn on the scope guard** (blocks commits outside your scopes):
   ```bash
   git config core.hooksPath .githooks
   git config eho.scope <comma-separated scopes>     # e.g. backend,contracts
   ```
5. **(Claude Code, launched from the repo root) Add deny rules** so your file tools can't touch other modules. Create or merge `.claude/settings.local.json` (git-ignored). Deny `Edit(/<area>/**)` for every top-level area you don't hold, plus `Edit(/docs/decisions/<prefix>-*)` for every prefix you don't hold. Add `Edit(/*.md)`, `Edit(/docs/*.md)`, `Edit(/.github/**)`, `Edit(/.githooks/**)`, `Edit(/.gitignore)` and `Edit(/.editorconfig)` unless you hold integration (or `docs/*.md` unless you hold product). Your human may need to approve this edit once.
6. Run the sync (§3) and tell your human, in 2–3 lines, that you're set up, what the team state is, and what you propose to work on first, or ask for direction (🧭) if the hero flow / your stack isn't decided yet.

---

## 3. Sync — keep up with the other agents

**When:** at session start, **before each new task**, **after each push**, and whenever you're waiting on your human. Never act on what you remember about another module without re-reading it.

```bash
git status --short                      # note local changes; never touch ones you didn't make
git fetch origin
git log --oneline HEAD..origin/main -- contracts docs '*/STATUS.md'   # coordination-relevant (includes feature STATUS files)
git diff HEAD...origin/main -- contracts docs '*/STATUS.md'           # read what changed
git pull --rebase --autostash           # replays only YOUR unpushed commits
```

If the pull conflicts in a file you don't hold: `git rebase --abort` and tell your human (🙋). Don't resolve someone else's file.

Then read every `*/STATUS.md` and `contracts/*/STATUS.md` (announcements, and requests/proposals mentioning you), `contracts/CHANGELOG.md`, and the decision statuses (`grep -H '^- \*\*Status' docs/decisions/*.md`).

**Handle what you find before continuing your own task**, in this order:
1. `BREAKING` / `ACTION` announcements that affect you → adapt your module (or plan it as your next task).
2. Inbound requests → mark them `seen`, then do the ones within your authority (§0) and mark them `done`. Escalate only per §0.
3. Proposals awaiting your ack → ack or object (§5).
4. Newly `accepted` decisions → apply their consequences in your module.

Report to your human using the "Routine" format in §0, unless something needs them.

---

## 4. Change impact map — "I changed X; what must I update?"

**Rule of thumb:** a change is **cross-module** if another module *calls, parses, generates, displays, deploys against, or assumes* it. Record a cross-module change at its source of truth below **and** announce it in your `STATUS.md`. Purely internal changes only need your STATUS *Current state* kept honest.

| # | You change… | Source of truth (record it here) | Also update | Who must act | Tag |
| --- | --- | --- | --- | --- | --- |
| 1 | Your module's language / framework / build tool / min SDK *(ask your human first, §0)* | `docs/decisions/<module>-stack.md` (or `-framework`) → `accepted` | Your `STATUS.md` → *Stack*; your module `README.md` → *Setup* | Nobody, unless it changes how others run your module | INFO |
| 2 | An HTTP endpoint, field, type, error format or status code | `contracts/openapi.yaml` + `contracts/examples/` (contracts holder) | `contracts/CHANGELOG.md`; `contracts/STATUS.md` announcement; implementers/consumers update *Contract coverage* | Backend + every consumer | additive → ACTION, breaking → BREAKING |
| 3 | You *need* an endpoint or field that doesn't exist | Outbound request in **your** `STATUS.md` → `contracts` | — | Contracts holder | — |
| 4 | Auth method, token format, roles *(high-level, §0)* | `docs/decisions/team-auth.md` + `securitySchemes` in `openapi.yaml` | `backend/STATUS.md` → *How to consume* (how to get a dev token) | All | BREAKING / ACTION |
| 5 | Real-time transport *(high-level, §0)* | `docs/decisions/contracts-realtime-transport.md` + `contracts/realtime.md` | `contracts/CHANGELOG.md` | All | ACTION |
| 6 | QR / join link / deep-link format, event join code | `docs/decisions/team-event-join.md` + `contracts/deeplinks.md` | Organizer-web (generates) and mobile (handles) coverage | organizer-web, mobile, backend | ACTION |
| 7 | Shared IDs, enums, naming (event/session IDs, language codes, states) | Schemas in `contracts/openapi.yaml` | `contracts/CHANGELOG.md` | All | ACTION / BREAKING |
| 8 | How to run the backend locally, base URL, port, deployed URL, env vars clients need | `backend/STATUS.md` → *How to consume* | Announcement | mobile, organizer-web | ACTION |
| 9 | Gemma model, hosting, expected latency/limits *(high-level, §0)* | `docs/decisions/backend-gemma-hosting.md` | `backend/STATUS.md` → *How to consume* | Clients (loading/timeout UX), product | INFO / ACTION |
| 10 | STT provider, live captions in/out *(high-level, §0)* | `docs/decisions/team-captions-and-stt.md` | `docs/MVP.md` (product holder) | All | ACTION |
| 11 | Persistence, embeddings, retrieval store | `docs/decisions/backend-persistence.md` | `backend/STATUS.md` | Backend only, if the contract is unchanged | INFO |
| 12 | Organizer upload formats, size limits, parsing | `docs/decisions/team-import-formats.md` + upload operation in `openapi.yaml` | `contracts/CHANGELOG.md` | organizer-web, backend | ACTION |
| 13 | MVP scope / hero flow / demo dataset *(design direction, §0)* | `docs/decisions/product-hero-flow.md`, `docs/MVP.md` | `docs/TASKS.md` | All | ACTION |
| 14 | New personal data, retention, networking visibility *(§0)* | `docs/DATA_PRIVACY.md` + the relevant contract | Commit message | All touching that data | ACTION |
| 15 | A new env var or secret your module needs | `<module>/.env.example` (placeholder only) | `STATUS.md` → *How to consume / run*; 🙋 your human if they must obtain the value | Whoever runs your module | INFO |
| 16 | Repo rules, ownership, hooks, CI | Integration files (integration holder) | `contracts/STATUS.md` announcement if you hold contracts, otherwise your own `STATUS.md` | All | ACTION |

**A decision your human tells you about** (made in chat or at the table) doesn't exist for other agents until it's written down. Record it right away: a decision file if you hold its prefix, otherwise a request to the holder.

**Never** "fix" another module to match your change. Announce it, and its agent adapts.

---

## 5. Requests, proposals and agreement between agents

### Requests ("I need something from you")

- The **requester** adds a row to *Outbound requests* in its own `STATUS.md`.
- The **recipient** sees it at its next sync, mirrors it in *Inbound requests*, and handles it per §3.
- **ID:** `<requester-module>#<n>` (`mobile#1`, `backend#1`, …). Each module numbers its own, so IDs never collide.
- **Statuses:** requester `open` → `closed` / `withdrawn`; recipient `seen` → `accepted` / `declined` (with a reason) → `done` (with a link to the commit, contract version or decision).
- Say **what** you need, **why** (which flow), and a sketch of the shape. It's input to the holder, not an instruction.

### Proposals ("I'm about to change something you depend on")

- Post the proposal as an announcement in your `STATUS.md` with an ID (`<module>#<n>`) and `needs ack from: <modules>`.
- **Additive / non-breaking:** no ack needed. Just do it and announce `ACTION`.
- **Breaking:** each affected agent acks or objects in its own `STATUS.md` → *Acks* table. Proceed when all acks are in.
- **No response within ~2 hours:** ask your human to nudge the silent teammate (📣, with a one-line message like *"please run your agent; it has a pending request from backend"*).

### Tie-break rules (apply them before escalating)

1. **Additive beats breaking.** If a change can be made additive (new field, new endpoint, new version), do that.
2. **The hero flow wins.** Prefer whatever unblocks the agreed demo flow (`product-hero-flow.md`).
3. **Feasibility belongs to the implementer.** The backend decides what it can actually serve; clients decide what they can actually render.
4. **Shape disputes:** the contracts holder decides.
5. **Simplest thing that demos.** We have ~24h.

If these don't settle it after one counter-proposal, escalate to both humans with a 🧭 that states both options neutrally.

---

## 6. Announcements

The newest entry goes at the top of *Announcements* in your `STATUS.md`:

```
- 2026-10-11 14:20 · BREAKING · backend#3 · for: mobile, organizer-web · `GET /events/{id}/agenda` now returns `sessions[]` grouped by room. See contracts/CHANGELOG.md 0.3.0.
```

Use real timestamps (`date '+%Y-%m-%d %H:%M'`).

| Tag | Meaning |
| --- | --- |
| `BREAKING` | Others' code breaks until they adapt. Needs acks first (§5), except in emergencies. |
| `ACTION` | Other agents should do something at their next sync. |
| `INFO` | Good to know. Nobody needs to change anything. |

The other agents pick these up on their own. Ask your human to ping someone (📣) only if it's **urgent or blocking**.

---

## 7. Publishing

Coordination is useless while it sits in your local clone.

- Commit coordination updates (STATUS, decision files, contract changes) **separately** from feature code, with a `coord(<scope>): …` or `contract: …` message, and **push immediately**: `git pull --rebase --autostash && git push`.
- Day-to-day work is **trunk-based on `main`**, since module paths don't overlap. Commit small, push often. Never `--force`. If a push is rejected, pull with rebase and retry.
- Use a PR instead of pushing to `main` only for breaking contract changes, rule changes, or when your human asks.
- Commit messages: `<type>(<scope>): <summary>` with type `feat` | `fix` | `chore` | `docs` | `test` | `coord` | `contract`.

---

## 8. Wrap-up (end of a task or session)

1. Update your `STATUS.md`: *Last updated*, *Current state*, *Contract coverage*, announcements, request/ack statuses.
2. Record any decision made during the session (§4).
3. Commit only your paths (`git add -- <your paths>`), then pull with rebase and push.
4. Tell your human briefly what changed, the **real** test status (never claim unrun tests passed), and any 🧭 / 📣 / 🙋 items.
