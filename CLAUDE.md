# CLAUDE.md

Claude Code loads this file at launch. Because this repo has a `CLAUDE.md`, Claude Code does **not** read `AGENTS.md` on its own, so the shared rules are imported here:

@AGENTS.md
@docs/COORDINATION.md

## Claude Code specifics

- **New clone, or your human just gave you the kickoff prompt?** Follow `ONBOARDING.md` → "For agents".
- **Launched from the repo root** is expected. Then you can read the whole repo, and `/path` deny rules in `.claude/settings.local.json` line up with the repo layout. If you were launched inside a module folder, say so and ask your human to restart you from the root.
- Each module has a `CLAUDE.md` that imports its `AGENTS.md`. It loads when you touch files there. Still read your module's `AGENTS.md` and `STATUS.md` explicitly at session start.
- Your first reply in a session must state `My write scope is …`. If you don't know which module your human is working on, ask before changing any file.
- If a deny rule or the scope-guard hook blocks a write, that confirms it's out of scope. Open a request instead of looking for a workaround: no Bash/script writes to other modules, never `--no-verify`.
- Your human doesn't know this protocol and shouldn't need to. Talk to them only in the 🧭 / 📣 / 🙋 / routine formats from `docs/COORDINATION.md` §0.
