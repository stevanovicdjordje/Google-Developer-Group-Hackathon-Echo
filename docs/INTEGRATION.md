# Eho — Integration workflow

How four people and their AI agents build three apps in parallel without stepping on each other. The **communication protocol** between agents (STATUS files, requests, announcements, change impact map) is in [`COORDINATION.md`](COORDINATION.md). This file covers the engineering workflow around it.

## Contract-first

1. A consumer or the backend opens a **request** to `contracts` in its own `STATUS.md`.
2. The contracts owner agrees the shape with the backend and consumers, then updates `contracts/openapi.yaml` + fixtures in `contracts/examples/`, writes a `CHANGELOG.md` entry, and announces it.
3. The backend implements it while clients build against the fixtures **at the same time**.
4. Clients switch to the real API once the backend marks the operation `implemented` in `backend/STATUS.md` → *Contract coverage* and publishes how to reach it (*How to consume*).
5. Both sides mark it `verified e2e` after a real end-to-end run.

## Mock-first UI

Clients never wait on the backend. Each client keeps a way to run on `contracts/examples/` fixtures or local mocks (a flag or build variant), and says how in its `STATUS.md`.

## Compatibility and versioning

- Additive changes (new optional field, new endpoint) are non-breaking.
- Removing or renaming fields, changing types, or making fields required is **breaking**. It needs a request/proposal and sign-off from every affected consumer.
- `info.version`: minor bump for additive, major bump for breaking. While below `1.0.0`, breaking changes bump the minor version and are flagged **BREAKING** in `contracts/CHANGELOG.md`.

## Branching and review

- **Trunk-based on `main`** (`COORDINATION.md` §7). Module paths don't overlap, so small direct commits are the low-friction default.
- **PRs** for breaking contract changes, rule/process changes, and anything someone wants reviewed. The owner of each touched path reviews. Contract PRs also get a consumer review.
- Contract changes are committed separately from implementation changes.

## Repo-wide read vs. write restrictions

- Everyone, human or agent, may **read** the whole repo.
- **Writes** are limited to your owned paths (`AGENTS.md`, `OWNERSHIP.md`).
- Enforcement is layered and partial: agent instructions → optional Claude Code deny rules → optional pre-commit scope guard (`.githooks/pre-commit`) → diff review. None of these is a security boundary.

## Several agents on one machine (`git worktree`, optional)

Usually each person runs one agent in their own clone. If **you** run more than one agent at once (say, one per module you own), give each its own worktree so they don't share a working tree:

```bash
# from the repo root
git worktree add ../eho-contracts -b contracts/<topic>
# start the second agent from ../eho-contracts with its own declared scope
git worktree list
git worktree remove ../eho-contracts   # after merging that branch into main
```

- Never give two agents overlapping write scopes in the same working tree.
- Each agent runs `git status --short` before editing and ignores changes it didn't make.
- Each agent stages only its own paths.

## Recommended checks

None of these are set up yet. Each owner adds what fits their stack and records how to run it in their `STATUS.md`.

| Check | Where | Purpose |
| --- | --- | --- |
| OpenAPI lint (`npx @redocly/cli lint contracts/openapi.yaml` or `openapi-spec-validator`) | contracts | Spec stays valid |
| Fixture validation against schemas | contracts | Mocks match the contract |
| Backend smoke test (health + one hero-flow call) | backend | The server actually runs |
| UI runs on mocks | mobile, organizer-web | Clients are independent of backend progress |
| **One real end-to-end integration** | all | Required for a working (non-mockup) demo |
