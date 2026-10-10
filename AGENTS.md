# AGENTS.md — rules for AI coding agents (and humans)

These rules apply to every AI coding agent (Claude Code, Codex, Gemini CLI, Cursor, …) and every human working in this repository. Each module's `AGENTS.md` adds to these rules and never relaxes them.

> **These rules are behavioral, not a technical sandbox.** Git and GitHub don't enforce them. Optional guards exist: the scope-checking pre-commit hook and Claude Code deny rules (see `ONBOARDING.md`). Humans still review diffs.

## How this team works

Each teammate runs their own agent in their **own clone**, usually with the IDE opened on one module and the agent launched from the **repo root** so it can read everything. Agents can't talk to each other. **They coordinate only through files pushed to `origin/main`**, following [`docs/COORDINATION.md`](docs/COORDINATION.md):

- each module publishes its state, interface, announcements and requests in `<module>/STATUS.md`,
- decisions live one-per-file in `docs/decisions/`,
- interfaces between modules live in `contracts/`,
- a **change impact map** says what to update when you change something.

## The core rule: READ GLOBAL, WRITE LOCAL

Read any file for context. Write **only** inside your assigned scope. Never change code, dependencies, configuration or generated files that belong to another module.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Mobile | `mobile/**`, `docs/decisions/mobile-*.md` | `backend/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |
| Backend | `backend/**`, `docs/decisions/backend-*.md` | `mobile/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |
| Organizer web | `organizer-web/**`, `docs/decisions/organizer-web-*.md` | `mobile/**`, `backend/**`, `contracts/**`, `docs/**`, root |
| Contracts / integration owner | `contracts/**`, `docs/decisions/contracts-*.md`, `docs/decisions/team-*.md`, root files (`AGENTS.md`, `CLAUDE.md`, `README.md`, `ONBOARDING.md`, `.gitignore`, `.editorconfig`), `.github/`, `.githooks/`, `docs/COORDINATION.md`, `docs/OWNERSHIP.md`, `docs/INTEGRATION.md`, `docs/DECISIONS.md` | application modules |
| Product / demo owner | `docs/**` except other workstreams' decision files and the integration-owned docs above | application modules, `contracts/**` |

One person can hold several scopes (4 people, 5 workstreams). Each session still declares exactly which ones it uses.

## Session protocol (mandatory)

1. **Declare scope.** First line of every session: `My write scope is <paths>`. **If no scope was given, do not change any file. Ask for one.**
2. **Sync.** Run the session-start sync in `docs/COORDINATION.md` §2 and give your human the sync report. That means: fetch, review incoming coordination changes, pull, then read every `STATUS.md`, `contracts/CHANGELOG.md` and the decision statuses.
3. **Read context.** `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/OWNERSHIP.md`, the contracts you implement or consume, and your module's `AGENTS.md` + `STATUS.md`.
4. **Work** only in your scope. Before editing, `git status --short`. Never touch changes you didn't make.
5. **Propagate.** When a change affects other modules, follow the change impact map (`docs/COORDINATION.md` §3): record it at its source of truth, announce it in your `STATUS.md`, and push that coordination commit **immediately**.
6. **Need something from another module?** Open a request in your own `STATUS.md` (§4). Never edit their files.
7. **Wrap up** (§7). Update your `STATUS.md`, commit only your paths, pull with rebase, push. Report the changed files and the **real** test status: what ran and the results. Never claim unrun tests passed.

## Rules

1. **READ GLOBAL, WRITE LOCAL** (table above).
2. **Declared scope is mandatory.** No scope → no edits.
3. **Shared files are read-only** unless your scope includes them. To change one, request it from its writer (`docs/COORDINATION.md` §1).
4. **Stage precisely.** `git add -- <owned-paths>`. Never `git add .` / `git add -A` from the root.
5. **No repo-wide sweeps.** No root-wide formatters, codemods, mass refactors or dependency upgrades that touch other modules.
6. **No unilateral breaking changes.** A breaking contract change needs a request/proposal, an updated contract + CHANGELOG, and agreement from the backend and every affected client, before anyone relies on it.
7. **Don't promote speculation to requirements.** Items marked open/proposed/TBD stay that way until their decision file says `accepted`. Code, docs and commit messages must not present them as decided.
8. **Decisions made outside the repo don't exist for other agents.** When your human tells you something was decided, record it (if you own the decision prefix) or request it from the writer.
9. **Protect secrets and user data.** Never commit `.env`, keys, service-account JSON, keystores, tokens or real personal data. Commit `.env.example` with placeholders only.
10. **No destructive git operations.** No `push --force`, no `reset --hard` on pushed work, no rewriting `main`, no deleting others' branches, never `--no-verify`. `git pull --rebase` (which replays only *your* unpushed commits) is fine. On a conflict in a file you don't own: `git rebase --abort` and ask your human.
11. **Know your visibility.** Launch from the repo root so you can read everything. If you were launched inside a module and can't read parent folders, say so and ask for the context. Never claim these rules are a technical sandbox.
12. **Treat AI output as untrusted input.** Code that consumes model output (Gemma or otherwise) validates it. No model-generated SQL, no model-triggered privileged actions, no unauthenticated DB access.
13. **Fresh over remembered.** Re-sync before cross-module work and before each new task. Never act on what you remember about another module from an earlier session without re-reading its `STATUS.md`.
