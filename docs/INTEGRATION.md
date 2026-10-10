# Eho — Integration workflow

How four people and their AI agents build three apps in parallel without stepping on each other.

## Contract-first

1. Agree on the endpoint in `contracts/openapi.yaml` (contract owner + consumers).
2. Add fixtures in `contracts/examples/`.
3. The backend implements it; clients build against the fixtures **at the same time**.
4. Clients switch to the real API once the backend endpoint passes a smoke test.

## Mock-first UI

Clients never wait on the backend. Each client keeps a way to run on `contracts/examples/` fixtures or local mocks (a flag or build variant). That makes it easy to demo UI work in isolation.

## Compatibility and versioning

- Additive changes (new optional field, new endpoint) are non-breaking.
- Removing or renaming fields, changing types, or making fields required is **breaking**. It needs a proposal and sign-off from every affected consumer, and a major bump of `info.version`.
- Each contract PR states its impact: `additive` / `breaking` / `fixture-only`.

## PR review

- One module per PR where possible; the PR template is mandatory.
- Contract PRs are separate from implementation PRs.
- The owner of each touched path reviews. Contract PRs also get a consumer review.

## Repo-wide read vs. write restrictions

- Everyone, human or agent, may **read** the whole repo.
- **Writes** are limited to your owned paths (`docs/OWNERSHIP.md`, `AGENTS.md`).
- These are **behavioral** rules. Git does not enforce them; review diffs before committing (`git diff --stat`).

## Parallel agents and `git worktree` (optional)

To run several agents at once without them sharing a working tree:

```bash
# from the repo root
git worktree add ../eho-backend  -b backend/<topic>
git worktree add ../eho-mobile   -b mobile/<topic>
# run each agent in its own worktree, from that worktree's root,
# with its write scope declared (e.g. "My write scope is backend/**").
git worktree list
git worktree remove ../eho-backend   # when the branch is merged
```

Rules when agents run in parallel:

- Never give two agents overlapping write scopes in the same working tree.
- Each agent checks `git status --short` before editing and ignores changes it didn't make.
- Each agent stages only its own paths: `git add -- <scope>/`.
- If two agents need the same contract change, the contract owner makes it once and both rebase onto it. Don't rebase someone else's branch for them.

## Recommended checks

None of these are set up yet. Each module owner adds what fits their stack.

| Check | Where | Purpose |
| --- | --- | --- |
| OpenAPI lint (e.g. `npx @redocly/cli lint contracts/openapi.yaml`) | contracts | Spec stays valid |
| Fixture validation against schemas | contracts | Mocks match the contract |
| Backend smoke test (health + one hero-flow call) | backend | The server actually runs |
| UI runs on mocks | mobile, organizer-web | Clients are independent of backend progress |
| **One real end-to-end integration** | all | Required for a working (non-mockup) demo |
