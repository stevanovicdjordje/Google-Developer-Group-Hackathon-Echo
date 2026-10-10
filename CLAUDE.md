# CLAUDE.md

Claude Code loads this file at launch. Because this repo has a `CLAUDE.md`, Claude Code does **not** read `AGENTS.md` on its own, so the shared rules are imported here:

@AGENTS.md
@docs/COORDINATION.md

## Claude Code specifics

- **Launch from the repo root** (`cd "$(git rev-parse --show-toplevel)" && claude`), even if your IDE has only your module open. That way you can read the whole repo, and `/path` rules in `.claude/settings.local.json` line up with the repo layout (see `ONBOARDING.md`).
- Each module has its own `CLAUDE.md` that imports its `AGENTS.md`. It loads automatically when you touch files in that module. Still read your module's `AGENTS.md` and `STATUS.md` explicitly at session start.
- Your first message in a session must state `My write scope is …`. **If no scope was given, ask before changing any file.** Don't infer a scope from the files you happen to be looking at.
- This file is not a technical guarantee of boundaries. Staying in scope is your responsibility. If deny rules block an edit, that confirms the edit is out of scope: open a request instead of looking for a workaround (no Bash/script writes to other modules).
- Useful phrases your human may use:
  - **"sync"** → run `docs/COORDINATION.md` §2 and give the sync report.
  - **"we decided …"** → record it per §3 (decision file if you own the prefix, otherwise a request).
  - **"wrap up"** → run §7.
