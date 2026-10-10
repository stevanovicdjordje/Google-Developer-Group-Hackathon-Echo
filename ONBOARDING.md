# Eho — Onboarding

## For humans (2 minutes)

You don't need to learn how the agents coordinate. They handle it themselves and only come to you for **design direction** and **big architecture calls**.

**What you do:** tell your agent what to build ("make the agenda screen", "make it look like X"), and answer its occasional questions. Everything else (keeping other agents informed, agreeing how the apps talk to the server, picking up teammates' changes) is the agent's job.

**The parts of the project** (more detail in the [README](README.md#what-each-part-is-plain-language)):
- `mobile/`: the attendee app
- `organizer-web/`: the organizer website
- `backend/`: the server both apps talk to; the only part that uses the AI
- `contracts/`: the agreement on how the apps and the server talk, plus sample data
- `docs/`: what we're building, the demo plan, and every decision made

1. **Clone** (once):
   ```bash
   git clone git@github.com:Ilij4n/eho.git      # or https://github.com/Ilij4n/eho.git
   ```
2. **Open your module** in your IDE if you like (e.g. `mobile/` in Android Studio). Optional.
3. **Start your agent from the repo root** (the IDE terminal is fine):
   ```bash
   cd eho        # the repo root, not your module folder
   claude        # or: codex
   ```
4. **Paste this, filling in your module:**
   ```text
   You are my agent for the Eho hackathon repo; the current directory is the repo root.
   I'm working on: <mobile | backend | organizer-web | product>.
   Read ONBOARDING.md ("For agents") and follow it.
   ```

That's it. From then on, just tell your agent what you want built. It will occasionally show you one of these:

| You see | It means |
| --- | --- |
| 🧭 **Decision needed** | A design or architecture choice that's yours. Pick an option. |
| 📣 **Please send this to …** | Copy the message to that teammate in chat (only when something is urgent). |
| 🙋 **I need you to …** | Something only a human can do: an API key, a login, a device. |

If a teammate sends you a 📣 message, paste it to your own agent.

---

## For agents

You were started by a teammate with the kickoff prompt above. Do the following without asking your human anything beyond what's needed.

1. **Read** `AGENTS.md` and `docs/COORDINATION.md` (if they're not already in your context), then your module's `AGENTS.md` and `STATUS.md`.
2. **First session in this clone?** (Your human's handle isn't on the `Owner` line of your module's `STATUS.md`.) Run the setup in `docs/COORDINATION.md` §2: identify your human, work out your scopes including fallback roles, register, turn on the scope guard, add Claude Code deny rules.
3. **Declare your scope** in your first reply: `My write scope is …`.
4. **Sync** (`docs/COORDINATION.md` §3) and handle anything waiting for you.
5. **Tell your human**, in 2–3 plain lines: you're set up, the relevant team state, and what you suggest doing first. If the hero flow or your module's stack isn't decided yet, ask with a 🧭 instead.
6. From then on: work in your scope, keep other agents informed per the change impact map (§4), sync before each task and after each push, and only involve your human per §0. Never explain the protocol to them unless they ask.

If you were launched inside a module folder instead of the repo root, say so and ask your human to restart you from the root. Until they do, read the root files via `../` and rely on the scope guard hook for protection.
