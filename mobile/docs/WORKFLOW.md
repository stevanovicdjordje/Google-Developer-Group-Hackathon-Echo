# Mobile orchestrator workflow

How the `mobile` workstream (@Ilij4n) is run: one **orchestrator** session plans and integrates; **worker** subagents do the implementation in parallel. All state lives in the repo, so any new orchestrator session can continue from a one-paragraph handoff prompt.

## Roles

| Role | Who | Does | Doesn't |
| --- | --- | --- | --- |
| Orchestrator | Main Claude session (Opus), launched from the repo root | Syncs, picks tasks from `BOARD.md`, writes briefs, dispatches workers, merges, verifies, updates STATUS/BOARD/HANDOFF, talks to the human | Read source in bulk or implement features itself (small fixes after a merge are fine) |
| `mobile-dev` | Sonnet, effort high, own worktree | Well-defined tasks: a screen, wiring, state, tests | Edit outside its brief, push |
| `mobile-dev-opus` | Opus, effort medium, own worktree | Hard tasks: architecture, cross-cutting refactors, design-system rollout, gnarly bugs, integrating real endpoints | Same |
| `mobile-verifier` | Sonnet, effort high, read-only | Analyze/test/build, screenshots, diff review | Edit code |

Agent definitions: `.claude/agents/mobile-*.md`.

## Files that hold the state

| File | Holds | Updated by |
| --- | --- | --- |
| `mobile/docs/BOARD.md` | Task board: IDs, status, size, agent, files touched, dependencies | Orchestrator, every time a task changes state |
| `mobile/docs/HANDOFF.md` | What the next orchestrator needs that isn't on the board: in-flight work, open questions to the human, gotchas | Orchestrator, at the end of each session (and before context runs low) |
| `mobile/STATUS.md` | What other teammates' agents need to know (protocol: `docs/COORDINATION.md`) | Orchestrator, when something cross-module changes |
| `mobile/docs/APP_GUIDE.md` | App structure for workers | Whoever changes the structure, in the same commit |
| `mobile/docs/api-needs.md` | What the app needs from the backend | Orchestrator |

## The loop

### 1. Start of session

1. `git status --short`, then sync (`docs/COORDINATION.md` §3): fetch, check incoming coordination changes, `git pull --rebase --autostash`.
2. Read `mobile/docs/HANDOFF.md` and `mobile/docs/BOARD.md`. Skim `mobile/STATUS.md` inbound requests and other modules' announcements that mention mobile.
3. Leftover worker branches from a previous session (`git branch --list 'worktree-*'`, `git worktree list`): merge them if their task is still `review` on the board, otherwise ask the human.
4. Tell the human in 3 lines or less: state, what you'll run next. Ask a 🧭 only if a task needs their call.

### 2. Pick and brief

- Take `ready` tasks from the board. **Parallel tasks must not touch the same files.** These are hot files; at most one running worker may touch each:
  `core/router.dart`, `core/theme.dart`, `data/repositories.dart`, `data/app_state.dart`, `data/models.dart`, `pubspec.yaml`.
  If two tasks need the same hot file, run them one after the other, or give the hot-file part to one of them.
- **Sonnet (`mobile-dev`)** by default. **Opus (`mobile-dev-opus`)** when the task spans many files, needs design judgment, or has failed once on Sonnet.
- **Commit everything on `main` before dispatching.** Worktrees branch from the local default branch, so uncommitted work is invisible to workers.
- Write a brief from the template below. The brief is the worker's **entire** context, so be explicit. Don't paste whole files; name them.

### 3. Dispatch

- Several independent workers: one message with several Agent calls, run in the background. Track them on the board (`in progress`, agent, start time).
- Don't wait idle. While workers run, prepare the next briefs or handle coordination.

### 4. Integrate (when a worker reports)

1. Read the report. If verification is missing or failed, send it back (SendMessage to the same agent) or re-dispatch.
2. `git log --oneline main..<branch>` and `git diff --stat main...<branch>`. Confirm only allowed paths changed.
3. `git merge --no-edit <branch>`. On conflicts in hot files, resolve them yourself if trivial; otherwise abort and re-dispatch on top of the new `main`.
4. After a batch of merges: `cd mobile/app && flutter analyze && flutter test`, or dispatch `mobile-verifier` with screenshots for UI work.
5. Push (`git pull --rebase --autostash && git push`), then clean up: `git worktree remove <path>` and `git branch -d <branch>`.
6. Board: task → `done` with commit hash. If it changed something others depend on, update `mobile/STATUS.md` (announcement) per `docs/COORDINATION.md` §4.

### 5. End of session (or context getting long)

Update `BOARD.md`, rewrite `HANDOFF.md` (template inside it), commit `coord(mobile): handoff`, push. Then give the human the **kickoff prompt** below, so they can start a fresh orchestrator.

## Brief template

```
TASK <ID>: <title>
Goal: <what the user should see/experience when done — 1–3 sentences>
Context: <why; link docs/MVP.md row or BOARD notes; any decision already made>
Files you may change: <exact paths or folders>   (anything else is off-limits)
Files to read first: mobile/docs/APP_GUIDE.md, <specific files>
Do:
- <concrete step>
- <concrete step>
Don't: <traps, e.g. "don't touch router.dart; another worker owns it", "no new packages">
Done when:
- <observable acceptance criteria>
- flutter analyze clean, flutter test passes (add/extend a widget test if behavior changed)
- <screenshots of /route1 /route2 via mobile/scripts/shots.sh, if UI>
Report: as defined in your agent instructions.
```

## Context hygiene for the orchestrator

- Don't read whole source files to "understand" them. APP_GUIDE plus worker reports are enough. If you need an answer about the code, dispatch an Explore agent or ask a worker.
- Keep `git diff` output to `--stat` unless reviewing a specific hunk.
- Write anything worth remembering into BOARD/HANDOFF immediately. They are your memory across sessions; your context is not.

## Kickoff prompt for a new orchestrator session

The human pastes this into a fresh Claude Code session (Opus) started from the repo root:

```text
You are the Eho mobile orchestrator. The current directory is the repo root (~/Developer/eho).
Follow mobile/docs/WORKFLOW.md: start-of-session steps, then continue from mobile/docs/HANDOFF.md and mobile/docs/BOARD.md.
Dispatch work to the mobile-dev / mobile-dev-opus / mobile-verifier agents; don't implement features yourself.
Keep me out of the loop except for 🧭 decisions, 🙋 actions, and a short status after each batch.
```
