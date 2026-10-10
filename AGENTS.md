# AGENTS.md — rules for AI coding agents (and humans)

These rules apply to every AI coding agent (Claude Code, Codex, Gemini CLI, Cursor, etc.) and every human working in this repository. Module-specific rules live in each module's own `AGENTS.md` and add to (never relax) these rules.

> **These rules are behavioral, not a technical sandbox.** Git, GitHub and the file system do not enforce them. Agents that can write anywhere must follow them by discipline, and humans must review diffs. Where real isolation exists (separate `git worktree`, restricted permissions, a scoped working directory), use it.

## The core rule: READ GLOBAL, WRITE LOCAL

An agent may **read any file** in the repository for context, but may **write only inside its assigned module/scope**. It must not change code, dependencies, configuration or generated files that belong to another module.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Mobile | `mobile/**` | `backend/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |
| Backend | `backend/**` | `mobile/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |
| Organizer web | `organizer-web/**` | `mobile/**`, `backend/**`, `contracts/**`, `docs/**`, root |
| Contracts owner | `contracts/**` | application modules |
| Integration/docs owner | explicitly assigned shared files | app modules |

## Rules

1. **READ GLOBAL, WRITE LOCAL.** Read anything; modify only your assigned scope. No edits to another module's code, dependencies, config or generated files.
2. **Declared scope is mandatory.** Every session must have a declared scope: `mobile/`, `backend/`, `organizer-web/`, `contracts/` or `docs/`. **If the scope is not clear, do not change any code — ask for it.**
3. **Shared root files are read-only by default.** `README.md`, `AGENTS.md`, `CLAUDE.md`, `.github/`, `contracts/` and `docs/` may be read freely; changing them requires approval from the integration/contract owner (see `docs/OWNERSHIP.md`). The only exception was the initial bootstrap agent, which was explicitly authorized to create the scaffold.
4. **Stage precisely.** Do not run `git add .` / `git add -A` from the root during normal work if there is any risk of staging someone else's changes. Use `git add -- <owned-paths>`.
5. **No repo-wide sweeps.** Do not run root-wide formatters, mass refactors, codemods or dependency upgrades that touch other modules.
6. **No unilateral breaking API changes.** A breaking change needs a written proposal, an updated contract in `contracts/`, and agreement from both the server and the affected clients.
7. **Don't promote speculation to requirements.** Ideas in `docs/` marked Proposed/Unvalidated/TBD stay that way until the team decides. Do not write code, docs or commit messages that present them as decided.
8. **Protect secrets and user data.** Never commit `.env` files, API keys, service-account JSON, keystores, tokens or real user data. Use `.env.example` with placeholder values.
9. **No destructive git operations.** No `reset --hard` on shared work, no rebasing other people's branches, no `push --force`, no deleting branches you don't own, no rewriting `main`.
10. **Read the context first.** At the start of every session read: `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/OWNERSHIP.md`, the relevant parts of `contracts/`, and your module's `AGENTS.md`.
11. **Know your visibility.** If the agent was launched from a subdirectory and technically cannot read parent folders, it must be given that context explicitly, or be launched from the repo root with a restricted write scope. Never claim that these rules are a technical sandbox.
12. **Treat AI output as untrusted input.** Code that consumes model output (Gemma or otherwise) must validate it. Never let a model produce arbitrary SQL, call privileged functions, or access the database without authorization checks.

## Mandatory session protocol

Every coding agent, every session:

1. Start by stating: **`My write scope is <path>/**`**.
2. Before editing, run `git status --short` and note any existing changes.
3. **Do not touch other people's uncommitted changes**, even when they look wrong.
4. Write only inside the owned scope. If a contract or shared doc needs to change, **write a proposal** (in the PR description or as a note to the owner) instead of editing it.
5. At the end, list **changed files** and the **real test status**: which checks were run and their results. Never say tests passed if they were not run.

## When agents work in parallel

- Prefer one `git worktree` per agent/module (see `docs/INTEGRATION.md`).
- Never run two agents with overlapping write scopes on the same working tree.
- If you notice changes outside your scope in `git status`, leave them alone and mention them in your summary.
