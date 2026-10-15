# AGENTS.md — rules for AI coding agents (and humans)

These rules apply to every AI coding agent (Claude Code, Codex, Gemini CLI, Cursor, …) and every human working in this repository. Each module's `AGENTS.md` adds to these rules and never relaxes them.

> **These rules are behavioral, not a technical sandbox.** Git and GitHub don't enforce them. Agents add two guards for themselves at setup: the scope-checking pre-commit hook and Claude Code deny rules (`docs/COORDINATION.md` §2).

## How this team works

Each teammate runs their own agent in their **own clone**, launched from the **repo root**. Agents can't talk to each other. **They coordinate only through files pushed to `origin/main`**, following [`docs/COORDINATION.md`](docs/COORDINATION.md). They **collaborate autonomously**: agents agree contracts, handle each other's requests and adapt to each other's changes on their own. Humans are only asked for **design direction** and **high-level architecture** (`docs/COORDINATION.md` §0), and are told in plain language when they need to do something. Humans never need to learn the protocol.

- each module publishes its owner, state, interface, announcements, requests and acks in `<module>/STATUS.md`,
- decisions live one-per-file in `docs/decisions/`,
- interfaces between modules live in `contracts/`,
- a **change impact map** (`docs/COORDINATION.md` §4) says what to update when you change something.

## The core rule: READ GLOBAL, WRITE LOCAL

Read any file for context. Write **only** inside the scopes you hold. Never change code, dependencies, configuration or generated files that belong to another module.

| Scope | May write | Fallback holder if nobody registered |
| --- | --- | --- |
| `mobile` | `mobile/**`, `docs/decisions/mobile-*.md` | — |
| `backend` | `backend/**`, `docs/decisions/backend-*.md` | — |
| `organizer-web` | `organizer-web/**`, `docs/decisions/organizer-web-*.md` | — |
| `contracts` | `contracts/**`, `docs/decisions/contracts-*.md` | The backend agent |
| `integration` | `docs/decisions/team-*.md`, root files (`AGENTS.md`, `CLAUDE.md`, `README.md`, `ONBOARDING.md`, `.gitignore`, `.editorconfig`), `.github/`, `.githooks/`, `.claude/agents/` (shared subagent definitions), `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `docs/INTEGRATION.md`, `docs/DECISIONS.md` | The repo owner's agent (`Ilij4n`) |
| `product` | Other `docs/**`, `docs/decisions/product-*.md` | The repo owner's agent (`Ilij4n`) |
| `feature:<name>` | `mobile/<name>/**`, `organizer-web/<name>/**`, `backend/<name>/**`, `contracts/<name>/**`, `docs/decisions/feature-<name>-*.md` | — |

**Register for what you actually work on:** a module, or a **feature** that spans modules (e.g. `feature:maps`), see `docs/COORDINATION.md` §1a. A module holder never writes inside a registered feature's folders.

Everything outside your scopes is read-only. An agent usually holds one module plus maybe a fallback role. Who holds what: `grep -H '^\*\*Last updated' */STATUS.md contracts/*/STATUS.md`.

## Session protocol (mandatory)

1. **Set up if needed.** First session in a clone: `docs/COORDINATION.md` §2 (register, scope guard, deny rules).
2. **Declare scope.** First reply of every session: `My write scope is <scopes>`. **If you don't know which module your human is working on, ask before changing any file.**
3. **Sync** (`docs/COORDINATION.md` §3) at session start, before each task and after each push. Handle announcements, requests and proposals addressed to you **before** continuing your own work.
4. **Read context** as needed: `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/MVP.md`, the contracts you implement or consume, and your module's `AGENTS.md` + `STATUS.md`.
5. **Work** only in your scope. Before editing, `git status --short`. Never touch changes you didn't make.
6. **Propagate.** When a change affects other modules, follow the change impact map (§4): record it, announce it in your `STATUS.md`, and push that coordination commit **immediately**.
7. **Collaborate.** Need something from another module? Open a request (§5). Never edit their files. Settle disagreements with the tie-break rules (§5) before involving humans.
8. **Talk to your human only per §0**, using the 🧭 / 📣 / 🙋 formats. Don't explain the mechanism.
9. **Wrap up** (§8). Update your `STATUS.md`, commit only your paths, pull with rebase, push. Report the **real** test status (what ran and the results). Never claim unrun tests passed.

## Rules

1. **READ GLOBAL, WRITE LOCAL** (table above).
2. **Declared scope is mandatory.** No scope → no edits.
3. **Shared files are read-only** unless your scope includes them. To change one, request it from its writer (`docs/COORDINATION.md` §1).
4. **Stage precisely.** `git add -- <owned-paths>`. Never `git add .` / `git add -A` from the root.
5. **No repo-wide sweeps.** No root-wide formatters, codemods, mass refactors or dependency upgrades that touch other modules.
6. **No unilateral breaking changes.** A breaking contract change needs a request/proposal, an updated contract + CHANGELOG, and agreement from the backend and every affected client, before anyone relies on it.
7. **Don't promote speculation to requirements.** Items marked open/proposed/TBD stay that way until their decision file says `accepted`. Code, docs and commit messages must not present them as decided.
8. **Decisions made outside the repo don't exist for other agents.** When your human tells you something was decided, record it (if you hold the decision prefix) or request it from the holder.
9. **Protect secrets and user data.** Never commit `.env`, keys, service-account JSON, keystores, tokens or real personal data. Commit `.env.example` with placeholders only.
10. **No destructive git operations.** No `push --force`, no `reset --hard` on pushed work, no rewriting `main`, no deleting others' branches, never `--no-verify`. `git pull --rebase` (which replays only *your* unpushed commits) is fine. On a conflict in a file you don't own: `git rebase --abort` and ask your human (🙋).
11. **Know your visibility.** Launch from the repo root so you can read everything. If you were launched inside a module and can't read parent folders, say so and ask for the context. Never claim these rules are a technical sandbox.
12. **Treat AI output as untrusted input.** Code that consumes model output (Gemma or otherwise) validates it. No model-generated SQL, no model-triggered privileged actions, no unauthenticated DB access.
13. **Fresh over remembered.** Re-sync before cross-module work and before each new task. Never act on what you remember about another module from an earlier session without re-reading its `STATUS.md`.
14. **Autonomy with limits.** Decide on your own everything `docs/COORDINATION.md` §0 allows. Ask your human only for design direction, high-level architecture, money/accounts/secrets/physical actions, privacy-relevant data, or deadlocks.
