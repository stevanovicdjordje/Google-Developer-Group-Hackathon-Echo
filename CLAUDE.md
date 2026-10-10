# CLAUDE.md

Instructions for Claude Code in this repository.

## Before doing anything

1. Read [`AGENTS.md`](AGENTS.md) (root). It is the source of truth for agent rules.
2. Read [`docs/OWNERSHIP.md`](docs/OWNERSHIP.md).
3. Read the scoped `AGENTS.md` of the module you were assigned (`mobile/`, `backend/`, `organizer-web/` or `contracts/`).
4. Read `docs/PRODUCT.md`, `docs/ARCHITECTURE.md` and the relevant parts of `contracts/`.

## READ GLOBAL, WRITE LOCAL

- You may read any file for context.
- You may write **only** inside your declared scope.
- Your first message in a session must state: `My write scope is <path>/**`.
- **If no scope was given, ask for one before changing any file.** You are responsible for asking — do not infer a scope from the files you happen to be looking at.
- Shared files (`README.md`, `AGENTS.md`, `CLAUDE.md`, `.github/`, `contracts/`, `docs/`) are read-only unless the user explicitly assigns them to you.

| Agent scope | May write | Read-only by default |
| --- | --- | --- |
| Mobile | `mobile/**` | `backend/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |
| Backend | `backend/**` | `mobile/**`, `organizer-web/**`, `contracts/**`, `docs/**`, root |
| Organizer web | `organizer-web/**` | `mobile/**`, `backend/**`, `contracts/**`, `docs/**`, root |
| Contracts owner | `contracts/**` | application modules |
| Integration/docs owner | explicitly assigned shared files | app modules |

## Important

- This `CLAUDE.md` does **not** replace scope discipline and is **not** a technical guarantee of boundaries. Claude Code can technically write anywhere it has permission; staying in scope is your responsibility, and humans review diffs.
- Use `git add -- <owned-paths>`, never `git add .` from the root.
- No force-pushes, no destructive git commands, no repo-wide formatters or dependency upgrades.
- Never present Proposed/TBD items from `docs/` as decided or implemented.
- End each session with a list of changed files and the real test status.
